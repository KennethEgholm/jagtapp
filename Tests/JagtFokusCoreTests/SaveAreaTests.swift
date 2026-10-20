import Foundation
import Testing
@testable import JagtFokusCore

struct SaveAreaTests {
    func area(_ id: UUID = UUID()) -> OfflineArea {
        OfflineArea(
            id: id,
            name: "Område 1",
            box: .around(Coordinate(latitude: 56.16, longitude: 10.20), sideMeters: 5_000),
            savedAt: Date(timeIntervalSince1970: 0),
            parcelCount: 1,
            bytes: 1,
            basemapTiles: "t"
        )
    }

    // MARK: Orphan packs

    @Test func packsWithoutARowInTheIndexAreOrphans() {
        let kept = UUID(), orphan = UUID()
        let index = OfflineAreaIndex(areas: [area(kept)])
        let result = OfflineCleanup.orphanPackIDs(packIDs: [kept, orphan], index: index, indexIsKnown: true)
        #expect(result == [orphan])
    }

    @Test func everyPackIsAnOrphanWhenTheIndexIsKnownToBeEmpty() {
        let a = UUID(), b = UUID()
        let result = OfflineCleanup.orphanPackIDs(packIDs: [a, b], index: OfflineAreaIndex(), indexIsKnown: true)
        #expect(result == [a, b])
    }

    @Test func nothingIsRemovedWhenTheIndexIsUnknown() {
        // An unreadable omraader.json looks empty. Deleting packs then would delete the user's areas.
        let result = OfflineCleanup.orphanPackIDs(packIDs: [UUID(), UUID()], index: OfflineAreaIndex(), indexIsKnown: false)
        #expect(result.isEmpty)
    }

    // MARK: Pack limits

    @Test func aPackWithinTheLimitsPasses() {
        #expect(!PackLimits.exceeded(tiles: 3_000, bytes: 50_000_000))
        #expect(!PackLimits.exceeded(tiles: 0, bytes: 0))
    }

    @Test func tooManyTilesOrBytesExceedTheLimits() {
        #expect(PackLimits.exceeded(tiles: 3_001, bytes: 1))
        #expect(PackLimits.exceeded(tiles: 1, bytes: 50_000_001))
    }

    // MARK: Progress

    @Test func parcelsTakeTheFirstFifthOfTheBar() {
        #expect(SaveProgress.overall(parcelsDone: 0, of: 4, pack: 0) == 0)
        #expect(abs(SaveProgress.overall(parcelsDone: 2, of: 4, pack: 0) - 0.1) < 1e-9)
        #expect(abs(SaveProgress.overall(parcelsDone: 4, of: 4, pack: 0) - 0.2) < 1e-9)
    }

    @Test func thePackFillsTheRestAndIsClamped() {
        #expect(abs(SaveProgress.overall(parcelsDone: 4, of: 4, pack: 0.5) - 0.6) < 1e-9)
        #expect(SaveProgress.overall(parcelsDone: 4, of: 4, pack: 1) == 1)
        #expect(SaveProgress.overall(parcelsDone: 4, of: 4, pack: 7) == 1)
        #expect(SaveProgress.overall(parcelsDone: 9, of: 4, pack: -1) == 0.2)
        #expect(SaveProgress.overall(parcelsDone: 0, of: 0, pack: 0) == 0)
    }

    // MARK: Offline plan

    @Test func offlineWithoutASavedAreaFetchesNothing() {
        let view = GeoBox.around(Coordinate(latitude: 56.16, longitude: 10.20), sideMeters: 1_000)
        #expect(LiveBoundaries.plan(for: view, zoom: 16, areas: [], isOnline: false) == .offline)
        #expect(LiveBoundaries.plan(for: view, zoom: 16, areas: [], isOnline: true) == .fetch)
    }

    @Test func offlineInsideASavedAreaStillShowsIt() {
        let saved = area()
        let view = GeoBox.around(Coordinate(latitude: 56.16, longitude: 10.20), sideMeters: 1_000)
        #expect(LiveBoundaries.plan(for: view, zoom: 16, areas: [saved], isOnline: false) == .savedArea(saved))
    }

