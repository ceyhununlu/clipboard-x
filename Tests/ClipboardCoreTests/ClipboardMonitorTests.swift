import Foundation
import Testing
@testable import ClipboardCore

@Suite("ClipboardMonitor") @MainActor
struct ClipboardMonitorTests {

    @Test("no callback when changeCount is unchanged after multiple polls")
    func noCallbackWhenUnchanged() {
        let pasteboard = FakePasteboard()
        pasteboard.content = textContent("hello")
        var callCount = 0
        let monitor = ClipboardMonitor(source: pasteboard) { _ in callCount += 1 }
        monitor.poll()
        monitor.poll()
        monitor.poll()
        #expect(callCount == 0)
    }

    @Test("one callback per change with the content the source returned")
    func oneCallbackPerChange() {
        let pasteboard = FakePasteboard()
        var received: [ClipboardContent] = []
        let monitor = ClipboardMonitor(source: pasteboard) { received.append($0) }

        pasteboard.changeCount = 1
        pasteboard.content = textContent("first")
        monitor.poll()

        pasteboard.changeCount = 2
        pasteboard.content = textContent("second")
        monitor.poll()

        #expect(received.count == 2)
        #expect(received[0] == .text("first"))
        #expect(received[1] == .text("second"))
    }

    @Test("a change whose readContent returns nil produces no callback but consumes the change")
    func nilContentProducesNoCallback() {
        let pasteboard = FakePasteboard()
        var callCount = 0
        let monitor = ClipboardMonitor(source: pasteboard) { _ in callCount += 1 }

        pasteboard.changeCount = 1
        pasteboard.content = nil
        monitor.poll()
        #expect(callCount == 0)

        monitor.poll()
        #expect(callCount == 0)
    }

    @Test("acknowledgeSelfWrite suppresses the pending change exactly once")
    func acknowledgeSelfWriteSuppressesOnce() {
        let pasteboard = FakePasteboard()
        var callCount = 0
        let monitor = ClipboardMonitor(source: pasteboard) { _ in callCount += 1 }

        pasteboard.changeCount = 1
        pasteboard.content = textContent("app-wrote-this")
        monitor.acknowledgeSelfWrite()
        monitor.poll()
        #expect(callCount == 0)

        pasteboard.changeCount = 2
        pasteboard.content = textContent("external-copy")
        monitor.poll()
        #expect(callCount == 1)
    }

    @Test("a monitor constructed over a non-zero changeCount does not fire on first poll")
    func noPhantomCaptureAtLaunch() {
        let pasteboard = FakePasteboard()
        pasteboard.changeCount = 5
        pasteboard.content = textContent("pre-existing")
        var callCount = 0
        let monitor = ClipboardMonitor(source: pasteboard) { _ in callCount += 1 }
        monitor.poll()
        #expect(callCount == 0)
    }

    @Test("start sets isRunning to true and stop sets it back to false")
    func startStopTogglesIsRunning() {
        let pasteboard = FakePasteboard()
        let monitor = ClipboardMonitor(source: pasteboard) { _ in }
        #expect(!monitor.isRunning)
        monitor.start()
        #expect(monitor.isRunning)
        monitor.stop()
        #expect(!monitor.isRunning)
    }

    @Test("start is idempotent: calling it twice does not double-register")
    func startIsIdempotent() {
        let pasteboard = FakePasteboard()
        let monitor = ClipboardMonitor(source: pasteboard) { _ in }
        monitor.start()
        monitor.start()
        #expect(monitor.isRunning)
        monitor.stop()
        #expect(!monitor.isRunning)
    }

    @Test("stop is idempotent: calling it on a stopped monitor is safe")
    func stopIsIdempotent() {
        let pasteboard = FakePasteboard()
        let monitor = ClipboardMonitor(source: pasteboard) { _ in }
        monitor.stop()
        monitor.stop()
        #expect(!monitor.isRunning)
    }
}
