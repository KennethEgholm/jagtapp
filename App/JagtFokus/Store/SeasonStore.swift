import Foundation
import Observation

@MainActor
@Observable
final class SeasonStore {
    enum LocationState: Equatable {
        case idle
        case locating
        case found
        case denied
        case unavailable
    }

    var catalog: HuntingCatalog
    var remoteStatus: String?

    var followToday = true
    var followHere = true
    var pickedDate = Date()
    var pickedPlace: Place
    var gpsPlace: Place?
    /// Last geocoder names, so a newer catalog can re-match without a new fix.
    private var gpsNames: [String] = []
    /// Last GPS position. Exact sun times for "Her".
    private(set) var gpsCoordinate: Coordinate?
    var locationState: LocationState = .idle
    /// Bumped on foreground so "i dag" rolls over at midnight.
    private(set) var now = Date()
    /// Counts the user's own date/place choices. Drives haptics, so GPS updates stay silent.
    private(set) var userSelections = 0

    let calendar = SeasonCalendar(locale: AppLanguage.locale)
    /// Bundled photo credits. Images are in the asset catalog.
    let photos = SeasonStore.bundlePhotos()
    /// Bundled life-history notes. Display only.
    let biology = SeasonStore.bundleBiology()
    private let remoteURL = URL(string: "https://raw.githubusercontent.com/KennethEgholm/jagtapp/main/data/jagttider.json")
    private let location = LocationService()

    init() {
        var loaded = Self.bundleCatalog() ?? HuntingCatalog(
            version: 0,
            updated: String(localized: "ukendt"),
            sourceName: String(localized: "Mangler data"),
            sourceURL: "",
            groups: []
        )
        if let cached = Self.cachedCatalog(), cached.version >= loaded.version {
            loaded = cached
        }
        catalog = loaded
        pickedPlace = loaded.denmark
        location.onFix = { [weak self] coordinate, names in
            self?.applyGPS(coordinate: coordinate, names: names)
        }
        location.onDenied = { [weak self] in
            // Never keep showing an old island once position is off.
            self?.gpsPlace = nil
            self?.gpsNames = []
            self?.gpsCoordinate = nil
            self?.locationState = .denied
        }
        location.onUnavailable = { [weak self] in
            self?.locationState = .unavailable
        }
        applyLaunchArguments()
        Task { await refreshRemote() }
    }

    // MARK: Query

    var queryDate: Date {
        followToday ? now : calendar.calendar.startOfDay(for: pickedDate)
    }

    var queryPlace: Place {
        if followHere, let gpsPlace { return gpsPlace }
        if followHere { return catalog.denmark }
        return pickedPlace
    }

    var isQueryToday: Bool {
        calendar.calendar.isDate(queryDate, inSameDayAs: now)
    }

    /// Every species, resolved for the query place.
    var resolvedSections: [ResolvedGroup] {
        catalog.resolvedSections(at: queryPlace)
    }

    /// Sun times for the query. Exact at the GPS position; otherwise at the place's
    /// representative point, so approximate. Display only, never used for "jagtbar".
    var querySun: (times: SunTimes, isApproximate: Bool)? {
        if followHere, let gpsCoordinate, gpsPlace != nil {
            return (calendar.sunTimes(on: queryDate, latitude: gpsCoordinate.latitude, longitude: gpsCoordinate.longitude), false)
        }
        guard let point = catalog.coordinate(for: queryPlace) else { return nil }
        return (calendar.sunTimes(on: queryDate, latitude: point.latitude, longitude: point.longitude), true)
    }

    func status(of item: ResolvedSpecies) -> SeasonStatus {
        calendar.status(of: item.periods, on: queryDate)
    }

    func resolved(speciesId: String) -> ResolvedSpecies? {
        guard let species = catalog.allSpecies.first(where: { $0.id == speciesId }) else { return nil }
        return catalog.resolved(species, at: queryPlace)
    }

    func photo(for speciesId: String) -> IdentifiedPhoto? {
        photos?.photo(for: speciesId)
    }

    func biology(for speciesId: String) -> TaxonBiology? {
        biology?.biology(for: speciesId)
    }

    func group(of speciesId: String) -> SpeciesGroup? {
        catalog.groups.first { group in group.species.contains { $0.id == speciesId } }
    }

    func place(id: String?) -> Place? {
        id.flatMap(catalog.place(id:))
    }

