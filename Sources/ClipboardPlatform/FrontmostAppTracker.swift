import AppKit
import ApplicationServices
import Foundation

/// Remembers which application (and focused field) the user was in before the
/// history panel stole focus, so paste can be delivered back there.
@MainActor
public final class FrontmostAppTracker {
    private let workspace: NSWorkspace

    public private(set) var capturedApp: NSRunningApplication?
    /// The AX focused element at capture time (text field / text view).
    public private(set) var capturedFocusedElement: AXUIElement?

    public init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    /// Records the current frontmost app and focused UI element unless it is us.
    ///
    /// Must run the instant the hotkey fires and before any window is shown:
    /// once the panel is up, we are the frontmost app and the original is lost.
    /// If we are already frontmost, previous capture is cleared so paste cannot
    /// target a stale background field.
    public func capture() {
        let ourPID = ProcessInfo.processInfo.processIdentifier

        guard let app = workspace.frontmostApplication,
              app.processIdentifier != ourPID
        else {
            clear()
            return
        }

        capturedApp = app
        capturedFocusedElement = nil
        guard AXIsProcessTrusted() else { return }

        // Prefer the focused element of the captured app — system-wide focus can
        // briefly point at the menu bar / status item after the hotkey.
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        if let element = copyFocusedElement(from: appElement),
           elementBelongs(to: app.processIdentifier, element: element) {
            capturedFocusedElement = element
            return
        }

        if let element = copyFocusedElement(from: AXUIElementCreateSystemWide()),
           elementBelongs(to: app.processIdentifier, element: element) {
            capturedFocusedElement = element
        }
    }

    /// Hands activation back to the captured app.
    @discardableResult
    public func reactivate() -> Bool {
        guard let app = capturedApp, !app.isTerminated else { return false }
        if NSApp.isActive {
            NSApp.yieldActivation(to: app)
        }
        return app.activate()
    }

    /// True when `element` still belongs to `expectedPID`.
    public func elementBelongs(to expectedPID: pid_t, element: AXUIElement) -> Bool {
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else { return false }
        return pid == expectedPID
    }

    public func clear() {
        capturedApp = nil
        capturedFocusedElement = nil
    }

    private func copyFocusedElement(from root: AXUIElement) -> AXUIElement? {
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            root,
            kAXFocusedUIElementAttribute as CFString,
            &focused
        ) == .success,
            let focused
        else { return nil }
        return unsafeBitCast(focused, to: AXUIElement.self)
    }
}
