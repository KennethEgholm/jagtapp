import Foundation

/// Lets at most `limit` pieces of work run at once; the rest wait their turn in order.
/// OpenFreeMap asks for no more than four parallel requests.
public actor RequestGate {
    private let limit: Int
    private var running = 0
    private var waiting: [CheckedContinuation<Void, Never>] = []

    public init(limit: Int) {
        self.limit = max(1, limit)
    }

    public func run<T: Sendable>(_ work: @Sendable () async throws -> T) async throws -> T {
        await acquire()
        do {
            let result = try await work()
            release()
            return result
        } catch {
            release()
            throw error
        }
    }

    private func acquire() async {
        if running < limit {
            running += 1
            return
        }
        // The slot is handed over by release(), so `running` stays unchanged.
        await withCheckedContinuation { waiting.append($0) }
    }

    private func release() {
        if waiting.isEmpty {
            running -= 1
        } else {
            waiting.removeFirst().resume()
        }
    }
}
