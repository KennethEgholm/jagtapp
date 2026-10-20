import Foundation

/// A 5 km square the user saved for use without a network: its parcels (in a file)
/// and a basemap pack (inside MapLibre's own database).
public struct OfflineArea: Codable, Sendable, Equatable, Identifiable, Hashable {
    public var id: UUID
    public var name: String
    public var box: GeoBox
    public var savedAt: Date
    public var parcelCount: Int
    /// Parcels file + basemap pack, at save.
    public var bytes: Int
    /// The OpenFreeMap tile template the pack was saved with.
    public var basemapTiles: String

    public init(
        id: UUID,
        name: String,
        box: GeoBox,
        savedAt: Date,
        parcelCount: Int,
        bytes: Int,
        basemapTiles: String
    ) {
        self.id = id
        self.name = name
        self.box = box
        self.savedAt = savedAt
        self.parcelCount = parcelCount
        self.bytes = bytes
        self.basemapTiles = basemapTiles
    }
}

/// The list of saved areas, newest first. This is the file the app trusts: an area
/// that is not here does not exist, whatever else is on disk.
public struct OfflineAreaIndex: Codable, Sendable, Equatable {
    public var areas: [OfflineArea]
    /// OpenFreeMap's TileJSON as it was when every saved area's basemap pack was complete for it.
    /// Offline, the map is given these bytes, so it asks for the tiles the packs hold, not a newer
    /// week's. In the index, so the areas' templates and the pin change in one atomic write.
    public var pinnedTileJSON: Data?

    public init(areas: [OfflineArea] = [], pinnedTileJSON: Data? = nil) {
        self.areas = areas
        self.pinnedTileJSON = pinnedTileJSON
    }

    /// The weekly tile template the pin names.
    public var pinnedTiles: String? {
        pinnedTileJSON.flatMap { try? OpenFreeMap.tilesTemplate(fromTileJSON: $0) }
    }

    public mutating func add(_ area: OfflineArea) {
        areas.insert(area, at: 0)
    }

    /// A save, with the TileJSON its pack was downloaded with. The pin moves only when it can
    /// speak for every area: there is none yet, or every area is now on the save's week.
    public mutating func add(_ area: OfflineArea, tileJSON: Data) {
        add(area)
        movePin(to: tileJSON, tiles: area.basemapTiles, force: pinnedTileJSON == nil)
    }

    /// Every new pack of a refresh is complete: the refreshed areas get the template, and the pin
    /// moves when every area is on it.
    public func refreshed(ids: Set<UUID>, tiles: String, tileJSON: Data) -> OfflineAreaIndex {
        var copy = self
        for position in copy.areas.indices where ids.contains(copy.areas[position].id) {
            copy.areas[position].basemapTiles = tiles
        }
        copy.movePin(to: tileJSON, tiles: tiles, force: false)
        return copy
    }

    private mutating func movePin(to tileJSON: Data, tiles: String, force: Bool) {
        if force || areas.allSatisfy({ $0.basemapTiles == tiles }) {
            pinnedTileJSON = tileJSON
        }
    }

    /// Same id, same position. For a basemap refresh.
    public mutating func replace(_ area: OfflineArea) {
        guard let position = areas.firstIndex(where: { $0.id == area.id }) else { return }
        areas[position] = area
    }

    /// The last area takes the pin with it: with nothing saved there is nothing to pin.
    public mutating func remove(id: UUID) {
        areas.removeAll { $0.id == id }
        if areas.isEmpty { pinnedTileJSON = nil }
    }

    public func intersecting(_ box: GeoBox) -> [OfflineArea] {
        areas.filter { $0.box.intersects(box) }
    }

    public func containing(_ point: Coordinate) -> OfflineArea? {
        areas.first { $0.box.contains(point) }
    }

    /// Areas whose basemap pack was saved with another week's tile URL than the current
    /// one. Offline, such a pack may be out of reach, so the app downloads it again.
    public func staleBasemaps(currentTiles: String) -> [OfflineArea] {
        areas.filter { $0.basemapTiles != currentTiles }
    }

