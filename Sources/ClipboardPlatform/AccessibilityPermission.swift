import AppKit
import ApplicationServices
import Combine
import Foundation

/// Tracks the Accessibility (TCC) grant that auto-paste and caret placement
/// depend on.
///
/// Trust is reported by `AXIsProcessTrusted()`, which is bound to the running
/// binary's code signature — not to the app name shown in System Settings. An
/// ad-hoc rebuild changes the code hash, so Settings can still show a toggle
/// as on while this API returns false. Signing with an Apple Development or
/// Developer ID identity keeps the grant stable across rebuilds.
///
/// The system offers no notification when the grant changes, and revoking it
/// does not relaunch the app, so the state is polled while the user is likely to
/// be acting on it (settings open, permission alert shown).
@MainActor
public final class AccessibilityPermission: ObservableObject {
    private static let settingsURL =
        "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

    @Published public private(set) var isTrusted: Bool

    private var timer: Timer?

    public init() {
        isTrusted = AXIsProcessTrusted()
    }

    deinit {
        timer?.invalidate()
    }

    public var isMonitoring: Bool {
        timer != nil
    }

    // MARK: - Observation

    public func refresh() {
        let trusted = AXIsProcessTrusted()
        guard trusted != isTrusted else { return }
        isTrusted = trusted
    }

    public func startMonitoring(interval: TimeInterval = 1.5) {
        guard timer == nil else { return }
        refresh()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        // Common mode keeps polling while a modal alert or menu is tracking.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Requesting

    /// Triggers the system's own "grant accessibility" prompt. Only the first
    /// call per app identity shows anything; afterwards macOS stays silent, which
    /// is why `presentExplanation()` exists.
    public func requestFromSystem() {
        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        isTrusted = AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary)
    }

    /// Opens System Settings → Privacy & Security → Accessibility.
    public func openSystemSettings() {
        _ = openAccessibilitySettings()
    }

    /// Explains what the permission buys the user before sending them to
    /// System Settings. Returns whether settings were opened.
    @discardableResult
    public func presentExplanation() -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "ClipboardX needs Accessibility access"
        alert.informativeText = """
            ClipboardX uses Accessibility access to paste the item you pick into \
            whichever app you were using, and to position the history popup at \
            your text cursor.

            Without it ClipboardX still records your clipboard and still copies \
            the item you pick — you just have to press ⌘V yourself, and the \
            popup appears at the pointer.
            """
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Not Now")
        guard alert.runModal() == .alertFirstButtonReturn else { return false }
        return openAccessibilitySettings()
    }

    private func openAccessibilitySettings() -> Bool {
        guard let url = URL(string: Self.settingsURL) else { return false }
        return NSWorkspace.shared.open(url)
    }
}
