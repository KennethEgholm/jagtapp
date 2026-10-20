import Foundation

/// The free basemap behind the map tab. No key. OpenFreeMap asks for attribution and
/// a modest request rate.
public enum OpenFreeMap {
    public static let styleURL = URL(string: "https://tiles.openfreemap.org/styles/liberty")!
    public static let tileJSONURL = URL(string: "https://tiles.openfreemap.org/planet")!
    public static let attribution = "OpenFreeMap © OpenMapTiles Data from OpenStreetMap"
    public static let maxParallelRequests = 4
    /// Zoom levels in a saved area's basemap pack.
    public static let packZoom: ClosedRange<Double> = 8...14

    public struct TileJSONError: Error, Equatable, Sendable {}

    /// The weekly tile URL template, for example
    /// `https://tiles.openfreemap.org/planet/20261015_001001_pt/{z}/{x}/{y}.pbf`.
    /// A saved area keeps it, so a newer week shows up as a stale pack.
    public static func tilesTemplate(fromTileJSON data: Data) throws -> String {
        struct TileJSON: Decodable {
            var tiles: [String]?
        }
        let decoded = try JSONDecoder().decode(TileJSON.self, from: data)
        guard let first = decoded.tiles?.first, !first.isEmpty else {
            throw TileJSONError()
        }
        return first
    }
}
