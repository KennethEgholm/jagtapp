import Foundation
import Network
import Observation
import os

/// What the map tab knows about boundaries: the saved areas, the live fetch for the view and
/// the GeoJSON that goes on the map. The decisions (zoom, saved area, size, errors) are
/// `LiveBoundaries` in Core; this only runs them. It also saves, refreshes and deletes areas.
@MainActor
@Observable
final class MapStore {
    enum Live: Equatable {
        case idle, loading, loaded, tooFarOut, offline, failed, noKey
    }

    enum Saving: Equatable {
        case idle
        /// The frame follows the map's centre; the card asks for Gem or Annuller.
        case choosing
        case downloading(name: String, progress: Double)
        case saved(String)
        case failed
    }

    private(set) var live: Live = .idle
    private(set) var saving: Saving = .idle
    /// Saved areas, newest first.
    private(set) var index = OfflineAreaIndex()
    /// The saved areas are loaded and the packs cleaned: saving may begin.
    private(set) var isReady = false
    /// From the system's path monitor. DEBUG `-offline YES` keeps it false.
    private(set) var isOnline = true
    /// Saved areas in view and the live fetch, as GeoJSON for the map. nil when there is nothing to draw.
    private(set) var visibleParcels: Data?
    /// Set when the view lies wholly inside a saved area: the status says which.
    private(set) var areaInView: OfflineArea?

    private var savedParcels: [UUID: ParcelSet] = [:]
    private var liveParcels: ParcelSet?
    private var cache = ParcelCache()
    private var lastView: (box: GeoBox, zoom: Double)?
    private var task: Task<Void, Never>?

    private var diskIsKnown = false
    /// Set when a delete fails, until the user has seen it.
    var deleteFailed = false
    /// Set when the reset fails, until the user has seen it.
    var resetFailed = false
    private var saveCentre: Coordinate?
    private var frozenFrame: GeoBox?
    private var saveTask: Task<Void, Never>?
    private var refreshTask: Task<Void, Never>?
    private var startTask: Task<Void, Never>?
    /// Bumped when a save ends or is cancelled, so a late result from an old save is ignored.
    private var saveGeneration = 0
    private let disk = OfflineDisk()
    private let packs = BasemapPacks()
    private let monitor = NWPathMonitor()

    private let apiKey: String?
    private let session: URLSession
    private static let debounce = Duration.milliseconds(400)
    /// A safety stop, 50,000 parcels. A 3 km square holds a few thousand.
    private nonisolated static let maxPages = 10
    private nonisolated static let log = Logger(subsystem: "dk.jagtfokus.app", category: "cadastre")
    private static let offlineLog = Logger(subsystem: "dk.jagtfokus.app", category: "offline")

    init(apiKey: String? = DatafordelerKey.value, session: URLSession = MapSession.shared) {
        self.apiKey = apiKey
        self.session = session
    }

    // MARK: Launch

    /// Reads the saved areas, removes what a killed save left behind and starts watching the
    /// network. Safe to call again: later calls wait for the first.
    func start() async {
        if startTask == nil {
            startTask = Task { await self.launch() }
        }
        await startTask?.value
    }

    private func launch() async {
        watchNetwork()
        let snapshot = await disk.launch()
        diskIsKnown = snapshot.isKnown
        setSaved(index: snapshot.index, parcels: snapshot.parcels)
        // An index that could not be read looks empty; then no pack is removed either. A refresh
        // killed halfway leaves two packs for an area: the one of the index's week stays.
        let found = await packs.records()
        let removed = await packs.cleanUp(index: snapshot.index, indexIsKnown: snapshot.isKnown)
        #if DEBUG
        Self.offlineLog.notice("launch: \(snapshot.index.areas.count, privacy: .public) areas, packs \(found.count, privacy: .public), packs removed \(removed, privacy: .public), index known \(snapshot.isKnown, privacy: .public), pin \(snapshot.index.pinnedTiles ?? "none", privacy: .public)")
        #endif
        isReady = true
    }

