import Foundation

/// Decisions around saving an area for use without a network. The app does the I/O.
public enum OfflineCleanup {
    /// Basemap packs whose id has no row in the index: half packs from a killed save,
    /// or packs of a deleted area. An index that could not be read looks empty, so then
    /// nothing is an orphan: removing the packs would remove the user's areas.
    public static func orphanPackIDs(packIDs: [UUID], index: OfflineAreaIndex, indexIsKnown: Bool) -> Set<UUID> {
        guard indexIsKnown else { return [] }
        let known = Set(index.areas.map(\.id))
        return Set(packIDs).subtracting(known)
    }
}

/// What one saved area's basemap pack may cost. 5 × 5 km at zoom 8 to 14 is far below this;
/// the limit is a guard, not an expectation.
public enum PackLimits {
    public static let maxTiles = 3_000
    public static let maxBytes = 50_000_000

    public static func exceeded(tiles: Int, bytes: Int) -> Bool {
        tiles > maxTiles || bytes > maxBytes
    }
}

/// One bar for the whole save: the parcels first, then the basemap pack.
public enum SaveProgress {
    /// The parcels' share of the bar.
    public static let parcelShare = 0.2

    public static func overall(parcelsDone: Int, of parcelsTotal: Int, pack: Double) -> Double {
        guard parcelsTotal > 0 else { return 0 }
        let parcels = min(1, max(0, Double(parcelsDone) / Double(parcelsTotal))) * parcelShare
        guard parcelsDone >= parcelsTotal else { return parcels }
        return min(1, parcels + min(1, max(0, pack)) * (1 - parcelShare))
    }
}

/// Tells a download that has stopped from one that waited. Only time the app was active counts:
/// in the background the app is suspended, and a download that waited is not a download that stalled.
public struct StallWatch: Sendable {
    public let limitSeconds: Int
    private var quietSeconds = 0

    public init(limitSeconds: Int) {
        self.limitSeconds = limitSeconds
    }

    /// True when the active quiet time has reached the limit.
    public mutating func tick(seconds: Int, isActive: Bool) -> Bool {
        guard isActive else { return false }
        quietSeconds += seconds
        return quietSeconds >= limitSeconds
    }

    /// The download moved.
    public mutating func progress() {
        quietSeconds = 0
    }

    /// The app came to the foreground: count from zero.
    public mutating func becameActive() {
        quietSeconds = 0
    }
}
