import Foundation
import MapLibre
import os

/// The one gate for OpenFreeMap: the map, the offline packs and the TileJSON fetch share its slots.
enum OpenFreeMapTraffic {
    static let gate = RequestGate(limit: OpenFreeMap.maxParallelRequests)
}

/// The app's own requests for the map: Datafordeler pages and OpenFreeMap's TileJSON. A
/// Datafordeler URL carries the key, so nothing is cached and nothing is stored: ephemeral,
/// no URL cache, no cookies. Live parcels stay in memory only.
enum MapSession {
    static let shared: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpAdditionalHeaders = ["User-Agent": UserAgent.app]
        #if DEBUG
        // `-offline YES` fails these requests too, as with no network.
        if MapRequestProtocol.offline { configuration.protocolClasses = [MapRequestProtocol.self] }
        #endif
        return URLSession(configuration: configuration)
    }()
}

/// The pinned TileJSON for `MapRequestProtocol`, which runs on URL loading threads. Read from the
/// Kort index on disk when it is needed (once per style load), so it is there from the first
/// request after launch, before `MapStore` has read anything.
enum PinnedBasemap {
    private static let downloads = OSAllocatedUnfairLock(initialState: 0)

    static func beginDownload() { downloads.withLock { $0 += 1 } }
    static func endDownload() { downloads.withLock { $0 -= 1 } }
    static var isDownloadingPack: Bool { downloads.withLock { $0 > 0 } }

    /// The pin, when there is a saved area for it to serve.
    static func tileJSON() -> Data? {
        guard case .known(let index) = OfflineAreaStore(folder: OfflineDisk.defaultFolder).indexState(),
              !index.areas.isEmpty else { return nil }
        return index.pinnedTileJSON
    }
}

/// All of MapLibre's traffic goes through here, so OpenFreeMap sees at most
/// `OpenFreeMap.maxParallelRequests` requests at once and the app's own User-Agent.
final class MapRequestProtocol: URLProtocol, @unchecked Sendable {
    private static let marker = "dk.jagtfokus.map-request"
    private static let gate = OpenFreeMapTraffic.gate
    private static let session = URLSession(configuration: .ephemeral)
    private var loading: Task<Void, Never>?

    /// Routes MapLibre's traffic through this protocol. Must run before MapLibre makes its file
    /// source, which the first `MLNMapView` or `MLNOfflineStorage.shared` does. Every MapLibre
    /// entry point in the app calls it first (`ParcelMapView`, `BasemapPacks`), so the order of
    /// the app's initialisers does not matter. Safe to call again: it runs once.
    static func install() {
        _ = installed
    }

    private static let installed: Void = {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MapRequestProtocol.self]
        MLNNetworkConfiguration.sharedManager.sessionConfiguration = configuration
        #if DEBUG
        if offline { URLProtocol.registerClass(MapRequestProtocol.self) }
        #endif
    }()

    #if DEBUG
    /// `-offline YES`: every request fails, as with no network.
    static let offline = UserDefaults.standard.bool(forKey: "offline")
    private static let log = Logger(subsystem: "dk.jagtfokus.app", category: "map")
    private static let count = OSAllocatedUnfairLock(initialState: 0)
    /// Requests running at this moment, and the most there have been at once. The gate must keep it at 4 or less.
    private static let inFlight = OSAllocatedUnfairLock(initialState: (current: 0, peak: 0))

    private static func began() {
        let peak = inFlight.withLock { state -> Int? in
            state.current += 1
            guard state.current > state.peak else { return nil }
            state.peak = state.current
            return state.peak
        }
        if let peak { log.notice("in flight, new peak: \(peak, privacy: .public)") }
    }

    private static func ended() {
        inFlight.withLock { $0.current -= 1 }
    }

    /// The URL for the log, without the Datafordeler key. The cadastre fetch passes through here too under `-offline YES`.
    private static func redacted(_ url: URL?) -> String {
        guard let url, var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return "-" }
        components.queryItems = components.queryItems?.map { item in
            item.name.lowercased() == "apikey" ? URLQueryItem(name: item.name, value: "…") : item
        }
        return components.string ?? "-"
    }
    #endif

    override class func canInit(with request: URLRequest) -> Bool {
        guard URLProtocol.property(forKey: marker, in: request) == nil else { return false }
        return request.url?.scheme == "https" || request.url?.scheme == "http"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        #if DEBUG
        let number = Self.count.withLock { count -> Int in
            count += 1
            return count
        }
        Self.log.notice("request \(number, privacy: .public) \(Self.redacted(self.request.url), privacy: .public)")
        if Self.offline {
            let error = URLError(.notConnectedToInternet)
            if !servePin(after: error) { client?.urlProtocol(self, didFailWithError: error) }
            return
        }
        #endif
        guard let marked = (request as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        URLProtocol.setProperty(true, forKey: Self.marker, in: marked)
        marked.setValue(UserAgent.app, forHTTPHeaderField: "User-Agent")
        let outgoing = marked as URLRequest
        loading = Task { [weak self] in
            do {
                let (data, response) = try await Self.gate.run {
                    // A cancelled request waited for its slot anyway; give it back at once.
                    try Task.checkCancellation()
                    #if DEBUG
                    Self.began()
                    defer { Self.ended() }
                    #endif
                    return try await Self.session.data(for: outgoing)
                }
                guard !Task.isCancelled, let self else { return }
                self.client?.urlProtocol(self, didReceive: self.revalidated(response), cacheStoragePolicy: .notAllowed)
                self.client?.urlProtocol(self, didLoad: data)
                self.client?.urlProtocolDidFinishLoading(self)
            } catch {
                guard !Task.isCancelled, let self else { return }
                if !self.servePin(after: error) { self.client?.urlProtocol(self, didFailWithError: error) }
            }
        }
    }

    private var isTileJSON: Bool {
        request.url.map(BasemapPin.isTileJSON) ?? false
    }

    /// The TileJSON answer while there is a pin: no freshness, so MapLibre asks again on each
    /// style load, and offline it asks here instead of using a stored newer week. Without a saved
    /// area the server's headers stand, and MapLibre's own cache works offline as before.
    private func revalidated(_ response: URLResponse) -> URLResponse {
        guard isTileJSON, let http = response as? HTTPURLResponse, let url = http.url,
              PinnedBasemap.tileJSON() != nil else { return response }
        var headers: [String: String] = [:]
        for (key, value) in http.allHeaderFields {
            if let key = key as? String, let value = value as? String { headers[key] = value }
        }
        return HTTPURLResponse(url: url, statusCode: http.statusCode, httpVersion: "HTTP/1.1",
                               headerFields: BasemapPin.revalidating(headers)) ?? response
    }

    /// No network and the map asks for the TileJSON: answer with the pin, the week every saved
    /// pack is complete for. True when it answered.
    private func servePin(after error: Error) -> Bool {
        guard isTileJSON, let url = request.url else { return false }
        let pin = PinnedBasemap.tileJSON()
        guard BasemapPin.serves(after: error, hasPin: pin != nil, isDownloadingPack: PinnedBasemap.isDownloadingPack),
              let pin,
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1",
                                             headerFields: BasemapPin.revalidating(["Content-Type": "application/json"]))
        else { return false }
        #if DEBUG
        Self.log.notice("tilejson: no network, served the pin \((try? OpenFreeMap.tilesTemplate(fromTileJSON: pin)) ?? "-", privacy: .public)")
        #endif
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: pin)
        client?.urlProtocolDidFinishLoading(self)
        return true
    }

    override func stopLoading() {
        loading?.cancel()
        loading = nil
    }
}