    private func watchNetwork() {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "offline") {
            isOnline = false
            return
        }
        #endif
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in self?.networkChanged(online: online) }
        }
        monitor.start(queue: DispatchQueue(label: "dk.jagtfokus.network", qos: .utility))
    }

    private func networkChanged(online: Bool) {
        guard online != isOnline else { return }
        isOnline = online
        if let lastView { regionChanged(lastView.box, zoom: lastView.zoom, immediately: true) }
    }

    /// The parcel under a tap: in a saved area, or in the live fetch. Nil when the id is gone.
    func parcel(withId id: String) -> Parcel? {
        for area in index.areas {
            if let found = savedParcels[area.id]?.parcels.first(where: { $0.id == id }) {
                return found
            }
        }
        return liveParcels?.parcels.first(where: { $0.id == id })
    }

    #if DEBUG
    /// DEBUG `-parcel <matrikelnummer>`: a parcel to open the sheet with, for screenshots.
    func parcel(number: String) -> Parcel? {
        for area in index.areas {
            if let found = savedParcels[area.id]?.parcels.first(where: { $0.number == number }) {
                return found
            }
        }
        return liveParcels?.parcels.first(where: { $0.number == number })
    }
    #endif

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
        if saving == .choosing { saveCentre = box.center }
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
        switch LiveBoundaries.plan(for: box, zoom: zoom, areas: index.areas, isOnline: isOnline) {
        case .tooFarOut, .tooLarge:
            live = .tooFarOut
            areaInView = nil
            liveParcels = nil
        case .savedArea(let area):
            // Inside a saved area nothing is asked for; offline, the status says so.
            live = isOnline ? .loaded : .offline
            areaInView = area
            liveParcels = nil
        case .offline:
            live = .offline
            areaInView = nil
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
        var sets = index.intersecting(box).compactMap { savedParcels[$0.id] }
        if let liveParcels { sets.append(liveParcels) }
        let data = await Self.render(sets)
        guard !Task.isCancelled else { return }
        if data != visibleParcels { visibleParcels = data }
    }

    /// Several saved areas hold many thousands of parcels: merge and encode off the main actor.
    @concurrent
    private static func render(_ sets: [ParcelSet]) async -> Data? {
        var merged = ParcelSet(parcels: [])
        for set in sets { merged = merged.merging(set) }
        return merged.count == 0 ? nil : try? merged.geoJSON()
    }

    private static func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
    }

    /// The safety stop was reached with a full last page: the box holds more than `maxPages` pages.
    struct TooManyParcels: Error {}

    /// Every page for the box, merged. Off the main actor: the XML parse of a page is real work.
    /// A save is `strict`: it throws rather than save an area with parcels missing.
    @concurrent
    private static func fetch(box: GeoBox, apiKey: String, session: URLSession, strict: Bool = false) async throws -> ParcelSet {
        var all = ParcelSet(parcels: [])
        var start = 0
        for _ in 0..<maxPages {
            var request = URLRequest(url: CadastreService.requestURL(box: box, apiKey: apiKey, startIndex: start))
            request.setValue(UserAgent.app, forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 20
            let data = try await page(request, session: session, attempts: strict ? 4 : 2)
            let parsed = try CadastrePage.decode(from: data)
            all = all.merging(parsed.parcels)
            if parsed.skipped > 0 {
                // A member whose geometry the parser does not read. It is counted, never silently dropped.
                Self.log.error("page at \(start, privacy: .public): \(parsed.skipped, privacy: .public) of \(parsed.members, privacy: .public) members had no polygon\(strict ? " (saved area)" : "", privacy: .public)")
            }
            // From the raw page: a skipped member must not make a full page look like the last.
            guard CadastrePaging.hasMore(parsed, startIndex: start, pageSize: CadastreService.pageSize) else { return all }
            start += CadastreService.pageSize
        }
        if strict { throw TooManyParcels() }
        return all
    }

    /// One page. A 5xx gets more tries after a short wait: the service now and then fails
    /// once and answers the same request a moment later. A save tries harder than the live view.
    @concurrent
    private static func page(_ request: URLRequest, session: URLSession, attempts: Int) async throws -> Data {
        for attempt in 1...attempts {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) else { return data }
            let failure = LiveBoundaries.BadStatus(code: http.statusCode)
            if attempt == attempts || !failure.isServerError { throw failure }
            try await Task.sleep(for: .milliseconds(600 * attempt))
        }
        throw LiveBoundaries.BadStatus(code: 0)
    }
}

// MARK: - Saved areas

extension MapStore {
    /// Gem område can start: the saved areas are loaded and readable, and no save is running.
    var canSave: Bool {
        guard isReady, diskIsKnown else { return false }
        switch saving {
        case .idle, .saved, .failed: return true
        case .choosing, .downloading: return false
        }
    }

    /// `omraader.json` is there but cannot be read. Saved areas may exist on disk; only a reset gets out of this.
    var savedAreasUnreadable: Bool { isReady && !diskIsKnown }

