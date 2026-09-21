import AppKit
import Foundation

/// Remembers which application the user was in before the history panel
/// stole focus, so paste can be delivered back there.
@MainActor
public final class FrontmostAppTracker {
    private let workspace: NSWorkspace

    public private(set) var capturedApp: NSRunningApplication?

    public init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    /// Records the current frontmost app unless it is us.
    ///
    /// Must run the instant the hotkey fires and before any window is shown:
    /// once the panel is up, we are the frontmost app and the original is lost.
    /// If we are already frontmost, previous capture is cleared so paste cannot
    /// target a stale app.
    public func capture() {
        let ourPID = ProcessInfo.processInfo.processIdentifier

        guard let app = workspace.frontmostApplication,
              app.processIdentifier != ourPID
        else {
            clear()
            return
        }

        capturedApp = app
    }

    /// Hands activation back to the captured app.
    ///
    /// This only *requests* the switch; `NSRunningApplication.activate()`
    /// returns before the target is frontmost. Callers that need the target to
    /// have focus (a synthesized ⌘V) must wait for that separately.
    @discardableResult
    public func reactivate() -> Bool {
        guard let app = capturedApp, !app.isTerminated else { return false }
        if NSApp.isActive {
            NSApp.yieldActivation(to: app)
        }
        return app.activate()
    }

    public func clear() {
        capturedApp = nil
    }
}
