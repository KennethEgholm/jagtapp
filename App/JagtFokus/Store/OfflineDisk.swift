import Foundation
import os

/// The saved areas on disk, behind one actor. `OfflineAreaStore` has no locking, so every
/// call goes through here, one at a time, off the main actor.
actor OfflineDisk {
    struct Snapshot: Sendable {
        var index: OfflineAreaIndex
        var parcels: [UUID: ParcelSet]
        /// False when `omraader.json` exists but cannot be read. The index then looks empty,
        /// and writing to it would orphan every saved area, so nothing writes.
        var isKnown: Bool
    }

    struct Unknown: Error {}

    private let store: OfflineAreaStore
    private var isKnown = false
    private static let log = Logger(subsystem: "dk.jagtfokus.app", category: "offline")

    init(folder: URL = OfflineDisk.defaultFolder) {
        store = OfflineAreaStore(folder: folder)
    }

    static var defaultFolder: URL {
        URL.applicationSupportDirectory.appending(path: "Kort", directoryHint: .isDirectory)
    }

    /// Reads the index by decoding it: no file is an empty index, a file that cannot be decoded
    /// is unknown (and nothing writes). Orphan parcel files go; failing to remove one is only logged.
    func launch() -> Snapshot {
        switch store.indexState() {
        case .unreadable:
            isKnown = false
            Self.log.error("omraader.json cannot be read; saved areas are left alone")
            return Snapshot(index: OfflineAreaIndex(), parcels: [:], isKnown: false)
        case .known(let index):
            isKnown = true
            do {
                try store.removeOrphans()
            } catch {
                Self.log.error("orphan files could not be removed")
            }
            var parcels: [UUID: ParcelSet] = [:]
            for area in index.areas {
                if let set = store.parcels(for: area.id) {
                    parcels[area.id] = set
                } else {
                    Self.log.error("parcels file for an indexed area is missing or broken")
                }
            }
            return Snapshot(index: index, parcels: parcels, isKnown: true)
        }
    }

    /// Everything in the Kort folder goes, and the index is known and empty again.
    func reset() throws {
        try store.reset()
        isKnown = true
    }

    /// Parcels file, then the index. The pack must be complete before this is called.
    func commit(
        id: UUID,
        name: String,
        box: GeoBox,
        parcels: ParcelSet,
        packBytes: Int,
        basemapTiles: String
    ) throws -> (area: OfflineArea, index: OfflineAreaIndex) {
        guard isKnown else { throw Unknown() }
        let parcelBytes = try parcels.geoJSON().count
        let area = OfflineArea(
            id: id,
            name: name,
            box: box,
            savedAt: Date(),
            parcelCount: parcels.count,
            bytes: parcelBytes + packBytes,
            basemapTiles: basemapTiles
        )
        try store.commit(area, parcels: parcels)
        return (area, store.loadIndex())
    }

    /// A refreshed basemap: the same area, the new tile template. nil when the area is gone.
    func replace(_ area: OfflineArea) throws -> OfflineAreaIndex? {
        guard isKnown else { throw Unknown() }
        var index = store.loadIndex()
        guard index.areas.contains(where: { $0.id == area.id }) else { return nil }
        index.replace(area)
        try store.saveIndex(index)
        return index
    }

    func delete(id: UUID) throws -> OfflineAreaIndex {
        guard isKnown else { throw Unknown() }
        try store.delete(id: id)
        return store.loadIndex()
    }
}