    /// The region or country a place sits under, for subtitles.
    func parentName(of place: Place) -> String? {
        guard place.kind == .area || place.kind == .island else { return nil }
        return self.place(id: place.parentId)?.name
    }

    // MARK: Intents

    func useToday() {
        userSelections += 1
        followToday = true
        pickedDate = now
    }

    func select(date: Date) {
        userSelections += 1
        if calendar.calendar.isDate(date, inSameDayAs: now) {
            useToday()
        } else {
            followToday = false
            pickedDate = date
        }
    }

    func useHere() {
        userSelections += 1
        followHere = true
        requestLocation()
    }

    func select(place: Place) {
        userSelections += 1
        followHere = false
        pickedPlace = place
    }

    func requestLocationIfNeeded() {
        guard followHere else { return }
        requestLocation()
    }

    /// A fix for the bag sheet. Does not change whether Jagtbar follows here.
    func locate() {
        requestLocation()
    }

    /// Call when the app comes to the foreground.
    func refreshNow() {
        now = Date()
    }

    /// Pull to refresh.
    func refresh() async {
        refreshNow()
        requestLocationIfNeeded()
        await refreshRemote()
    }

    private func requestLocation() {
        if gpsPlace == nil || locationState != .found {
            locationState = .locating
        }
        location.request()
    }

    private func applyGPS(coordinate: Coordinate, names: [String]) {
        gpsCoordinate = coordinate
        gpsNames = names
        gpsPlace = catalog.matchPlace(names: names)
        locationState = .found
    }

    // MARK: Data

    func refreshRemote() async {
        guard let remoteURL else { return }
        do {
            let (data, response) = try await URLSession.shared.data(from: remoteURL)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                remoteStatus = String(localized: "Bruger indbygget data")
                return
            }
            let remote = try HuntingCatalog.decodeChecked(from: data)
            if remote.version >= catalog.version {
                catalog = remote
                // Places may have moved or gained local times in the new data.
                pickedPlace = catalog.place(id: pickedPlace.id) ?? catalog.denmark
                if !gpsNames.isEmpty {
                    gpsPlace = catalog.matchPlace(names: gpsNames)
                }
                try Self.saveCache(data)
                remoteStatus = String(localized: "Opdateret fra net")
            } else {
                remoteStatus = String(localized: "Indbygget data er nyere")
            }
        } catch is CatalogRefused, is DecodingError {
            // A broken file reaches every phone. Keep the data this one has.
            remoteStatus = String(localized: "Fejl i ny data. Bruger gemt data.")
        } catch {
            remoteStatus = String(localized: "Offline. Bruger gemt data.")
        }
    }

    private static func bundleCatalog() -> HuntingCatalog? {
        let urls = [
            Bundle.main.url(forResource: "jagttider", withExtension: "json"),
            Bundle.main.url(forResource: "jagttider", withExtension: "json", subdirectory: "data")
        ].compactMap { $0 }
        for url in urls {
            if let data = try? Data(contentsOf: url),
               let catalog = try? HuntingCatalog.decode(from: data) {
                return catalog
            }
        }
        return nil
    }

    private static func bundlePhotos() -> SpeciesPhotos? {
        guard let url = Bundle.main.url(forResource: "species-photos", withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return try? SpeciesPhotos.decode(from: data)
    }

    private static func bundleBiology() -> BiologyCatalog? {
        guard let url = Bundle.main.url(forResource: "biologi", withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return try? BiologyCatalog.decode(from: data)
    }

    private static var cacheURL: URL {
        let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return folder.appending(path: "jagttider.json")
    }

    private static func cachedCatalog() -> HuntingCatalog? {
        guard let data = try? Data(contentsOf: cacheURL) else { return nil }
        return try? HuntingCatalog.decodeChecked(from: data)
    }

    private static func saveCache(_ data: Data) throws {
        let folder = cacheURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try data.write(to: cacheURL, options: .atomic)
    }

    /// Debug only: `-date 2026-11-15 -place als` for screenshots and manual checks.
    private func applyLaunchArguments() {
        #if DEBUG
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: "date") {
            let parts = raw.split(separator: "-").compactMap { Int($0) }
            if parts.count == 3,
               let date = calendar.calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12)) {
                select(date: date)
            }
        }
        if let id = defaults.string(forKey: "place"), let place = catalog.place(id: id) {
            select(place: place)
        }
        #endif
    }
}
