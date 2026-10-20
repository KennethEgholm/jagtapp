import Foundation
import Testing
@testable import JagtFokusCore

struct LiveBoundariesTests {
    let aarhus = Coordinate(latitude: 56.16, longitude: 10.20)

    func area(side: Double = 5_000, name: String = "Område 1") -> OfflineArea {
        OfflineArea(
            id: UUID(),
            name: name,
            box: GeoBox.around(aarhus, sideMeters: side),
            savedAt: Date(timeIntervalSince1970: 0),
            parcelCount: 10,
            bytes: 100,
            basemapTiles: "t"
        )
    }

    func parcels(_ ids: String...) -> ParcelSet {
        ParcelSet(parcels: ids.map { Parcel(id: $0, number: $0, district: "", polygons: []) })
    }

    // MARK: Box in box

    @Test func boxContainsABoxInsideItAndItself() {
        let outer = GeoBox.around(aarhus, sideMeters: 5_000)
        #expect(outer.contains(GeoBox.around(aarhus, sideMeters: 1_000)))
        #expect(outer.contains(outer))
        #expect(!outer.contains(GeoBox.around(aarhus, sideMeters: 6_000)))
        // Overlapping but not inside.
        let shifted = GeoBox.around(Coordinate(latitude: aarhus.latitude, longitude: aarhus.longitude + 0.03), sideMeters: 2_000)
        #expect(outer.intersects(shifted))
        #expect(!outer.contains(shifted))
    }

    // MARK: Plan

    @Test func belowTheMinimumZoomNothingIsFetched() {
        let view = GeoBox.around(aarhus, sideMeters: 1_000)
        #expect(LiveBoundaries.plan(for: view, zoom: MapRules.boundaryMinZoom - 0.1, areas: []) == .tooFarOut)
        // Zoom wins over a saved area: the layers do not draw below it either.
        #expect(LiveBoundaries.plan(for: view, zoom: 8, areas: [area()]) == .tooFarOut)
    }

    @Test func aViewInsideOneSavedAreaMakesNoFetch() {
        let saved = area()
        let view = GeoBox.around(aarhus, sideMeters: 1_000)
        #expect(LiveBoundaries.plan(for: view, zoom: 16, areas: [saved]) == .savedArea(saved))
    }

    @Test func aViewPartlyOutsideASavedAreaFetches() {
        let saved = area(side: 5_000)
        let edge = Coordinate(latitude: aarhus.latitude, longitude: saved.box.east)
        let view = GeoBox.around(edge, sideMeters: 1_000)
        #expect(LiveBoundaries.plan(for: view, zoom: 16, areas: [saved]) == .fetch)
    }

    /// A box `width` × `height` metres around the point.
    func box(width: Double, height: Double, at center: Coordinate) -> GeoBox {
        let halfHeight = height / 2 / 111_320
        let halfWidth = width / 2 / (111_320 * cos(center.latitude * .pi / 180))
        return GeoBox(
            south: center.latitude - halfHeight, west: center.longitude - halfWidth,
            north: center.latitude + halfHeight, east: center.longitude + halfWidth
        )
    }

    @Test func theLiveCapIsAnAreaOfNineSquareKilometres() {
        #expect(MapRules.liveFetchMaxAreaSquareMeters == 9_000_000)
        #expect(LiveBoundaries.plan(for: GeoBox.around(aarhus, sideMeters: 2_950), zoom: 14, areas: []) == .fetch)
        #expect(LiveBoundaries.plan(for: GeoBox.around(aarhus, sideMeters: 3_050), zoom: 14, areas: []) == .tooLarge)
    }

    @Test func aPortraitPhoneAtZoom13Fetches() {
        // iPhone 18 Pro, portrait, below the navigation bar: about 402 × 770 points.
        // At zoom 13 by Aarhus a point is about 5.3 m: 2.1 × 4.1 km, taller than 3 km but under 9 km².
        let portrait = box(width: 2_140, height: 4_100, at: aarhus)
        #expect(portrait.heightMeters > 3_000)
        #expect(LiveBoundaries.plan(for: portrait, zoom: 13, areas: []) == .fetch)
        // Tall and narrow counts by its area, not its longer side.
        #expect(LiveBoundaries.plan(for: box(width: 500, height: 8_000, at: aarhus), zoom: 13, areas: []) == .fetch)
        #expect(LiveBoundaries.plan(for: box(width: 2_500, height: 4_000, at: aarhus), zoom: 13, areas: []) == .tooLarge)
    }

    @Test func aBigViewInsideASavedAreaStillNeedsNoFetch() {
        let saved = area(side: 5_000)
        let view = GeoBox.around(aarhus, sideMeters: 4_000)
        #expect(LiveBoundaries.plan(for: view, zoom: 14, areas: [saved]) == .savedArea(saved))
    }

    // MARK: Errors

    @Test func lostNetworkIsOffline() {
        for code in [URLError.Code.notConnectedToInternet, .networkConnectionLost, .timedOut] {
            #expect(LiveBoundaries.failure(for: URLError(code)) == .offline)
        }
    }

    @Test func everythingElseIsFailed() {
        #expect(LiveBoundaries.failure(for: URLError(.badServerResponse)) == .failed)
        #expect(LiveBoundaries.failure(for: LiveBoundaries.BadStatus(code: 401)) == .failed)
        #expect(LiveBoundaries.failure(for: LiveBoundaries.BadStatus(code: 403)) == .failed)
        #expect(LiveBoundaries.failure(for: ParcelsRefused(problems: [.outsideDenmark(id: "1")])) == .failed)
        #expect(LiveBoundaries.failure(for: CocoaError(.fileReadCorruptFile)) == .failed)
    }

    @Test func onlyServerErrorsAreWorthARetry() {
        // The service now and then answers 500 and then 200 for the same box.
        for code in [500, 502, 503, 504] { #expect(LiveBoundaries.BadStatus(code: code).isServerError) }
        for code in [400, 401, 403, 404, 429] { #expect(!LiveBoundaries.BadStatus(code: code).isServerError) }
    }

    // MARK: Cache

    @Test func theCacheAnswersABoxInsideAFetchedOne() {
        var cache = ParcelCache()
        let big = GeoBox.around(aarhus, sideMeters: 2_000)
        cache.insert(box: big, parcels: parcels("a", "b"))
        #expect(cache.lookup(GeoBox.around(aarhus, sideMeters: 500))?.count == 2)
        #expect(cache.lookup(GeoBox.around(aarhus, sideMeters: 2_500)) == nil)
    }

    @Test func theCacheKeepsTheLastEightBoxes() {
        var cache = ParcelCache()
        func box(_ index: Int) -> GeoBox {
            GeoBox.around(Coordinate(latitude: 55 + Double(index) * 0.1, longitude: 10), sideMeters: 1_000)
        }
        for index in 0..<9 { cache.insert(box: box(index), parcels: parcels("p\(index)")) }
        #expect(ParcelCache.capacity == 8)
        #expect(cache.lookup(box(0)) == nil)
        for index in 1..<9 { #expect(cache.lookup(box(index)) != nil) }
    }

    @Test func insertingTheSameBoxAgainDoesNotUseTwoSlots() {
        var cache = ParcelCache()
        let box = GeoBox.around(aarhus, sideMeters: 1_000)
        for _ in 0..<20 { cache.insert(box: box, parcels: parcels("a")) }
        #expect(cache.count == 1)
    }
}
