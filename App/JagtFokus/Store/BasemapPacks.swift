@preconcurrency import MapLibre
import os
import UIKit

/// The basemap packs of the saved areas, inside MapLibre's own offline database. A pack's
/// `context` is `PackContext`: the area's id and the week's tile template it was downloaded for,
/// so the index and the packs can be matched, and a refresh can hold an old and a new pack per area.
///
/// Pack requests go through the same `MLNNetworkConfiguration` session as the map, so
/// `MapRequestProtocol` throttles them to `OpenFreeMap.maxParallelRequests` too.
@MainActor
final class BasemapPacks {
    struct TooLarge: Error {}
    struct Stalled: Error {}

    /// Not touched at init: `MapStore` is made before the app's `init` body runs, and
    /// MapLibre's file source must not exist before `MapRequestProtocol` is installed.
    private var storage: MLNOfflineStorage {
        MapRequestProtocol.install()
        return MLNOfflineStorage.shared
    }
    private static let log = Logger(subsystem: "dk.jagtfokus.app", category: "offline")

    /// The packs MapLibre holds, as id and week. MapLibre loads the list on its own thread, so it is empty for a moment.
    func records() async -> [PackRecord] {
        await loadedPacks().compactMap(Self.record(of:))
    }

    /// Launch: removes orphans, and per saved area every pack but one of the index's week
    /// (`OfflineCleanup.packsToRemove`). Returns how many went.
    func cleanUp(index: OfflineAreaIndex, indexIsKnown: Bool) async -> Int {
        let packs = await loadedPacks().filter { Self.record(of: $0) != nil }
        let records = packs.compactMap(Self.record(of:))
        let remove = OfflineCleanup.packsToRemove(records, index: index, indexIsKnown: indexIsKnown)
        for position in remove { await removePack(packs[position]) }
        return remove.count
    }

    /// Downloads a pack for the box, tagged with the week `tiles`, and returns its size in bytes.
    /// Other packs of the area stay: a refresh removes the old one only when every new pack is
    /// complete. A failed or cancelled download removes its half pack before it throws.
    ///
    /// `tileJSON` is OpenFreeMap's current TileJSON. MapLibre keeps one copy per URL and a new
    /// pack reuses what is stored, so the current file is stored first: the pack then fetches
    /// this week's tiles, the ones `tiles` names, and not last week's.
    func download(_ box: GeoBox, id: UUID, tileJSON: Data, tiles: String, progress: @escaping (Double) -> Void) async throws -> Int {
        // While a pack downloads, the map's TileJSON request is never answered with the pin.
        PinnedBasemap.beginDownload()
        defer { PinnedBasemap.endDownload() }
        await preload(tileJSON)
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
        let pack = try await add(region, context: PackContext.encode(id: id, tiles: tiles))
        Self.log.notice("pack started")
        #if DEBUG
        // `-holdPack 20`: wait with a half pack in the database, so a test can kill the app there.
        let hold = UserDefaults.standard.double(forKey: "holdPack")
        if hold > 0 { try? await Task.sleep(for: .seconds(hold)) }
        #endif
        do {
            return try await run(pack, progress: progress)
        } catch {
            await removePack(pack)
            throw error
        }
    }

    /// Stores TileJSON bytes as MapLibre's copy of `OpenFreeMap.tileJSONURL`. Already stale and
    /// marked must-revalidate: online the map asks the server again, offline it asks the app,
    /// which answers with the pin. After a failed refresh this puts the pinned week back.
    func preload(_ tileJSON: Data) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            storage.preload(
                tileJSON,
                for: OpenFreeMap.tileJSONURL,
                modificationDate: Date(),
                expirationDate: Date(),
                eTag: nil,
                mustRevalidate: true
            ) { _, _ in continuation.resume() }
        }
    }

    /// Every pack there is: the reset of saved areas. The app makes no other packs.
    func removeAll() async {
        for pack in await loadedPacks() {
            await removePack(pack)
        }
    }

    /// Every pack with this id.
    func remove(id: UUID) async {
        for pack in await loadedPacks() where Self.record(of: pack)?.id == id {
            await removePack(pack)
        }
    }

    /// The area's packs for the week `tiles`: the new packs of a refresh that failed.
    func remove(id: UUID, tiles: String) async {
        for pack in await loadedPacks() {
            guard let record = Self.record(of: pack), record.id == id, record.tiles == tiles else { continue }
            await removePack(pack)
        }
    }

    /// The area's packs for any other week than `tiles`: the old packs once a refresh is complete.
    func removeOthers(id: UUID, keeping tiles: String) async {
        for pack in await loadedPacks() {
            guard let record = Self.record(of: pack), record.id == id, record.tiles != tiles else { continue }
            await removePack(pack)
        }
    }

    // MARK: MapLibre

    private func loadedPacks() async -> [MLNOfflinePack] {
        for _ in 0..<50 {
            if let packs = storage.packs { return packs }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return storage.packs ?? []
    }

    private static func record(of pack: MLNOfflinePack) -> PackRecord? {
        guard pack.state != .invalid else { return nil }
        return PackContext.decode(pack.context)
    }

    private func add(_ region: MLNTilePyramidOfflineRegion, context: Data) async throws -> MLNOfflinePack {
        try await withCheckedThrowingContinuation { continuation in
            storage.addPack(for: region, withContext: context) { pack, error in
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
    /// Counts quiet time only while the app is active (see `StallWatch`).
    private var stall = StallWatch(limitSeconds: 60)
    private var best = 0.0
    private var cancelledEarly = false
    private var errors = 0
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
        // Coming back to the foreground starts the count again.
        observers.append(center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.stall.becameActive() }
        })
        watchdog = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard let self else { return }
                if self.stall.tick(seconds: 5, isActive: UIApplication.shared.applicationState == .active) {
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
        stall.progress()
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
