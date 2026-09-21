import Foundation

/// Waits until the app we handed activation back to is actually frontmost.
///
/// `NSRunningApplication.activate()` only *requests* activation; the switch
/// happens later, once the window server and the target have processed it. A
/// ⌘V posted before that lands in an app with no key window and is dropped, so
/// the keystroke must wait for the switch to be observable. Polling is bounded
/// so an app that never comes forward cannot leave a paste pending forever.
///
/// Scheduling is injected so the sequencing can be tested without real delays.
@MainActor
public final class ActivationWaiter {
    /// Runs `work` on the main actor after `delay` seconds.
    public typealias Scheduler = @MainActor (_ delay: TimeInterval, _ work: @escaping @MainActor () -> Void) -> Void

    public struct Timing: Sendable {
        /// How often the frontmost app is re-checked.
        public var pollInterval: TimeInterval
        /// How long to keep waiting before giving up on the switch.
        public var timeout: TimeInterval
        /// Activation requests are re-issued at this cadence while waiting;
        /// macOS 14+ can drop a request that raced the yield.
        public var retryInterval: TimeInterval
        /// Breathing room after the switch is visible, so the target has
        /// restored its key window and first responder before ⌘V arrives.
        public var settleDelay: TimeInterval

        public init(
            pollInterval: TimeInterval = 0.015,
            timeout: TimeInterval = 1.5,
            retryInterval: TimeInterval = 0.25,
            settleDelay: TimeInterval = 0.05
        ) {
            self.pollInterval = pollInterval
            self.timeout = timeout
            self.retryInterval = retryInterval
            self.settleDelay = settleDelay
        }
    }

    public let timing: Timing
    private let schedule: Scheduler
    /// Re-checks scheduled after the immediate first one. Counted in polls
    /// rather than accumulated seconds so the cut-off does not drift with
    /// floating-point rounding.
    private let maxPolls: Int
    private let pollsPerRetry: Int

    public init(timing: Timing = Timing(), schedule: Scheduler? = nil) {
        self.timing = timing
        self.maxPolls = max(1, Int((timing.timeout / timing.pollInterval).rounded()))
        self.pollsPerRetry = max(1, Int((timing.retryInterval / timing.pollInterval).rounded()))
        self.schedule = schedule ?? Self.mainQueueScheduler()
    }

    private static func mainQueueScheduler() -> Scheduler {
        { delay, work in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                MainActor.assumeIsolated { work() }
            }
        }
    }

    /// Calls `completion` exactly once: with `true` once `isActive` reports the
    /// switch (after `settleDelay`), or with `false` when `timeout` elapses.
    /// `retryActivation` is invoked every `retryInterval` while waiting.
    public func wait(
        isActive: @escaping @MainActor () -> Bool,
        retryActivation: @escaping @MainActor () -> Void,
        completion: @escaping @MainActor (Bool) -> Void
    ) {
        poll(attempt: 0, isActive: isActive, retryActivation: retryActivation, completion: completion)
    }

    private func poll(
        attempt: Int,
        isActive: @escaping @MainActor () -> Bool,
        retryActivation: @escaping @MainActor () -> Void,
        completion: @escaping @MainActor (Bool) -> Void
    ) {
        if isActive() {
            schedule(timing.settleDelay) { completion(true) }
            return
        }
        guard attempt < maxPolls else {
            completion(false)
            return
        }
        if attempt > 0, attempt % pollsPerRetry == 0 {
            retryActivation()
        }

        schedule(timing.pollInterval) { [weak self] in
            guard let self else {
                completion(false)
                return
            }
            self.poll(
                attempt: attempt + 1,
                isActive: isActive,
                retryActivation: retryActivation,
                completion: completion
            )
        }
    }
}
