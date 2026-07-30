import AppKit
import Foundation

/// Remembers which application the user was in before the history panel stole
/// focus, so the paste can be delivered back to it.
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
    /// Our own process is ignored rather than recorded so that pressing the
    /// shortcut twice does not overwrite a good capture with ourselves.
    public func capture() {
        guard let app = workspace.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        capturedApp = app
    }

    /// Hands activation back to the captured app.
    ///
    /// Prefer `yieldActivation` so we do not fight macOS 14+'s focus rules;
    /// fall back to a plain `activate()` on older systems and when we were
    /// never the active app to begin with (non-activating panel path).
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
