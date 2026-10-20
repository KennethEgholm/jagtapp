import Foundation
import Testing
@testable import JagtFokusCore

/// The pinned TileJSON: the week every saved area's basemap pack is complete for.
struct BasemapPinTests {
    static let oldTiles = "https://tiles.openfreemap.org/planet/20261008_001001_pt/{z}/{x}/{y}.pbf"
    static let newTiles = "https://tiles.openfreemap.org/planet/20261015_001001_pt/{z}/{x}/{y}.pbf"

    static func tileJSON(_ tiles: String) -> Data {
        Data(#"{"tiles":["\#(tiles)"],"maxzoom":14}"#.utf8)
    }

    func area(_ id: UUID = UUID(), tiles: String) -> OfflineArea {
        OfflineArea(
            id: id,
            name: "Område",
            box: .around(Coordinate(latitude: 56.16, longitude: 10.20), sideMeters: 5_000),
            savedAt: Date(timeIntervalSince1970: 1_792_000_000),
            parcelCount: 1,
            bytes: 1,
            basemapTiles: tiles
        )
    }

    // MARK: Pin in the index

    @Test func thePinRoundTripsAndNamesItsWeek() throws {
        var index = OfflineAreaIndex(areas: [area(tiles: Self.oldTiles)])
        index.pinnedTileJSON = Self.tileJSON(Self.oldTiles)
        let decoded = try OfflineAreaIndex.decode(from: index.encoded())
        #expect(decoded.pinnedTileJSON == Self.tileJSON(Self.oldTiles))
        #expect(decoded.pinnedTiles == Self.oldTiles)
    }

    @Test func anIndexWithoutAPinStillReads() throws {
        let old = #"{"areas":[]}"#
        let index = try OfflineAreaIndex.decode(from: Data(old.utf8))
        #expect(index.pinnedTileJSON == nil)
        #expect(index.pinnedTiles == nil)
    }

    @Test func theFirstSavePins() {
        var index = OfflineAreaIndex()
        index.add(area(tiles: Self.newTiles), tileJSON: Self.tileJSON(Self.newTiles))
        #expect(index.pinnedTiles == Self.newTiles)
    }

    @Test func aSaveOnANewWeekKeepsTheOldPinWhileOtherAreasAreOnTheOldWeek() {
        var index = OfflineAreaIndex(areas: [area(tiles: Self.oldTiles)])
        index.pinnedTileJSON = Self.tileJSON(Self.oldTiles)
        index.add(area(tiles: Self.newTiles), tileJSON: Self.tileJSON(Self.newTiles))
        // The old area's pack is complete only for the old week: the pin stays until the refresh.
        #expect(index.pinnedTiles == Self.oldTiles)
    }

    @Test func aSaveOnThePinnedWeekKeepsThePin() {
        var index = OfflineAreaIndex(areas: [area(tiles: Self.newTiles)])
        index.pinnedTileJSON = Self.tileJSON(Self.newTiles)
        index.add(area(tiles: Self.newTiles), tileJSON: Self.tileJSON(Self.newTiles))
        #expect(index.pinnedTiles == Self.newTiles)
    }

    @Test func deletingTheLastAreaDropsThePin() {
        let id = UUID()
        var index = OfflineAreaIndex(areas: [area(id, tiles: Self.newTiles), area(tiles: Self.newTiles)])
        index.pinnedTileJSON = Self.tileJSON(Self.newTiles)
        index.remove(id: id)
        #expect(index.pinnedTileJSON != nil)
        index.remove(id: index.areas[0].id)
        #expect(index.pinnedTileJSON == nil)
    }

    @Test func theStoreKeepsThePinThroughCommitAndDeleteAndResetRemovesIt() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let store = OfflineAreaStore(folder: folder)
        let first = area(tiles: Self.newTiles)
        let second = area(tiles: Self.newTiles)
        let parcels = ParcelSet(parcels: [])
        try store.commit(first, parcels: parcels, tileJSON: Self.tileJSON(Self.newTiles))
        try store.commit(second, parcels: parcels, tileJSON: Self.tileJSON(Self.newTiles))
        try store.delete(id: first.id)
        #expect(store.loadIndex().pinnedTiles == Self.newTiles)
        try store.reset()
        #expect(store.loadIndex().pinnedTileJSON == nil)
    }

