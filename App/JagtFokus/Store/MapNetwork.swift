import Foundation
import MapLibre
import os

/// All of MapLibre's traffic goes through here, so OpenFreeMap sees at most
/// `OpenFreeMap.maxParallelRequests` requests at once and the app's own User-Agent.
final class MapRequestProtocol: URLProtocol, @unchecked Sendable {
    private static let marker = "dk.jagtfokus.map-request"
    private static let gate = RequestGate(limit: OpenFreeMap.maxParallelRequests)
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
        Self.log.notice("request \(number, privacy: .public) \(self.request.url?.absoluteString ?? "-", privacy: .public)")
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
