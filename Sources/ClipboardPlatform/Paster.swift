import AppKit
import ApplicationServices
import ClipboardCore
import CoreGraphics
import Foundation

/// Delivers a history item to the app the user was working in.
///
/// The pasteboard write always happens; synthesizing `⌘V` is a bonus that needs
/// Accessibility permission, so a missing grant degrades to "it is on your
/// clipboard, press ⌘V yourself" rather than failing.
@MainActor
public final class Paster {
    /// The reactivated app needs a beat to become key before it will accept a
    /// synthetic keystroke. Too short and ⌘V lands in the void; too long and
    /// the paste feels laggy. Empirically ~200 ms is reliable on macOS 15.
    private static let pasteDelay: TimeInterval = 0.20

    private let pasteboard: SystemPasteboard
    private let permission: AccessibilityPermission
    private let tracker: FrontmostAppTracker

    /// Called immediately after the app writes to the pasteboard, so the monitor
    /// can discount its own write instead of re-recording the item.
    public var onPasteboardWrite: (() -> Void)?

    public init(
        pasteboard: SystemPasteboard,
        permission: AccessibilityPermission,
        tracker: FrontmostAppTracker
    ) {
        self.pasteboard = pasteboard
        self.permission = permission
        self.tracker = tracker
    }

    /// Puts `content` on the pasteboard and optionally pastes it for the user.
    ///
    /// `completion` reports whether `⌘V` was actually synthesized, which is what
    /// the caller needs to decide between "pasted" and "copied" feedback.
    public func deliver(
        _ content: ClipboardContent,
        plainTextOnly: Bool,
        autoPaste: Bool,
        completion: (@MainActor (Bool) -> Void)?
    ) {
        if !(plainTextOnly && pasteboard.writePlainText(content)) {
            pasteboard.write(content)
        }
        onPasteboardWrite?()

        // Always return the user to the app they were in, even when we are only
        // copying. Choosing from the history is a momentary interruption.
        let targetPID = tracker.capturedApp?.processIdentifier
        tracker.reactivate()

        permission.refresh()
        guard autoPaste, permission.isTrusted else {
            completion?(false)
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.pasteDelay) { [weak self] in
            MainActor.assumeIsolated {
                completion?(self?.synthesizeCommandV(into: targetPID) ?? false)
            }
        }
    }

    /// Posts a `⌘V` key-down/key-up pair.
    ///
    /// Prefer posting to the target process when we know it: a session-wide tap
    /// can race with focus changes and land on us (or nowhere). Returns false
    /// when Accessibility permission is missing.
    @discardableResult
    public func synthesizeCommandV() -> Bool {
        synthesizeCommandV(into: nil)
    }

    @discardableResult
    public func synthesizeCommandV(into targetPID: pid_t?) -> Bool {
        guard AXIsProcessTrusted(), let source = CGEventSource(stateID: .combinedSessionState)
        else { return false }

        // Keep the user's own input flowing during the suppression interval that
        // follows a synthetic event, otherwise their next keystroke is dropped.
        source.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitLocalKeyboardEvents],
            state: .eventSuppressionStateSuppressionInterval
        )

        let key = CGKeyCode(VirtualKey.v)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
        else { return false }

        keyDown.flags = .maskCommand
        keyUp.flags = []

        if let targetPID, targetPID > 0 {
            keyDown.postToPid(targetPID)
            keyUp.postToPid(targetPID)
        } else {
            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }
        return true
    }
}
