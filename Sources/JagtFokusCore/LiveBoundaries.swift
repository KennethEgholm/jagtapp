import Foundation

public extension GeoBox {
    /// The other box lies wholly inside this one. Edges count as inside.
    func contains(_ other: GeoBox) -> Bool {
        south <= other.south && other.north <= north
            && west <= other.west && other.east <= east
    }
}

/// What the map does about boundaries for the view it shows. Pure decisions; the
/// app does the fetching.
public enum LiveBoundaries {
    public enum Plan: Equatable, Sendable {
        /// Below `MapRules.boundaryMinZoom`: the map says to zoom in.
        case tooFarOut
        /// The view lies wholly inside one saved area. Its parcels are on disk.
        case savedArea(OfflineArea)
        /// Zoomed in enough, but the view is wider or taller than a live fetch may be.
        case tooLarge
        case fetch
    }

    public static func plan(for box: GeoBox, zoom: Double, areas: [OfflineArea]) -> Plan {
        guard zoom >= MapRules.boundaryMinZoom else { return .tooFarOut }
        if let area = areas.first(where: { $0.box.contains(box) }) {
            return .savedArea(area)
        }
        guard max(box.widthMeters, box.heightMeters) <= MapRules.liveFetchMaxSideMeters else {
            return .tooLarge
        }
        return .fetch
    }

    /// The service answered, but not with a page.
    public struct BadStatus: Error, Equatable, Sendable {
        public var code: Int

        public init(code: Int) {
            self.code = code
        }

        /// 5xx: the service had a bad moment. One more try is reasonable; 401 and 403 are not.
        public var isServerError: Bool { (500..<600).contains(code) }
    }

    public enum Failure: Equatable, Sendable {
        /// No network right now.
        case offline
        /// Anything else, an expired key (401, 403) included.
        case failed
    }

    public static func failure(for error: Error) -> Failure {
        guard let urlError = error as? URLError else { return .failed }
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .timedOut:
            return .offline
        default:
            return .failed
        }
    }
}

/// The last few fetched views, so a small pan or a zoom back in asks the service for nothing.
public struct ParcelCache: Sendable {
    public static let capacity = 8

    private struct Entry: Sendable {
        var box: GeoBox
        var parcels: ParcelSet
    }

    private var entries: [Entry] = []

    public init() {}

    public var count: Int { entries.count }

    /// The newest fetch that covers the box.
    public func lookup(_ box: GeoBox) -> ParcelSet? {
        entries.first { $0.box.contains(box) }?.parcels
    }

    public mutating func insert(box: GeoBox, parcels: ParcelSet) {
        entries.removeAll { $0.box == box }
        entries.insert(Entry(box: box, parcels: parcels), at: 0)
        if entries.count > Self.capacity {
            entries.removeLast(entries.count - Self.capacity)
        }
    }
}
