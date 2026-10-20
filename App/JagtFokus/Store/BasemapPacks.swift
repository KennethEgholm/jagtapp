@preconcurrency import MapLibre
import os

/// The basemap packs of the saved areas, inside MapLibre's own offline database. A pack's
/// `context` is the area's id, so the index and the packs can be matched.
///
/// Pack requests go through the same `MLNNetworkConfiguration` session as the map, so
/// `MapRequestProtocol` throttles them to `OpenFreeMap.maxParallelRequests` too.
@MainActor
final class BasemapPacks {
    struct TooLarge: Error {}
    struct Stalled: Error {}

    private let storage = MLNOfflineStorage.shared
    private static let log = Logger(subsystem: "dk.jagtfokus.app", category: "offline")

    /// The ids of the packs MapLibre holds. MapLibre loads the list on its own thread, so it is nil for a moment.
    func ids() async -> Set<UUID> {
        Set(await loadedPacks().compactMap(Self.id(of:)))
    }

    /// Downloads a pack for the box and returns its size in bytes. A pack the area already
    /// has under this id stays until the new one is complete, then goes: a failed refresh
    /// keeps the old basemap. A failed or cancelled download removes its half pack before it throws.
    ///
    /// `tileJSON` is OpenFreeMap's current TileJSON. MapLibre keeps one copy per URL and a new
    /// pack reuses what is stored, so the current file is stored first: the pack then fetches
    /// this week's tiles, the ones the area's `basemapTiles` names, and not last week's.
    func download(_ box: GeoBox, id: UUID, tileJSON: Data, progress: @escaping (Double) -> Void) async throws -> Int {
        await store(tileJSON)
        let previous = await loadedPacks().filter { Self.id(of: $0) == id }
        let region = MLNTilePyramidOfflineRegion(
            styleURL: OpenFreeMap.styleURL,
            bounds: MLNCoordinateBounds(
                sw: CLLocationCoordinate2D(latitude: box.south, longitude: box.west),
                ne: CLLocationCoordinate2D(latitude: box.north, longitude: box.east)
            ),
            fromZoomLevel: OpenFreeMap.packZoom.lowerBound,
            toZoomLevel: OpenFreeMap.packZoom.upperBound
        )
        region.includesIdeographicGlyphs = false
        let pack = try await add(region, id: id)
        Self.log.notice("pack started")
        #if DEBUG
        // `-holdPack 20`: wait with a half pack in the database, so a test can kill the app there.
        let hold = UserDefaults.standard.double(forKey: "holdPack")
        if hold > 0 { try? await Task.sleep(for: .seconds(hold)) }
        #endif
        do {
            let bytes = try await run(pack, progress: progress)
            for old in previous { await removePack(old) }
            return bytes
        } catch {
            await removePack(pack)
            throw error
        }
    }

    /// Every pack with this id.
    func remove(id: UUID) async {
        for pack in await loadedPacks() where Self.id(of: pack) == id {
            await removePack(pack)
        }
    }

    // MARK: MapLibre

    private func store(_ tileJSON: Data) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            storage.preload(
                tileJSON,
                for: OpenFreeMap.tileJSONURL,
                modificationDate: Date(),
                expirationDate: Date().addingTimeInterval(3600),
                eTag: nil,
                mustRevalidate: false
            ) { _, _ in continuation.resume() }
        }
    }

    private func loadedPacks() async -> [MLNOfflinePack] {
        for _ in 0..<50 {
            if let packs = storage.packs { return packs }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return storage.packs ?? []
    }

    private static func id(of pack: MLNOfflinePack) -> UUID? {
        guard pack.state != .invalid else { return nil }
        return String(data: pack.context, encoding: .utf8).flatMap { UUID(uuidString: $0) }
    }

    private func add(_ region: MLNTilePyramidOfflineRegion, id: UUID) async throws -> MLNOfflinePack {
        try await withCheckedThrowingContinuation { continuation in
            storage.addPack(for: region, withContext: Data(id.uuidString.utf8)) { pack, error in
                if let pack {
                    continuation.resume(returning: pack)
                } else {
                    continuation.resume(throwing: error ?? URLError(.unknown))
                }
            }
        }
    }

    private func removePack(_ pack: MLNOfflinePack) async {
        guard pack.state != .invalid else { return }
        pack.suspend()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            storage.removePack(pack) { _ in continuation.resume() }
        }
    }

    private func run(_ pack: MLNOfflinePack, progress: @escaping (Double) -> Void) async throws -> Int {
        let watcher = PackWatcher(pack: pack, progress: progress)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { watcher.start($0) }
        } onCancel: {
            Task { @MainActor in watcher.cancel() }
        }
    }
}

/// Follows one pack until it is complete, too large, stalled or cancelled. MapLibre retries
/// failed resources on its own, so a single error notification is only logged.
@MainActor
private final class PackWatcher {
    private let pack: MLNOfflinePack
    private let report: (Double) -> Void
    private var continuation: CheckedContinuation<Int, Error>?
    private var observers: [NSObjectProtocol] = []
    private var watchdog: Task<Void, Never>?
    private var lastChange = ContinuousClock.now
    private var best = 0.0
    private var cancelledEarly = false
    private var errors = 0
    private static let stallLimit = Duration.seconds(60)
    private static let log = Logger(subsystem: "dk.jagtfokus.app", category: "offline")

    init(pack: MLNOfflinePack, progress: @escaping (Double) -> Void) {
        self.pack = pack
        report = progress
    }

    func start(_ continuation: CheckedContinuation<Int, Error>) {
        self.continuation = continuation
        guard !cancelledEarly else { return finish(.failure(CancellationError())) }
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .MLNOfflinePackProgressChanged, object: pack, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.changed() }
        })
        observers.append(center.addObserver(forName: .MLNOfflinePackError, object: pack, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.errors += 1 }
        })
        watchdog = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard let self else { return }
                if ContinuousClock.now - self.lastChange > Self.stallLimit {
                    self.finish(.failure(BasemapPacks.Stalled()))
                    return
                }
            }
        }
        pack.resume()
    }

    func cancel() {
        guard continuation != nil else {
            cancelledEarly = true
            return
        }
        finish(.failure(CancellationError()))
    }

    private func changed() {
        guard continuation != nil else { return }
        lastChange = .now
        let progress = pack.progress
        let tiles = Int(progress.countOfTilesCompleted)
        let bytes = Int(progress.countOfBytesCompleted)
        if PackLimits.exceeded(tiles: tiles, bytes: bytes) {
            Self.log.error("pack over the limit: \(tiles, privacy: .public) tiles, \(bytes, privacy: .public) bytes")
            return finish(.failure(BasemapPacks.TooLarge()))
        }
        if progress.countOfResourcesExpected > 0 {
            best = max(best, min(1, Double(progress.countOfResourcesCompleted) / Double(progress.countOfResourcesExpected)))
        }
        report(best)
        if pack.state == .complete {
            Self.log.notice("pack complete: \(tiles, privacy: .public) tiles, \(bytes, privacy: .public) bytes, \(progress.countOfResourcesCompleted, privacy: .public) resources, \(self.errors, privacy: .public) errors")
            finish(.success(bytes))
        }
    }

    private func finish(_ result: Result<Int, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        watchdog?.cancel()
        if case .failure = result, pack.state != .invalid { pack.suspend() }
        continuation.resume(with: result)
    }
}
