import Foundation
import Testing

@testable import ClipboardPlatform

/// Records scheduled work so a test can step through it without real delays.
@MainActor
private final class ManualScheduler {
    private(set) var queue: [(delay: TimeInterval, work: @MainActor () -> Void)] = []

    var schedule: ActivationWaiter.Scheduler {
        { [self] delay, work in self.queue.append((delay, work)) }
    }

    /// Runs the next scheduled closure and returns the delay it asked for.
    @discardableResult
    func step() -> TimeInterval? {
        guard !queue.isEmpty else { return nil }
        let next = queue.removeFirst()
        next.work()
        return next.delay
    }

    /// Runs everything, including work scheduled while running. Bounded so a
    /// waiter that never stops cannot hang the test.
    func drain(limit: Int = 10_000) {
        var steps = 0
        while step() != nil {
            steps += 1
            precondition(steps < limit, "scheduler did not settle")
        }
    }
}

@Suite("ActivationWaiter")
@MainActor
struct ActivationWaiterTests {
    private let timing = ActivationWaiter.Timing(
        pollInterval: 0.01, timeout: 0.1, retryInterval: 0.03, settleDelay: 0.05
    )

    @Test("A target that is already frontmost completes after only the settle delay")
    func alreadyActive() {
        let scheduler = ManualScheduler()
        let waiter = ActivationWaiter(timing: timing, schedule: scheduler.schedule)
        var results: [Bool] = []
        var retries = 0

        waiter.wait(isActive: { true }, retryActivation: { retries += 1 }, completion: { results.append($0) })

        #expect(results.isEmpty)
        #expect(scheduler.step() == timing.settleDelay)
        #expect(results == [true])
        #expect(retries == 0)
        #expect(scheduler.step() == nil)
    }

    @Test("Polling continues until the switch is visible, then completes exactly once")
    func becomesActiveLater() {
        let scheduler = ManualScheduler()
        let waiter = ActivationWaiter(timing: timing, schedule: scheduler.schedule)
        var results: [Bool] = []
        var polls = 0

        waiter.wait(
            isActive: {
                polls += 1
                return polls >= 4
            },
            retryActivation: {},
            completion: { results.append($0) }
        )
        scheduler.drain()

        #expect(polls == 4)
        #expect(results == [true])
    }

    @Test("Activation is re-requested while waiting, at the retry cadence")
    func retriesActivation() {
        let scheduler = ManualScheduler()
        let waiter = ActivationWaiter(timing: timing, schedule: scheduler.schedule)
        var retries = 0
        var polls = 0

        waiter.wait(
            isActive: {
                polls += 1
                return polls > 7
            },
            retryActivation: { retries += 1 },
            completion: { _ in }
        )
        scheduler.drain()

        // The switch is seen on the 8th check (attempt 7). With a 30 ms cadence
        // over 10 ms polls, activation is re-requested at attempts 3 and 6.
        #expect(retries == 2)
    }

    @Test("Giving up reports false once and never fires a late success")
    func timesOut() {
        let scheduler = ManualScheduler()
        let waiter = ActivationWaiter(timing: timing, schedule: scheduler.schedule)
        var results: [Bool] = []
        var polls = 0

        waiter.wait(
            isActive: {
                polls += 1
                return false
            },
            retryActivation: {},
            completion: { results.append($0) }
        )
        scheduler.drain()

        #expect(results == [false])
        // 0.1 s timeout at 0.01 s per poll: the first check plus ten scheduled re-checks.
        #expect(polls == 11)
    }

    @Test("Completion is delivered on the settle delay, not on the polling interval")
    func settleDelayIsUsedAfterActivation() {
        let scheduler = ManualScheduler()
        let waiter = ActivationWaiter(timing: timing, schedule: scheduler.schedule)
        var polls = 0

        waiter.wait(
            isActive: {
                polls += 1
                return polls == 2
            },
            retryActivation: {},
            completion: { _ in }
        )

        #expect(scheduler.step() == timing.pollInterval)
        #expect(scheduler.step() == timing.settleDelay)
        #expect(scheduler.step() == nil)
    }
}
