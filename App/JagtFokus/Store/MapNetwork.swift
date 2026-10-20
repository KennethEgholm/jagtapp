import Foundation
import MapLibre
import os

/// The one gate for OpenFreeMap: the map, the offline packs and the TileJSON fetch share its slots.
enum OpenFreeMapTraffic {
    static let gate = RequestGate(limit: OpenFreeMap.maxParallelRequests)
}

/// All of MapLibre's traffic goes through here, so OpenFreeMap sees at most
/// `OpenFreeMap.maxParallelRequests` requests at once and the app's own User-Agent.
final class MapRequestProtocol: URLProtocol, @unchecked Sendable {
    private static let marker = "dk.jagtfokus.map-request"
    private static let gate = OpenFreeMapTraffic.gate
    private static let session = URLSession(configuration: .ephemeral)
    private var loading: Task<Void, Never>?

    /// Call before any `MLNMapView` exists.
    static func install() {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MapRequestProtocol.self]
        MLNNetworkConfiguration.sharedManager.sessionConfiguration = configuration
        #if DEBUG
        if offline { URLProtocol.registerClass(MapRequestProtocol.self) }
        #endif
    }

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
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
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
                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                self.client?.urlProtocol(self, didLoad: data)
                self.client?.urlProtocolDidFinishLoading(self)
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.client?.urlProtocol(self, didFailWithError: error)
            }
        }
    }

    override func stopLoading() {
        loading?.cancel()
        loading = nil
    }
}
