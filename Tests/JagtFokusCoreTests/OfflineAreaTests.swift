import Foundation
import Testing
@testable import JagtFokusCore

struct OfflineAreaTests {
    static let oldTiles = "https://tiles.openfreemap.org/planet/20261008_001001_pt/{z}/{x}/{y}.pbf"
    static let newTiles = "https://tiles.openfreemap.org/planet/20261015_001001_pt/{z}/{x}/{y}.pbf"

    func area(
        _ name: String,
        at center: Coordinate = Coordinate(latitude: 56.16, longitude: 10.20),
        savedAt: TimeInterval = 1_792_000_000,
        tiles: String = OfflineAreaTests.newTiles
    ) -> OfflineArea {
        OfflineArea(
            id: UUID(),
            name: name,
            box: .around(center, sideMeters: 5_000),
            savedAt: Date(timeIntervalSince1970: savedAt),
            parcelCount: 12,
            bytes: 1_000_000,
            basemapTiles: tiles
        )
    }

    func parcels() -> ParcelSet {
        ParcelSet(parcels: [
            Parcel(
                id: "Jordstykke_Gaeldende.1",
                number: "1924",
                district: "",
                polygons: [[[
                    Coordinate(latitude: 56.161457, longitude: 10.200533),
                    Coordinate(latitude: 56.161356, longitude: 10.200220),
                    Coordinate(latitude: 56.161326, longitude: 10.200131),
                    Coordinate(latitude: 56.161457, longitude: 10.200533),
                ]]]
            ),
        ])
    }

    func temporaryStore() -> (OfflineAreaStore, URL) {
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        return (OfflineAreaStore(folder: dir), dir)
    }

    // MARK: Index

    @Test func roundTrips() throws {
        var index = OfflineAreaIndex()
        index.add(area("Område 1", savedAt: 1_792_000_000))
        index.add(area("Område 2", savedAt: 1_792_100_000))
        let decoded = try OfflineAreaIndex.decode(from: index.encoded())
        #expect(decoded == index)
    }

    @Test func newestFirst() {
        var index = OfflineAreaIndex()
        let first = area("A")
        let second = area("B")
        index.add(first)
        index.add(second)
        #expect(index.areas.map(\.name) == ["B", "A"])
    }

    @Test func removeById() {
        var index = OfflineAreaIndex()
        let first = area("A")
        let second = area("B")
        index.add(first)
        index.add(second)
        index.remove(id: first.id)
        #expect(index.areas == [second])
    }

    @Test func replaceKeepsPosition() {
        var index = OfflineAreaIndex()
        let first = area("A", tiles: Self.oldTiles)
        let second = area("B")
        index.add(first)
        index.add(second)
        var refreshed = first
        refreshed.basemapTiles = Self.newTiles
        index.replace(refreshed)
        #expect(index.areas.map(\.id) == [second.id, first.id])
        #expect(index.areas[1].basemapTiles == Self.newTiles)
    }

    @Test func containingPicksTheAreaUnderThePoint() {
        var index = OfflineAreaIndex()
        let aarhus = area("Aarhus", at: Coordinate(latitude: 56.16, longitude: 10.20))
        let odense = area("Odense", at: Coordinate(latitude: 55.40, longitude: 10.39))
        index.add(aarhus)
        index.add(odense)
        #expect(index.containing(Coordinate(latitude: 56.161, longitude: 10.201))?.id == aarhus.id)
        #expect(index.containing(Coordinate(latitude: 55.401, longitude: 10.391))?.id == odense.id)
        #expect(index.containing(Coordinate(latitude: 57.0, longitude: 9.0)) == nil)
    }

    @Test func intersectingSkipsFarAreas() {
        var index = OfflineAreaIndex()
        let aarhus = area("Aarhus", at: Coordinate(latitude: 56.16, longitude: 10.20))
        let odense = area("Odense", at: Coordinate(latitude: 55.40, longitude: 10.39))
        index.add(aarhus)
        index.add(odense)
        let view = GeoBox.around(Coordinate(latitude: 56.17, longitude: 10.21), sideMeters: 3_000)
        #expect(index.intersecting(view).map(\.id) == [aarhus.id])
    }

    @Test func nextDefaultNameFillsTheGap() {
        var index = OfflineAreaIndex()
        #expect(index.nextDefaultName(prefix: "Område") == "Område 1")
        index.add(area("Område 1"))
        index.add(area("Område 3"))
        index.add(area("Jagtmarken"))
        #expect(index.nextDefaultName(prefix: "Område") == "Område 2")
        index.add(area("Område 2"))
        #expect(index.nextDefaultName(prefix: "Område") == "Område 4")
    }

    @Test func staleBasemapsComparesTheTemplate() {
        var index = OfflineAreaIndex()
        let stale = area("Gammel", tiles: Self.oldTiles)
        let fresh = area("Ny", tiles: Self.newTiles)
        index.add(stale)
        index.add(fresh)
        #expect(index.staleBasemaps(currentTiles: Self.newTiles).map(\.id) == [stale.id])
        #expect(index.staleBasemaps(currentTiles: Self.oldTiles).map(\.id) == [fresh.id])
    }

    // MARK: Store

    @Test func commitWritesParcelsThenIndex() throws {
        let (store, dir) = temporaryStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let saved = area("Område 1")
        try store.commit(saved, parcels: parcels())

        #expect(FileManager.default.fileExists(atPath: dir.appending(path: "\(saved.id.uuidString).geojson").path))
        #expect(FileManager.default.fileExists(atPath: dir.appending(path: "omraader.json").path))
        #expect(store.loadIndex().areas == [saved])
        #expect(store.parcels(for: saved.id) == parcels())
        #expect(store.parcels(for: UUID()) == nil)
    }

    @Test func orphanParcelsAreRemoved() throws {
        let (store, dir) = temporaryStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let kept = area("Område 1")
        try store.commit(kept, parcels: parcels())

        // A crash between the parcels file and the index row.
        let orphanId = UUID()
        let orphanURL = dir.appending(path: "\(orphanId.uuidString).geojson")
        try parcels().geoJSON().write(to: orphanURL)

        try store.removeOrphans()

        #expect(!FileManager.default.fileExists(atPath: orphanURL.path))
        #expect(store.parcels(for: kept.id) != nil)
        #expect(store.loadIndex().areas == [kept])
    }

    @Test func brokenIndexKeepsTheParcelFiles() throws {
        let (store, dir) = temporaryStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let saved = area("Område 1")
        try store.commit(saved, parcels: parcels())
        try Data("ikke-json".utf8).write(to: dir.appending(path: "omraader.json"))

        #expect(throws: (any Error).self) { try store.removeOrphans() }
        #expect(store.parcels(for: saved.id) != nil)
    }

    @Test func brokenIndexLoadsEmpty() throws {
        let (store, dir) = temporaryStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        #expect(store.loadIndex().areas.isEmpty)

        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("ikke-json".utf8).write(to: dir.appending(path: "omraader.json"))
        #expect(store.loadIndex().areas.isEmpty)
    }

    @Test func deleteRemovesBoth() throws {
        let (store, dir) = temporaryStore()
        defer { try? FileManager.default.removeItem(at: dir) }

        let first = area("A")
        let second = area("B")
        try store.commit(first, parcels: parcels())
        try store.commit(second, parcels: parcels())

        try store.delete(id: first.id)

        #expect(store.loadIndex().areas == [second])
        #expect(store.parcels(for: first.id) == nil)
        #expect(!FileManager.default.fileExists(atPath: dir.appending(path: "\(first.id.uuidString).geojson").path))
        #expect(store.parcels(for: second.id) != nil)
    }
}
