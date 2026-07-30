import AppKit
import SwiftUI

/// Owns the single settings window, creating it on first use.
@MainActor
final class SettingsWindowController {
    private let makeContent: () -> AnyView
    private var window: NSWindow?

    init<Content: View>(content: @escaping () -> Content) {
        self.makeContent = { AnyView(content()) }
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        if !window.isVisible {
            window.center()
        }
        // An accessory app has to activate explicitly for its window to come
        // forward and accept typing.
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.performClose(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 520, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ClipboardX Settings"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: makeContent())
        window.setContentSize(CGSize(width: 520, height: 400))
        return window
    }
}
