import AppKit
import ApplicationServices
import ClipboardCore
import CoreGraphics
import Foundation

/// Delivers a history item to the app the user was working in.
///
/// The pasteboard write always happens; synthesizing paste needs Accessibility.
/// Without a grant the item is still on the clipboard for a manual ⌘V.
///
/// Delivery is deliberately single-shot: one pasteboard write, then at most
/// one ⌘V into the captured app once it is confirmed frontmost. Inserting text
/// through the Accessibility API is avoided on purpose: setting
/// `kAXSelectedText` has no observable outcome (`.success` only means the
/// target accepted the message, and a timed-out request may still be carried
/// out later), so any fallback layered on top of it can end up writing the
/// item twice — or, when the setter silently no-ops, not at all.
@MainActor
public final class Paster {
    /// Some apps (Emacs, Microsoft Remote Desktop) only honour ⌘ on a
    /// synthesized keystroke when a device-specific Command bit is set too.
    private static let leftCommandDeviceFlag = CGEventFlags(rawValue: 0x0000_0008)

    private let pasteboard: SystemPasteboard
    private let permission: AccessibilityPermission
    private let tracker: FrontmostAppTracker
    private let waiter: ActivationWaiter

    /// Called immediately after the app writes to the pasteboard, so the monitor
    /// can discount its own write instead of re-recording the item.
    public var onPasteboardWrite: (() -> Void)?

    public init(
        pasteboard: SystemPasteboard,
        permission: AccessibilityPermission,
        tracker: FrontmostAppTracker,
        waiter: ActivationWaiter = ActivationWaiter()
    ) {
        self.pasteboard = pasteboard
        self.permission = permission
        self.tracker = tracker
        self.waiter = waiter
    }

    /// Puts `content` on the pasteboard and optionally pastes it for the user.
    public func deliver(
        _ content: ClipboardContent,
        plainTextOnly: Bool,
        autoPaste: Bool,
        completion: (@MainActor (Bool) -> Void)?
    ) {
        if !(plainTextOnly && pasteboard.writePlainText(content)) {
            pasteboard.write(content)
        }
        finishDelivery(autoPaste: autoPaste, completion: completion)
    }

    /// Pastes a plain string (emoji / text snippets from the picker).
    public func deliverText(
        _ string: String,
        autoPaste: Bool,
        completion: (@MainActor (Bool) -> Void)?
    ) {
        pasteboard.write(.text(string))
        finishDelivery(autoPaste: autoPaste, completion: completion)
    }

    private func finishDelivery(
        autoPaste: Bool,
        completion: (@MainActor (Bool) -> Void)?
    ) {
        onPasteboardWrite?()

        permission.refresh()
        let canPaste = autoPaste && AXIsProcessTrusted()
        let target = tracker.capturedApp

        // Hand activation back first in every case, so the user is returned to
        // their app even when we end up not pasting.
        tracker.reactivate()

        guard canPaste else {
            if autoPaste, !AXIsProcessTrusted() {
                permission.presentExplanation()
            }
            completion?(false)
            return
        }

        guard let target, !target.isTerminated else {
            // Nothing was captured, so there is no app to wait for. If we are not
            // the active app the frontmost one is the user's; otherwise a
            // session-wide ⌘V would only reach ourselves.
            completion?(NSApp.isActive ? false : synthesizeCommandV(into: nil))
            return
        }

        let pid = target.processIdentifier
        waiter.wait(
            isActive: { NSWorkspace.shared.frontmostApplication?.processIdentifier == pid },
            retryActivation: { [tracker] in _ = tracker.reactivate() },
            completion: { [weak self] activated in
                // Post even when the switch was not observed in time: the event
                // is addressed to the target's process, so it cannot reach any
                // other app, and a target that came forward late still gets it.
                guard let self else {
                    completion?(false)
                    return
                }
                let posted = self.synthesizeCommandV(into: pid)
                completion?(activated && posted)
            }
        )
    }

    /// Posts ⌘V to the target process when known, otherwise to the session.
    @discardableResult
    public func synthesizeCommandV() -> Bool {
        synthesizeCommandV(into: nil)
    }

    @discardableResult
    public func synthesizeCommandV(into targetPID: pid_t?) -> Bool {
        guard AXIsProcessTrusted(),
              let source = CGEventSource(stateID: .combinedSessionState)
        else { return false }

        source.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitLocalKeyboardEvents],
            state: .eventSuppressionStateSuppressionInterval
        )

        let key = CGKeyCode(VirtualKey.v)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
        else { return false }

        let flags: CGEventFlags = [.maskCommand, Self.leftCommandDeviceFlag]
        keyDown.flags = flags
        keyUp.flags = flags

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