    /// The 5 km square drawn on the map: around the centre while choosing, fixed while downloading.
    var saveFrame: GeoBox? {
        switch saving {
        case .choosing:
            (saveCentre ?? lastView?.box.center).map { GeoBox.around($0, sideMeters: MapRules.saveSideMeters) }
        case .downloading:
            frozenFrame
        case .idle, .saved, .failed:
            nil
        }
    }

    /// The map's centre while the user pans, so the frame follows the finger.
    func centreMoved(to centre: Coordinate) {
        if saving == .choosing { saveCentre = centre }
    }

    func beginSave() {
        guard canSave else { return }
        saveCentre = lastView?.box.center
        saving = .choosing
    }

    /// Leaves choosing, ends a running save (its pack is removed) or closes a result.
    func cancelSave() {
        if case .downloading = saving {
            saveTask?.cancel()
        }
        saveGeneration += 1
        frozenFrame = nil
        saving = .idle
    }

    /// 4 quadrants x pages -> merge -> basemap pack -> index. Nothing is in the index until the
    /// pack is complete, so a failure or a kill leaves nothing in the list.
    func save(name: String) async {
        guard saving == .choosing, isReady, diskIsKnown, let box = saveFrame else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmed.isEmpty ? index.nextDefaultName(prefix: String(localized: "Område")) : trimmed
        saveGeneration += 1
        let generation = saveGeneration
        frozenFrame = box
        saving = .downloading(name: name, progress: 0)
        let task = Task { await self.runSave(id: UUID(), name: name, box: box, generation: generation) }
        saveTask = task
        await task.value
    }

    private func runSave(id: UUID, name: String, box: GeoBox, generation: Int) async {
        do {
            guard let apiKey else { throw LiveBoundaries.BadStatus(code: 401) }
            // The tile template first: if the week turns during the download, the area is only
            // marked stale and refreshed later. Fetched after, it could be marked fresh with an old pack.
            let tileJSON = try await Self.currentTileJSON(session: session)
            var parcels = ParcelSet(parcels: [])
            let quadrants = box.quadrants()
            for (done, quadrant) in quadrants.enumerated() {
                let part = try await Self.fetch(box: quadrant, apiKey: apiKey, session: session, strict: true)
                try Task.checkCancellation()
                parcels = await Self.merged(parcels, part)
                setProgress(SaveProgress.overall(parcelsDone: done + 1, of: quadrants.count, pack: 0), generation: generation)
            }
            let packBytes = try await packs.download(box, id: id, tileJSON: tileJSON.data, tiles: tileJSON.template) { [weak self] fraction in
                self?.setProgress(SaveProgress.overall(parcelsDone: quadrants.count, of: quadrants.count, pack: fraction), generation: generation)
            }
            try Task.checkCancellation()
            let committed = try await disk.commit(id: id, name: name, box: box, parcels: parcels, packBytes: packBytes, basemapTiles: tileJSON.template, tileJSON: tileJSON.data)
            // Cancelled in the last moment: the area is in the index, so it stays and shows in the list.
            setSaved(index: committed.index, parcels: savedParcels.merging([id: parcels]) { $1 })
            if committed.index.pinnedTiles != tileJSON.template {
                // Older areas are on an older week: the pin stays theirs until the refresh moves them all.
                await restorePin()
                Task { await self.refreshStaleBasemaps() }
            }
            guard generation == saveGeneration else { return }
            frozenFrame = nil
            saving = .saved(name)
            Self.offlineLog.notice("area saved: \(committed.area.parcelCount, privacy: .public) parcels, \(committed.area.bytes, privacy: .public) bytes")
            Task {
                try? await Task.sleep(for: .seconds(4))
                if saving == .saved(name) { saving = .idle }
            }
        } catch {
            // A pack that was added but not committed must not stay: nothing is indexed for it.
            await packs.remove(id: id)
            await restorePin()
            guard generation == saveGeneration else { return }
            saveGeneration += 1
            frozenFrame = nil
            saving = .failed
            Self.offlineLog.error("save failed: \(Self.describe(error), privacy: .public)")
        }
    }

    private func setProgress(_ value: Double, generation: Int) {
        guard generation == saveGeneration, case .downloading(let name, let current) = saving, value > current else { return }
        saving = .downloading(name: name, progress: value)
    }

    /// Never a URL: it can carry the key.
    private static func describe(_ error: Error) -> String {
        if let status = error as? LiveBoundaries.BadStatus { return "HTTP \(status.code)" }
        if let urlError = error as? URLError { return "URLError \(urlError.code.rawValue)" }
        return String(describing: type(of: error))
    }

