import Foundation
import Observation
import os

/// What the map tab knows about boundaries: the saved areas, the live fetch for the view and
/// the GeoJSON that goes on the map. The decisions (zoom, saved area, size, errors) are
/// `LiveBoundaries` in Core; this only runs them.
@MainActor
@Observable
final class MapStore {
    enum Live: Equatable {
        case idle, loading, loaded, tooFarOut, offline, failed, noKey
    }

    private(set) var live: Live = .idle
    /// Saved areas. Task 6 fills it.
    private(set) var index = OfflineAreaIndex()
    /// Saved areas in view and the live fetch, as GeoJSON for the map. nil when there is nothing to draw.
    private(set) var visibleParcels: Data?
    /// Set when the view lies wholly inside a saved area: the status says which.
    private(set) var areaInView: OfflineArea?

    private var savedParcels: [UUID: ParcelSet] = [:]
    private var liveParcels: ParcelSet?
    private var cache = ParcelCache()
    private var lastView: (box: GeoBox, zoom: Double)?
    private var task: Task<Void, Never>?

    private let apiKey: String?
    private let session: URLSession
    private static let debounce = Duration.milliseconds(400)
    /// A safety stop, 50,000 parcels. A 3 km square holds a few thousand.
    private nonisolated static let maxPages = 10
    private static let log = Logger(subsystem: "dk.jagtfokus.app", category: "cadastre")

    init(apiKey: String? = DatafordelerKey.value, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    /// Saved areas with their parcels. The map redraws at once.
    func setSaved(index: OfflineAreaIndex, parcels: [UUID: ParcelSet]) {
        self.index = index
        savedParcels = parcels
        if let lastView { regionChanged(lastView.box, zoom: lastView.zoom, immediately: true) }
    }

    /// The map has settled on a new view. Waits 0.4 s, and a newer view cancels this one,
    /// the request included.
    func regionChanged(_ box: GeoBox, zoom: Double) {
        regionChanged(box, zoom: zoom, immediately: false)
    }

    private func regionChanged(_ box: GeoBox, zoom: Double, immediately: Bool) {
        lastView = (box, zoom)
        task?.cancel()
        task = Task { [weak self] in
            if !immediately {
                try? await Task.sleep(for: Self.debounce)
            }
            guard !Task.isCancelled else { return }
            await self?.update(box: box, zoom: zoom)
        }
    }

    private func update(box: GeoBox, zoom: Double) async {
        switch LiveBoundaries.plan(for: box, zoom: zoom, areas: index.areas) {
        case .tooFarOut, .tooLarge:
            live = .tooFarOut
            areaInView = nil
            liveParcels = nil
        case .savedArea(let area):
            live = .loaded
            areaInView = area
            liveParcels = nil
        case .fetch:
            areaInView = nil
            if let cached = cache.lookup(box) {
                liveParcels = cached
                live = .loaded
            } else {
                guard let apiKey else {
                    live = .noKey
                    liveParcels = nil
                    await publish(for: box)
                    return
                }
                live = .loading
                do {
                    let fetched = try await Self.fetch(box: box, apiKey: apiKey, session: session)
                    guard !Task.isCancelled else { return }
                    cache.insert(box: box, parcels: fetched)
                    liveParcels = fetched
                    live = .loaded
                } catch {
                    guard !Task.isCancelled, !Self.isCancellation(error) else { return }
                    switch LiveBoundaries.failure(for: error) {
                    case .offline: live = .offline
                    case .failed: live = .failed
                    }
                    liveParcels = nil
                    #if DEBUG
                    // Never the URL: it carries the key.
                    let detail = (error as? LiveBoundaries.BadStatus).map { "HTTP \($0.code)" } ?? String(describing: type(of: error))
                    Self.log.notice("fetch failed: \(detail, privacy: .public)")
                    #endif
                }
            }
        }
        await publish(for: box)
    }

    /// Saved areas that touch the view, then the live fetch.
    private func publish(for box: GeoBox) async {
        var set = ParcelSet(parcels: [])
        for area in index.intersecting(box) {
            if let saved = savedParcels[area.id] { set = set.merging(saved) }
        }
        if let liveParcels { set = set.merging(liveParcels) }
        let data = set.count == 0 ? nil : await Task.detached { try? set.geoJSON() }.value
        guard !Task.isCancelled else { return }
        if data != visibleParcels { visibleParcels = data }
    }

    private static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
    }

    /// Every page for the box, merged. Off the main actor: the XML parse of a page is real work.
    @concurrent
    private static func fetch(box: GeoBox, apiKey: String, session: URLSession) async throws -> ParcelSet {
        var all = ParcelSet(parcels: [])
        var start = 0
        for _ in 0..<maxPages {
            var request = URLRequest(url: CadastreService.requestURL(box: box, apiKey: apiKey, startIndex: start))
            request.setValue(UserAgent.app, forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 20
            let data = try await page(request, session: session)
            let parsed = try ParcelSet.decodeChecked(from: data)
            all = all.merging(parsed)
            if parsed.count < CadastreService.pageSize { break }
            start += CadastreService.pageSize
        }
        return all
    }

    /// One page. A 5xx gets one more try after a short wait: the service now and then
    /// fails once and answers the same request a moment later.
    @concurrent
    private static func page(_ request: URLRequest, session: URLSession) async throws -> Data {
        for attempt in 1...2 {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) else { return data }
            let failure = LiveBoundaries.BadStatus(code: http.statusCode)
            if attempt == 2 || !failure.isServerError { throw failure }
            try await Task.sleep(for: .milliseconds(600))
        }
        throw LiveBoundaries.BadStatus(code: 0)
    }
}
