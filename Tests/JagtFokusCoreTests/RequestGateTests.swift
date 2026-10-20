import Foundation
import Testing
@testable import JagtFokusCore

private actor PeakCounter {
    private(set) var running = 0
    private(set) var peak = 0
    private(set) var finished = 0

    func start() {
        running += 1
        peak = max(peak, running)
    }

    func finish() {
        running -= 1
        finished += 1
    }
}

struct RequestGateTests {
    @Test func gateNeverRunsMoreThanTheLimit() async throws {
        let gate = RequestGate(limit: 4)
        let counter = PeakCounter()

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    try await gate.run {
                        await counter.start()
                        try await Task.sleep(for: .milliseconds(20))
                        await counter.finish()
                    }
                }
            }
            try await group.waitForAll()
        }

        #expect(await counter.peak <= 4)
        #expect(await counter.peak > 1)
        #expect(await counter.finished == 20)
    }

    @Test func gateReleasesTheSlotWhenWorkThrows() async throws {
        struct Boom: Error {}
        let gate = RequestGate(limit: 1)
        await #expect(throws: Boom.self) {
            try await gate.run { throw Boom() }
        }
        let value = try await gate.run { 42 }
        #expect(value == 42)
    }
}
