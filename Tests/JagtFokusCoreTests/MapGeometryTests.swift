import Foundation
import Testing
@testable import JagtFokusCore

struct MapGeometryTests {
    /// Aarhus, where the plan's probe box sits.
    let aarhus = Coordinate(latitude: 56.16, longitude: 10.20)
    /// Metres per degree of latitude, the flat-earth constant the implementation uses.
    let metersPerDegree = 111_320.0

    /// Metres of longitude at a latitude.
    func longitudeMeters(at latitude: Double) -> Double {
        metersPerDegree * cos(latitude * .pi / 180)
    }

    /// A point `meters` east of the point, along its latitude.
    func east(of point: Coordinate, meters: Double) -> Coordinate {
        Coordinate(
            latitude: point.latitude,
            longitude: point.longitude + meters / longitudeMeters(at: point.latitude)
        )
    }

    @Test func aroundIsFiveKilometresEachWay() {
        let box = GeoBox.around(aarhus, sideMeters: 5_000)
        #expect(abs(box.widthMeters - 5_000) < 5)
        #expect(abs(box.heightMeters - 5_000) < 5)
        #expect(abs(box.center.latitude - aarhus.latitude) < 1e-9)
        #expect(abs(box.center.longitude - aarhus.longitude) < 1e-9)
    }

    @Test func containsAndIntersects() {
        let box = GeoBox.around(aarhus, sideMeters: 5_000)
        #expect(box.contains(aarhus))
        // 3 km east is 500 m past the east edge of a 5 km box.
        #expect(!box.contains(east(of: aarhus, meters: 3_000)))

        // Two 5 km boxes with centres 4 km apart overlap; 6 km apart they do not.
        func shifted(eastMeters: Double) -> GeoBox {
            GeoBox.around(east(of: aarhus, meters: eastMeters), sideMeters: 5_000)
        }
        #expect(box.intersects(shifted(eastMeters: 4_000)))
        #expect(!box.intersects(shifted(eastMeters: 6_000)))
    }

    @Test func quadrantsCoverTheBox() {
        let box = GeoBox.around(aarhus, sideMeters: 5_000)
        let quads = box.quadrants()
        #expect(quads.count == 4)
        for quad in quads {
            #expect(abs(quad.widthMeters - 2_500) < 5)
            #expect(abs(quad.heightMeters - 2_500) < 5)
        }
        // SW, SE, NW, NE in that order.
        #expect(quads[0].center.latitude < box.center.latitude)
        #expect(quads[0].center.longitude < box.center.longitude)
        #expect(quads[3].center.latitude > box.center.latitude)
        #expect(quads[3].center.longitude > box.center.longitude)
        // Together the four are the original box.
        #expect(abs(quads.map(\.south).min()! - box.south) < 1e-9)
        #expect(abs(quads.map(\.west).min()! - box.west) < 1e-9)
        #expect(abs(quads.map(\.north).max()! - box.north) < 1e-9)
        #expect(abs(quads.map(\.east).max()! - box.east) < 1e-9)
    }

    @Test func cameraStart() {
        #expect(MapCamera.start(at: aarhus, isExact: true) == MapCamera(center: aarhus, zoom: 15))
        #expect(MapCamera.start(at: aarhus, isExact: false) == MapCamera(center: aarhus, zoom: 10))
        #expect(MapCamera.start(at: nil, isExact: true) == .denmark)
        #expect(MapCamera.start(at: nil, isExact: false) == .denmark)
        #expect(MapCamera.denmark == MapCamera(center: Coordinate(latitude: 56.0, longitude: 10.8), zoom: 6))
    }

    @Test func denmarkBox() {
        // Bornholm and Skagen are inside; Copenhagen with the axes swapped is not.
        #expect(GeoBox.denmark.contains(Coordinate(latitude: 55.1, longitude: 14.9)))
        #expect(GeoBox.denmark.contains(Coordinate(latitude: 57.72, longitude: 10.58)))
        #expect(!GeoBox.denmark.contains(Coordinate(latitude: 12.6, longitude: 55.7)))
    }
}