    @Test func zoomAndSizeDecideBeforeTheNetworkDoes() {
        let near = GeoBox.around(Coordinate(latitude: 56.16, longitude: 10.20), sideMeters: 1_000)
        let wide = GeoBox.around(Coordinate(latitude: 56.16, longitude: 10.20), sideMeters: 8_000)
        #expect(LiveBoundaries.plan(for: near, zoom: 10, areas: [], isOnline: false) == .tooFarOut)
        #expect(LiveBoundaries.plan(for: wide, zoom: 14, areas: [], isOnline: false) == .tooLarge)
    }
}

// MARK: - Index readability and reset

struct IndexStateTests {
    func temporaryStore() -> (OfflineAreaStore, URL) {
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        return (OfflineAreaStore(folder: dir), dir)
    }

    func area() -> OfflineArea {
        OfflineArea(
            id: UUID(),
            name: "Område 1",
            box: .around(Coordinate(latitude: 56.16, longitude: 10.20), sideMeters: 5_000),
            savedAt: Date(timeIntervalSince1970: 0),
            parcelCount: 0,
            bytes: 1,
            basemapTiles: "t"
        )
    }

    @Test func noFolderAndNoFileIsKnownAndEmpty() {
        let (store, _) = temporaryStore()
        #expect(store.indexState() == .known(OfflineAreaIndex()))
    }

    @Test func aReadableIndexIsKnown() throws {
        let (store, dir) = temporaryStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let saved = area()
        try store.commit(saved, parcels: ParcelSet(parcels: []))
        #expect(store.indexState() == .known(OfflineAreaIndex(areas: [saved])))
    }

    @Test func aFileThatCannotBeDecodedIsUnreadableNotEmpty() throws {
        let (store, dir) = temporaryStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("{ not json".utf8).write(to: dir.appending(path: "omraader.json"))
        #expect(store.indexState() == .unreadable)
    }

    @Test func resetRemovesEverythingAndLeavesAKnownEmptyIndex() throws {
        let (store, dir) = temporaryStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        try store.commit(area(), parcels: ParcelSet(parcels: []))
        try Data("{ not json".utf8).write(to: dir.appending(path: "omraader.json"))
        try Data("x".utf8).write(to: dir.appending(path: "stray.geojson"))
        try store.reset()
        #expect(store.indexState() == .known(OfflineAreaIndex()))
        let left = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        #expect(left.isEmpty)
    }

    @Test func resetWithoutAFolderIsFine() throws {
        let (store, _) = temporaryStore()
        try store.reset()
        #expect(store.indexState() == .known(OfflineAreaIndex()))
    }
}

// MARK: - Stall watch

struct StallWatchTests {
    @Test func stallsAfterTheLimitOfActiveQuietTime() {
        var watch = StallWatch(limitSeconds: 60)
        for _ in 0..<11 {
            let stalled = watch.tick(seconds: 5, isActive: true)
            #expect(!stalled)
        }
        let stalled = watch.tick(seconds: 5, isActive: true)
        #expect(stalled)
    }

    @Test func timeInTheBackgroundDoesNotCount() {
        var watch = StallWatch(limitSeconds: 60)
        // Ten minutes of ticks while suspended, then back.
        for _ in 0..<120 {
            let stalled = watch.tick(seconds: 5, isActive: false)
            #expect(!stalled)
        }
        let stalled = watch.tick(seconds: 5, isActive: true)
        #expect(!stalled)
    }

    @Test func progressAndComingBackStartTheCountAgain() {
        var watch = StallWatch(limitSeconds: 60)
        for _ in 0..<11 { _ = watch.tick(seconds: 5, isActive: true) }
        watch.progress()
        for _ in 0..<11 {
            let stalled = watch.tick(seconds: 5, isActive: true)
            #expect(!stalled)
        }
        watch.becameActive()
        for _ in 0..<11 {
            let stalled = watch.tick(seconds: 5, isActive: true)
            #expect(!stalled)
        }
        let stalled = watch.tick(seconds: 5, isActive: true)
        #expect(stalled)
    }
}
