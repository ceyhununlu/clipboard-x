import AppKit
import ApplicationServices
import ClipboardCore
import CoreGraphics
import Foundation

/// Delivers a history item to the app the user was working in.
///
/// The pasteboard write always happens; synthesizing paste needs Accessibility.
/// Without a grant the item is still on the clipboard for a manual ⌘V.
@MainActor
public final class Paster {
    /// Time for the previous app to become key after we yield activation.
    private static let pasteDelay: TimeInterval = 0.18

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
    public func deliver(
        _ content: ClipboardContent,
        plainTextOnly: Bool,
        autoPaste: Bool,
        completion: (@MainActor (Bool) -> Void)?
    ) {
        if !(plainTextOnly && pasteboard.writePlainText(content)) {
            pasteboard.write(content)
        }
        let axText: String?
        if plainTextOnly {
            axText = content.plainText
        } else if case .text(let string) = content {
            axText = string
        } else {
            axText = nil
        }
        finishDelivery(plainText: axText, autoPaste: autoPaste, completion: completion)
    }

    /// Pastes a plain string (emoji / text snippets from the picker).
    public func deliverText(
        _ string: String,
        autoPaste: Bool,
        completion: (@MainActor (Bool) -> Void)?
    ) {
        pasteboard.write(.text(string))
        finishDelivery(plainText: string, autoPaste: autoPaste, completion: completion)
    }

    private func finishDelivery(
        plainText: String?,
        autoPaste: Bool,
        completion: (@MainActor (Bool) -> Void)?
    ) {
        onPasteboardWrite?()

        permission.refresh()
        let canPaste = autoPaste && AXIsProcessTrusted()
        let targetPID = tracker.capturedApp?.processIdentifier

        // AX fast path only when the captured element still belongs to the
        // captured app — avoids inserting into a stale background field.
        if canPaste,
           let plainText,
           let targetPID,
           let element = tracker.capturedFocusedElement,
           tracker.elementBelongs(to: targetPID, element: element) {
            _ = AXUIElementSetAttributeValue(
                element,
                kAXFocusedAttribute as CFString,
                kCFBooleanTrue as CFTypeRef
            )
            if insertText(plainText, into: element) {
                tracker.reactivate()
                completion?(true)
                return
            }
        }

        // Fall back: return focus, then ⌘V (images / Electron / failed AX).
        tracker.reactivate()

        guard canPaste else {
            if autoPaste, !AXIsProcessTrusted() {
                permission.presentExplanation()
            }
            completion?(false)
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.pasteDelay) { [weak self] in
            MainActor.assumeIsolated {
                guard let self else {
                    completion?(false)
                    return
                }
                self.tracker.reactivate()

                if let plainText,
                   let targetPID,
                   self.insertTextViaAccessibility(plainText, expectedPID: targetPID) {
                    completion?(true)
                    return
                }
                completion?(self.synthesizeCommandV(into: targetPID))
            }
        }
    }

    /// Inserts only into a focused element that still belongs to `expectedPID`.
    private func insertTextViaAccessibility(_ string: String, expectedPID: pid_t) -> Bool {
        let appElement = AXUIElementCreateApplication(expectedPID)
        var focused: CFTypeRef?
        if AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focused
        ) == .success,
            let focused {
            let element = unsafeBitCast(focused, to: AXUIElement.self)
            if tracker.elementBelongs(to: expectedPID, element: element),
               insertText(string, into: element) {
                return true
            }
        }
        return false
    }

    private func insertText(_ string: String, into element: AXUIElement) -> Bool {
        AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            string as CFTypeRef
        ) == .success
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

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

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
