import Foundation

/// The pinned TileJSON and the map's requests for it. OpenFreeMap names a new weekly tile path
/// in its TileJSON, and MapLibre keeps one copy per URL: once an online session stores the new
/// week, the saved packs' tiles are out of reach offline. So the app answers the TileJSON request
/// itself when the network is gone, with the bytes every pack is complete for, and makes MapLibre
/// ask again every time it is online.
public enum BasemapPin {
    /// MapLibre's request for OpenFreeMap's TileJSON (the style's source URL).
    public static func isTileJSON(_ url: URL) -> Bool {
        let pinned = OpenFreeMap.tileJSONURL
        return url.scheme == pinned.scheme && url.host == pinned.host && url.path == pinned.path
    }

    /// The map's TileJSON request failed for want of a network, and there is a pin to give it.
    /// Never while a pack downloads: the pack must get this week's TileJSON or fail.
    public static func serves(after error: Error, hasPin: Bool, isDownloadingPack: Bool) -> Bool {
        guard hasPin, !isDownloadingPack, let code = (error as? URLError)?.code else { return false }
        switch code {
        case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost,
             .cannotConnectToHost, .dnsLookupFailed, .dataNotAllowed, .internationalRoamingOff:
            return true
        default:
            return false
        }
    }

    /// The response's headers with every freshness hint gone, so MapLibre revalidates the TileJSON
    /// on each style load and, offline, asks the app again instead of using a stored newer week.
    /// MapLibre reads `max-age` and `must-revalidate`; `no-cache` is for any other cache.
    public static func revalidating(_ headers: [String: String]) -> [String: String] {
        var result = headers.filter { key, _ in
            !["cache-control", "expires", "age"].contains(key.lowercased())
        }
        result["Cache-Control"] = "no-cache, max-age=0, must-revalidate"
        return result
    }
}

/// What a stale-basemap refresh has to do.
public struct BasemapRefresh: Equatable, Sendable {
    /// Areas whose pack is for another week: each needs a new pack.
    public var stale: [OfflineArea]
    /// The pin is not the current week.
    public var movesPin: Bool

    public var isNeeded: Bool { !stale.isEmpty || movesPin }

    public static func plan(index: OfflineAreaIndex, currentTiles: String) -> BasemapRefresh {
        guard !index.areas.isEmpty else { return BasemapRefresh(stale: [], movesPin: false) }
        return BasemapRefresh(
            stale: index.staleBasemaps(currentTiles: currentTiles),
            movesPin: index.pinnedTiles != currentTiles
        )
    }
}

/// One basemap pack as the app reads its MapLibre context: the area's id and the week it was downloaded for.
public struct PackRecord: Equatable, Sendable {
    public var id: UUID
    /// nil for a pack whose context is the id alone (saved before the week was recorded).
    public var tiles: String?

    public init(id: UUID, tiles: String?) {
        self.id = id
        self.tiles = tiles
    }
}

/// The context bytes stored with a pack.
public enum PackContext {
    private struct Body: Codable {
        var id: UUID
        var tiles: String
    }

    public static func encode(id: UUID, tiles: String) -> Data {
        (try? JSONEncoder().encode(Body(id: id, tiles: tiles))) ?? Data(id.uuidString.utf8)
    }

    public static func decode(_ data: Data) -> PackRecord? {
        if let body = try? JSONDecoder().decode(Body.self, from: data) {
            return PackRecord(id: body.id, tiles: body.tiles)
        }
        return String(data: data, encoding: .utf8).flatMap { UUID(uuidString: $0) }.map { PackRecord(id: $0, tiles: nil) }
    }
}

public extension OfflineCleanup {
    /// Positions in `packs` to remove at launch. Orphans go. Per saved area, one pack of the
    /// index's week stays (an old context without a week counts as it) and the others go: they
    /// are half packs of a killed save or refresh, or the old week of a refresh killed after the
    /// index moved. No pack of the index's week: all stay, the next refresh mends it. An unknown
    /// index removes nothing.
    static func packsToRemove(_ packs: [PackRecord], index: OfflineAreaIndex, indexIsKnown: Bool) -> [Int] {
        guard indexIsKnown else { return [] }
        let templates = Dictionary(index.areas.map { ($0.id, $0.basemapTiles) }, uniquingKeysWith: { first, _ in first })
        var remove: [Int] = []
        var byArea: [UUID: [Int]] = [:]
        for (position, pack) in packs.enumerated() {
            if templates[pack.id] == nil {
                remove.append(position)
            } else {
                byArea[pack.id, default: []].append(position)
            }
        }
        for (id, positions) in byArea {
            let template = templates[id]
            let matching = positions.filter { packs[$0].tiles == template }
            let keep = matching.first ?? positions.first(where: { packs[$0].tiles == nil })
            guard let keep else { continue }
            remove += positions.filter { $0 != keep }
        }
        return remove.sorted()
    }
}
