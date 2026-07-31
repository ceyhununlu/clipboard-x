import AppKit
import ApplicationServices
import ClipboardCore
import Testing

@testable import ClipboardPlatform

@Suite("AccessibilityPermission")
@MainActor
struct AccessibilityPermissionTests {
    @Test("The initial state mirrors the system's answer")
    func initialState() {
        let permission = AccessibilityPermission()

        #expect(permission.isTrusted == AXIsProcessTrusted())
    }

    @Test("Refreshing is silent and idempotent")
    func refreshIsIdempotent() {
        let permission = AccessibilityPermission()

        permission.refresh()
        let first = permission.isTrusted
        permission.refresh()

        #expect(permission.isTrusted == first)
    }

    @Test("Monitoring starts once and stops cleanly")
    func monitoringLifecycle() {
        let permission = AccessibilityPermission()
        defer { permission.stopMonitoring() }

        #expect(permission.isMonitoring == false)
        permission.startMonitoring(interval: 0.05)
        #expect(permission.isMonitoring)
        permission.startMonitoring(interval: 0.05)
        #expect(permission.isMonitoring)
        permission.stopMonitoring()
        #expect(permission.isMonitoring == false)
        permission.stopMonitoring()
        #expect(permission.isMonitoring == false)
    }
}

@Suite("FrontmostAppTracker")
@MainActor
struct FrontmostAppTrackerTests {
    @Test("Nothing captured means nothing to reactivate")
    func reactivateWithoutCapture() {
        let tracker = FrontmostAppTracker()

        tracker.clear()

        #expect(tracker.capturedApp == nil)
        #expect(tracker.reactivate() == false)
    }

    @Test("Capturing never records our own process")
    func neverCapturesSelf() {
        let tracker = FrontmostAppTracker()

        tracker.capture()

        if let captured = tracker.capturedApp {
            #expect(captured.processIdentifier != ProcessInfo.processInfo.processIdentifier)
        }
    }

    @Test("Clearing forgets a capture")
    func clearForgets() {
        let tracker = FrontmostAppTracker()

        tracker.capture()
        tracker.clear()

        #expect(tracker.capturedApp == nil)
        #expect(tracker.capturedFocusedElement == nil)
    }
}

@Suite("Paster")
@MainActor
struct PasterTests {
    private func makePaster() -> (NSPasteboard, SystemPasteboard, Paster) {
        let native = NSPasteboard(
            name: NSPasteboard.Name("com.clipboardx.tests.\(UUID().uuidString)")
        )
        native.clearContents()
        let pasteboard = SystemPasteboard(pasteboard: native)
        let paster = Paster(
            pasteboard: pasteboard,
            permission: AccessibilityPermission(),
            tracker: FrontmostAppTracker()
        )
        return (native, pasteboard, paster)
    }

    @Test("Delivering without auto-paste copies and reports that nothing was pasted")
    func deliverWithoutAutoPaste() {
        let (native, _, paster) = makePaster()
        defer { native.releaseGlobally() }
        var wroteNotifications = 0
        var pasted: Bool?
        paster.onPasteboardWrite = { wroteNotifications += 1 }

        paster.deliver(.text("delivered"), plainTextOnly: false, autoPaste: false) { pasted = $0 }

        #expect(native.string(forType: .string) == "delivered")
        #expect(wroteNotifications == 1)
        #expect(pasted == false)
    }

    @Test("Plain-text delivery drops the formatting")
    func deliverPlainTextOnly() throws {
        let (native, _, paster) = makePaster()
        defer { native.releaseGlobally() }
        let attributed = NSAttributedString(string: "Styled")
        let rtf = try #require(
            attributed.rtf(
                from: NSRange(location: 0, length: attributed.length), documentAttributes: [:]
            )
        )

        paster.deliver(
            .richText(rtf: rtf, plain: "Styled"), plainTextOnly: true, autoPaste: false,
            completion: nil
        )

        #expect(native.data(forType: .rtf) == nil)
        #expect(native.string(forType: .string) == "Styled")
    }

    @Test("Plain-text delivery of an image falls back to the image itself")
    func deliverImageAsPlainText() {
        let (native, _, paster) = makePaster()
        defer { native.releaseGlobally() }
        let payload = ImagePayload(pngData: Data([0x89, 0x50]), pixelWidth: 1, pixelHeight: 1)

        paster.deliver(.image(payload), plainTextOnly: true, autoPaste: false, completion: nil)

        #expect(native.data(forType: .png) == Data([0x89, 0x50]))
    }

    @Test("A missing completion handler is not required")
    func deliverWithoutCompletion() {
        let (native, pasteboard, paster) = makePaster()
        defer { native.releaseGlobally() }

        paster.deliver(.text("quiet"), plainTextOnly: false, autoPaste: false, completion: nil)

        #expect(pasteboard.readContent() == .text("quiet"))
    }
}

@Suite("LoginItemManager")
@MainActor
struct LoginItemManagerTests {
    @Test("Outside an app bundle the feature reports itself unavailable")
    func unavailableUnderSwiftTest() {
        let manager = LoginItemManager()

        #expect(manager.isAvailable == false)
        #expect(manager.isEnabled == false)
        #expect(manager.statusDescription.isEmpty == false)
    }

    @Test("Enabling outside an app bundle throws an explanatory error")
    func enablingThrows() {
        let manager = LoginItemManager()

        #expect(throws: LoginItemError.unavailable) {
            try manager.setEnabled(true)
        }
        #expect(throws: LoginItemError.unavailable) {
            try manager.setEnabled(false)
        }
    }

    @Test("Every error explains itself to the user")
    func errorDescriptions() {
        #expect(LoginItemError.unavailable.errorDescription?.isEmpty == false)
        #expect(LoginItemError.serviceFailed("no").errorDescription?.isEmpty == false)
    }
}
