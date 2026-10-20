import Foundation

/// A geographic bounding box in degrees, for map views and saved areas. Small boxes
/// only: the metre conversions treat the earth as flat, which is fine at 5 km.
public struct GeoBox: Codable, Sendable, Equatable, Hashable {
    public var south: Double
    public var west: Double
    public var north: Double
    public var east: Double

    public init(south: Double, west: Double, north: Double, east: Double) {
        self.south = south
        self.west = west
        self.north = north
        self.east = east
    }

    /// Metres per degree of latitude. Good enough at 5 km.
    private static let metersPerDegree = 111_320.0

    /// Metres of longitude at a latitude.
    private static func longitudeMeters(at latitude: Double) -> Double {
        metersPerDegree * cos(latitude * .pi / 180)
    }

    /// The square of `sideMeters` centred on the point.
    public static func around(_ center: Coordinate, sideMeters: Double) -> GeoBox {
        let halfHeight = sideMeters / 2 / metersPerDegree
        let halfWidth = sideMeters / 2 / longitudeMeters(at: center.latitude)
        return GeoBox(
            south: center.latitude - halfHeight,
            west: center.longitude - halfWidth,
            north: center.latitude + halfHeight,
            east: center.longitude + halfWidth
        )
    }

    public var center: Coordinate {
        Coordinate(latitude: (south + north) / 2, longitude: (west + east) / 2)
    }

    /// Along the centre latitude.
    public var widthMeters: Double {
        (east - west) * Self.longitudeMeters(at: center.latitude)
    }

    /// North–south.
    public var heightMeters: Double {
        (north - south) * Self.metersPerDegree
    }

    /// Inclusive on all four edges.
    public func contains(_ point: Coordinate) -> Bool {
        south <= point.latitude && point.latitude <= north
            && west <= point.longitude && point.longitude <= east
    }

    /// Inclusive overlap of the two rectangles.
    public func intersects(_ other: GeoBox) -> Bool {
        south <= other.north && other.south <= north
            && west <= other.east && other.west <= east
    }

    /// The four quarters, SW, SE, NW, NE. Split at the mid latitude and mid longitude,
    /// so together they cover the box exactly.
    public func quadrants() -> [GeoBox] {
        let midLatitude = (south + north) / 2
        let midLongitude = (west + east) / 2
        return [
            GeoBox(south: south, west: west, north: midLatitude, east: midLongitude),
            GeoBox(south: south, west: midLongitude, north: midLatitude, east: east),
            GeoBox(south: midLatitude, west: west, north: north, east: midLongitude),
            GeoBox(south: midLatitude, west: midLongitude, north: north, east: east),
        ]
    }

    /// All of Denmark, Bornholm included.
    public static let denmark = GeoBox(south: 54.5, west: 8.0, north: 57.8, east: 15.3)
}

/// Where the map starts: a point and a zoom.
public struct MapCamera: Equatable, Sendable {
    public var center: Coordinate
    public var zoom: Double

    public init(center: Coordinate, zoom: Double) {
        self.center = center
        self.zoom = zoom
    }

    /// All of Denmark.
    public static let denmark = MapCamera(center: Coordinate(latitude: 56.0, longitude: 10.8), zoom: 6)

    /// Exact GPS → zoom 15. A place's representative point → zoom 10. None → `.denmark`.
    public static func start(at point: Coordinate?, isExact: Bool) -> MapCamera {
        guard let point else { return denmark }
        return MapCamera(center: point, zoom: isExact ? 15 : 10)
    }
}

/// Tuning for the map tab.
public enum MapRules {
    /// Side of a saved area.
    public static let saveSideMeters: Double = 5_000
    /// Boundaries show from this zoom; below it the map says to zoom in.
    public static let boundaryMinZoom: Double = 13
    /// Matrikelnumre on the parcels from this zoom.
    public static let labelMinZoom: Double = 16
    /// Live fetches for the view stay under the agency's 10 km² viewer cap. By area, not by side:
    /// a portrait phone at zoom 13 shows about 2 × 4 km, taller than 3 km but under 9 km².
    public static let liveFetchMaxAreaSquareMeters: Double = 9_000_000
}