    // MARK: Refresh

    @Test func nothingToRefreshWhenEveryAreaAndThePinAreCurrent() {
        var index = OfflineAreaIndex(areas: [area(tiles: Self.newTiles)])
        index.pinnedTileJSON = Self.tileJSON(Self.newTiles)
        let plan = BasemapRefresh.plan(index: index, currentTiles: Self.newTiles)
        #expect(plan.stale.isEmpty)
        #expect(!plan.movesPin)
        #expect(!plan.isNeeded)
        #expect(!BasemapRefresh.plan(index: OfflineAreaIndex(), currentTiles: Self.newTiles).isNeeded)
    }

    @Test func aNewWeekRefreshesEveryStaleAreaAndMovesThePin() {
        let fresh = area(tiles: Self.newTiles)
        let stale1 = area(tiles: Self.oldTiles), stale2 = area(tiles: Self.oldTiles)
        var index = OfflineAreaIndex(areas: [stale1, fresh, stale2])
        index.pinnedTileJSON = Self.tileJSON(Self.oldTiles)
        let plan = BasemapRefresh.plan(index: index, currentTiles: Self.newTiles)
        #expect(plan.stale.map(\.id) == [stale1.id, stale2.id])
        #expect(plan.movesPin)
    }

    @Test func anIndexWithoutAPinGetsOneWithoutNewPacks() {
        // Saved before the pin existed, on the current week: only the pin is written.
        let plan = BasemapRefresh.plan(index: OfflineAreaIndex(areas: [area(tiles: Self.newTiles)]), currentTiles: Self.newTiles)
        #expect(plan.stale.isEmpty)
        #expect(plan.movesPin)
        #expect(plan.isNeeded)
    }

    @Test func aCompleteRefreshUpdatesEveryAreaAndThePinInOneIndex() {
        let a = area(tiles: Self.oldTiles), b = area(tiles: Self.oldTiles)
        var index = OfflineAreaIndex(areas: [a, b])
        index.pinnedTileJSON = Self.tileJSON(Self.oldTiles)
        let updated = index.refreshed(ids: [a.id, b.id], tiles: Self.newTiles, tileJSON: Self.tileJSON(Self.newTiles))
        #expect(updated.areas.allSatisfy { $0.basemapTiles == Self.newTiles })
        #expect(updated.areas.map(\.id) == [a.id, b.id])
        #expect(updated.pinnedTiles == Self.newTiles)
    }

    @Test func aRefreshThatLeftAnAreaBehindDoesNotMoveThePin() {
        let a = area(tiles: Self.oldTiles), b = area(tiles: Self.oldTiles)
        var index = OfflineAreaIndex(areas: [a, b])
        index.pinnedTileJSON = Self.tileJSON(Self.oldTiles)
        let updated = index.refreshed(ids: [a.id], tiles: Self.newTiles, tileJSON: Self.tileJSON(Self.newTiles))
        #expect(updated.pinnedTiles == Self.oldTiles)
    }

    // MARK: Packs at launch

    @Test func aPackContextCarriesTheIdAndTheWeek() {
        let id = UUID()
        let data = PackContext.encode(id: id, tiles: Self.newTiles)
        #expect(PackContext.decode(data) == PackRecord(id: id, tiles: Self.newTiles))
        // Packs saved before the week was in the context: the id alone.
        #expect(PackContext.decode(Data(id.uuidString.utf8)) == PackRecord(id: id, tiles: nil))
        #expect(PackContext.decode(Data("nonsense".utf8)) == nil)
    }

    @Test func aKilledRefreshKeepsThePackOfTheIndexWeek() {
        let id = UUID()
        let index = OfflineAreaIndex(areas: [area(id, tiles: Self.oldTiles)])
        let packs = [PackRecord(id: id, tiles: Self.newTiles), PackRecord(id: id, tiles: Self.oldTiles)]
        #expect(OfflineCleanup.packsToRemove(packs, index: index, indexIsKnown: true) == [0])
    }

    @Test func killedAfterTheIndexMovedKeepsTheNewPack() {
        let id = UUID()
        let index = OfflineAreaIndex(areas: [area(id, tiles: Self.newTiles)])
        let packs = [PackRecord(id: id, tiles: Self.oldTiles), PackRecord(id: id, tiles: Self.newTiles)]
        #expect(OfflineCleanup.packsToRemove(packs, index: index, indexIsKnown: true) == [0])
    }