    /// The area, its parcels file and its pack. The index row goes first: a kill in between
    /// leaves an orphan, which the next launch removes.
    func delete(_ id: UUID) async {
        refreshTask?.cancel()
        await refreshTask?.value
        guard diskIsKnown else {
            deleteFailed = true
            return
        }
        do {
            let updated = try await disk.delete(id: id)
            var parcels = savedParcels
            parcels[id] = nil
            setSaved(index: updated, parcels: parcels)
        } catch {
            Self.offlineLog.error("delete failed: \(Self.describe(error), privacy: .public)")
            deleteFailed = true
            return
        }
        await packs.remove(id: id)
    }

    /// The way out of an unreadable index: every file in the Kort folder and every basemap pack
    /// goes, and saving works again with nothing saved.
    func resetSavedAreas() async {
        saveTask?.cancel()
        refreshTask?.cancel()
        await refreshTask?.value
        saveGeneration += 1
        frozenFrame = nil
        saving = .idle
        do {
            try await disk.reset()
        } catch {
            Self.offlineLog.error("reset failed: \(Self.describe(error), privacy: .public)")
            resetFailed = true
            return
        }
        diskIsKnown = true
        setSaved(index: OfflineAreaIndex(), parcels: [:])
        await packs.removeAll()
    }

    /// Online: when OpenFreeMap names a new week, downloads a new pack for every area saved with an
    /// older one, silently. All or nothing: the old packs and the pin stay until every new pack is
    /// complete; then the index (every area's template and the pin, one write) moves, and only then
    /// do the old packs go. Any failure removes the new packs and puts the pinned week back.
    func refreshStaleBasemaps() async {
        await start()
        if let refreshTask {
            await refreshTask.value
            return
        }
        guard isOnline, diskIsKnown, !index.areas.isEmpty else { return }
        let task = Task { await self.runRefresh() }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    private func runRefresh() async {
        guard let current = try? await Self.currentTileJSON(session: session) else { return }
        let plan = BasemapRefresh.plan(index: index, currentTiles: current.template)
        guard plan.isNeeded else { return }
        #if DEBUG
        Self.offlineLog.notice("refresh: \(plan.stale.count, privacy: .public) stale areas, pin moves \(plan.movesPin, privacy: .public)")
        #endif
        var started: [UUID] = []
        do {
            for area in plan.stale {
                try Task.checkCancellation()
                started.append(area.id)
                _ = try await packs.download(area.box, id: area.id, tileJSON: current.data, tiles: current.template) { _ in }
            }
            try Task.checkCancellation()
            #if DEBUG
            // `-failRefresh YES`: fail after the new packs are complete, before the index moves.
            if UserDefaults.standard.bool(forKey: "failRefresh") { throw CancellationError() }
            #endif
            let updated = try await disk.applyRefresh(ids: Set(started), tiles: current.template, tileJSON: current.data)
            setSaved(index: updated, parcels: savedParcels)
        } catch {
            Self.offlineLog.error("refresh failed, the old packs and the pin stay: \(Self.describe(error), privacy: .public)")
            for id in started { await packs.remove(id: id, tiles: current.template) }
            await restorePin()
            return
        }
        // The index names the new week: the old packs can go. A kill before this is mended at launch.
        for id in started { await packs.removeOthers(id: id, keeping: current.template) }
        #if DEBUG
        Self.offlineLog.notice("refresh complete: \(started.count, privacy: .public) packs, pin \(self.index.pinnedTiles ?? "none", privacy: .public)")
        #endif
    }

    /// MapLibre's copy of the TileJSON becomes the pinned week again, so offline it is the one the packs hold.
    private func restorePin() async {
        guard let pin = index.pinnedTileJSON else { return }
        await packs.preload(pin)
    }

    /// Thousands of parcels: off the main actor.
    @concurrent
    private static func merged(_ first: ParcelSet, _ second: ParcelSet) async -> ParcelSet {
        first.merging(second)
    }

    /// OpenFreeMap's TileJSON, as bytes and as the weekly tile template it names.
    @concurrent
    private static func currentTileJSON(session: URLSession) async throws -> (data: Data, template: String) {
        var request = URLRequest(url: OpenFreeMap.tileJSONURL)
        request.setValue(UserAgent.app, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        // Always the server's answer: this decides whether the saved packs are stale.
        request.cachePolicy = .reloadIgnoringLocalCacheData
        // OpenFreeMap allows four requests at once, the map's and the packs' included.
        let (data, response) = try await OpenFreeMapTraffic.gate.run {
            try await session.data(for: request)
        }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw LiveBoundaries.BadStatus(code: http.statusCode)
        }
        return (data, try OpenFreeMap.tilesTemplate(fromTileJSON: data))
    }
}