    /// "Område 2" when "Område 1" and "Område 3" exist: the lowest number not taken.
    public func nextDefaultName(prefix: String) -> String {
        let taken = Set(areas.map(\.name))
        var number = 1
        while taken.contains("\(prefix) \(number)") {
            number += 1
        }
        return "\(prefix) \(number)"
    }

    public static func decode(from data: Data) throws -> OfflineAreaIndex {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(OfflineAreaIndex.self, from: data)
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}

/// Saved areas on disk: `omraader.json` (the index) and one `<uuid>.geojson` per area.
/// `savedAt` lives in the index. File modification dates are never read.
public struct OfflineAreaStore: Sendable {
    public let folder: URL

    public init(folder: URL) {
        self.folder = folder
    }

    private var indexURL: URL { folder.appending(path: "omraader.json") }

    private func parcelsURL(for id: UUID) -> URL {
        folder.appending(path: "\(id.uuidString).geojson")
    }

    /// Whether the index can be trusted.
    public enum IndexState: Equatable, Sendable {
        /// Read, or not there yet (nothing saved): safe to write to.
        case known(OfflineAreaIndex)
        /// The file is there but cannot be decoded. It looks empty, and writing would orphan every area.
        case unreadable
    }

    /// No file is a known, empty index. A file that cannot be decoded is `.unreadable`.
    public func indexState() -> IndexState {
        guard FileManager.default.fileExists(atPath: indexURL.path) else { return .known(OfflineAreaIndex()) }
        guard let data = try? Data(contentsOf: indexURL),
              let index = try? OfflineAreaIndex.decode(from: data) else {
            return .unreadable
        }
        return .known(index)
    }

    /// Removes everything in the folder: the way out of an unreadable index.
    public func reset() throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: folder.path) else { return }
        for url in try fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) {
            try fm.removeItem(at: url)
        }
    }

    /// A missing or broken file gives an empty index.
    public func loadIndex() -> OfflineAreaIndex {
        guard let data = try? Data(contentsOf: indexURL),
              let index = try? OfflineAreaIndex.decode(from: data) else {
            return OfflineAreaIndex()
        }
        return index
    }

    public func parcels(for id: UUID) -> ParcelSet? {
        guard let data = try? Data(contentsOf: parcelsURL(for: id)) else { return nil }
        return try? ParcelSet.decodeChecked(from: data)
    }

    /// Parcels file first, index last: a crash leaves at most an orphan file. `tileJSON` is the
    /// TileJSON the area's pack was downloaded with; it may become the pin.
    public func commit(_ area: OfflineArea, parcels: ParcelSet, tileJSON: Data? = nil) throws {
        try createFolder()
        try parcels.geoJSON().write(to: parcelsURL(for: area.id), options: .atomic)
        var index = loadIndex()
        index.areas.removeAll { $0.id == area.id }
        if let tileJSON {
            index.add(area, tileJSON: tileJSON)
        } else {
            index.add(area)
        }
        try saveIndex(index)
    }

    public func saveIndex(_ index: OfflineAreaIndex) throws {
        try createFolder()
        try index.encoded().write(to: indexURL, options: .atomic)
    }

    /// Index row first, file last, so a crash again leaves only an orphan.
    public func delete(id: UUID) throws {
        var index = loadIndex()
        index.remove(id: id)
        try saveIndex(index)
        let url = parcelsURL(for: id)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    /// Deletes parcel files that have no row in the index. An index that exists but
    /// cannot be read is a reason to do nothing: every file would look like an orphan.
    public func removeOrphans() throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: folder.path) else { return }
        let known: Set<UUID>
        if fm.fileExists(atPath: indexURL.path) {
            let index = try OfflineAreaIndex.decode(from: Data(contentsOf: indexURL))
            known = Set(index.areas.map(\.id))
        } else {
            known = []
        }
        for url in try fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) {
            guard url.pathExtension == "geojson",
                  let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent),
                  !known.contains(id) else { continue }
            try fm.removeItem(at: url)
        }
    }

    private func createFolder() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }
}