    @Test func orphansGoAndAnOldContextCountsAsTheIndexWeek() {
        let kept = UUID(), orphan = UUID()
        let index = OfflineAreaIndex(areas: [area(kept, tiles: Self.newTiles)])
        let packs = [PackRecord(id: orphan, tiles: Self.newTiles), PackRecord(id: kept, tiles: nil)]
        #expect(OfflineCleanup.packsToRemove(packs, index: index, indexIsKnown: true) == [0])
    }

    @Test func noPackOfTheIndexWeekKeepsThemAll() {
        // Should not happen. The basemap the user has is better than none; the next refresh mends it.
        let id = UUID()
        let index = OfflineAreaIndex(areas: [area(id, tiles: Self.newTiles)])
        let packs = [PackRecord(id: id, tiles: Self.oldTiles), PackRecord(id: id, tiles: "other")]
        #expect(OfflineCleanup.packsToRemove(packs, index: index, indexIsKnown: true).isEmpty)
    }

    @Test func twoPacksOfTheIndexWeekKeepOne() {
        let id = UUID()
        let index = OfflineAreaIndex(areas: [area(id, tiles: Self.newTiles)])
        let packs = [PackRecord(id: id, tiles: Self.newTiles), PackRecord(id: id, tiles: Self.newTiles)]
        #expect(OfflineCleanup.packsToRemove(packs, index: index, indexIsKnown: true) == [1])
    }

    @Test func anUnknownIndexRemovesNoPack() {
        let packs = [PackRecord(id: UUID(), tiles: Self.newTiles)]
        #expect(OfflineCleanup.packsToRemove(packs, index: OfflineAreaIndex(), indexIsKnown: false).isEmpty)
    }

    // MARK: Serving the pin

    @Test func onlyTheTileJSONURLIsPinned() {
        #expect(BasemapPin.isTileJSON(URL(string: "https://tiles.openfreemap.org/planet")!))
        #expect(!BasemapPin.isTileJSON(URL(string: "https://tiles.openfreemap.org/planet/20261015_001001_pt/14/1/2.pbf")!))
        #expect(!BasemapPin.isTileJSON(URL(string: "https://tiles.openfreemap.org/styles/liberty")!))
        #expect(!BasemapPin.isTileJSON(URL(string: "http://example.com/planet")!))
    }

    @Test func theMapGetsThePinWhenTheNetworkIsGone() {
        for code in [URLError.Code.notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost, .dataNotAllowed, .internationalRoamingOff] {
            #expect(BasemapPin.serves(after: URLError(code), hasPin: true, isDownloadingPack: false))
        }
    }

    @Test func noPinNoPackDownloadAndNoOtherError() {
        #expect(!BasemapPin.serves(after: URLError(.notConnectedToInternet), hasPin: false, isDownloadingPack: false))
        // A pack must fetch this week's TileJSON or fail, never the pinned one.
        #expect(!BasemapPin.serves(after: URLError(.notConnectedToInternet), hasPin: true, isDownloadingPack: true))
        #expect(!BasemapPin.serves(after: URLError(.badServerResponse), hasPin: true, isDownloadingPack: false))
        #expect(!BasemapPin.serves(after: URLError(.cancelled), hasPin: true, isDownloadingPack: false))
        #expect(!BasemapPin.serves(after: CancellationError(), hasPin: true, isDownloadingPack: false))
    }

    @Test func theAnswerAlwaysAsksAgain() {
        let headers = BasemapPin.revalidating([
            "Content-Type": "application/json",
            "cache-control": "public, max-age=3600",
            "Expires": "Tue, 20 Oct 2026 15:00:00 GMT",
            "Age": "12",
            "ETag": "\"abc\"",
        ])
        #expect(headers["Content-Type"] == "application/json")
        #expect(headers["ETag"] == "\"abc\"")
        #expect(headers["Expires"] == nil)
        #expect(headers["Age"] == nil)
        #expect(headers["cache-control"] == nil)
        // MapLibre reads max-age and must-revalidate; no-cache is for everyone else.
        #expect(headers["Cache-Control"] == "no-cache, max-age=0, must-revalidate")
    }
}
