import AppKit
import ClipboardCore
import ClipboardPlatform
import SwiftUI

/// A borderless panel that can take keyboard focus without activating the app,
/// so the app the user was typing in stays frontmost and ⌘V lands there.
final class HistoryPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Shows, places, and drives the history popup.
@MainActor
final class HistoryPanelController {
    /// `plainTextOnly` is true when the user held Option.
    var onChoose: ((ClipboardItem, Bool) -> Void)?
    var onDismiss: (() -> Void)?

    private let model: HistoryPanelModel
    private var panel: HistoryPanel?
    private var hostingView: ClearHostingView<HistoryListView>?
    private var keyMonitor: Any?
    private var outsideClickMonitor: Any?
    private var observers: [NSObjectProtocol] = []
    private var anchor: PanelAnchor = .centered
    private var isDismissing = false

    init(model: HistoryPanelModel) {
        self.model = model
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    // MARK: - Presentation

    func toggle(anchor: PanelAnchor) {
        if isVisible {
            dismiss()
        } else {
            show(anchor: anchor)
        }
    }

    func show(anchor: PanelAnchor) {
        self.anchor = anchor
        model.reset()

        let panel = panel ?? makePanel()
        self.panel = panel
        layout(panel)

        panel.makeKeyAndOrderFront(nil)
        if !panel.isKeyWindow {
            // Some configurations refuse key status to an inactive app; falling
            // back to activating ourselves keeps the keyboard working.
            NSApp.activate()
            panel.makeKeyAndOrderFront(nil)
        }
        panel.orderFrontRegardless()

        installKeyMonitor()
        installDismissObservers(for: panel)
        AppLog.panel.debug("Panel shown with \(self.model.visibleItems.count) rows")
    }

    func dismiss(reactivate: Bool = true) {
        guard !isDismissing, let panel else { return }
        isDismissing = true
        removeKeyMonitor()
        removeDismissObservers()
        panel.orderOut(nil)
        isDismissing = false
        if reactivate { onDismiss?() }
    }

    /// Positions the fixed-size panel near the caret / pointer.
    private func layout(_ panel: HistoryPanel) {
        let size = CGSize(width: HistoryListView.width, height: HistoryListView.panelHeight)
        let screen = screenForAnchor() ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1_440, height: 900)
        let origin = PanelPlacer.origin(panelSize: size, anchor: anchor, visibleFrame: visibleFrame)
        panel.setFrame(CGRect(origin: origin, size: size), display: true)
        panel.invalidateShadow()
    }

    private func screenForAnchor() -> NSScreen? {
        let point: CGPoint
        switch anchor {
        case .belowRect(let rect): point = CGPoint(x: rect.midX, y: rect.midY)
        case .atPoint(let value): point = value
        case .centered: return NSScreen.main
        }
        return NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
    }

    private func makePanel() -> HistoryPanel {
        let panel = HistoryPanel(
            contentRect: CGRect(x: 0, y: 0, width: HistoryListView.width, height: 300),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        // System shadows are rectangular and show up as a square hairline past
        // the rounded plate. Skip them; the vibrancy plate reads clearly alone.
        panel.hasShadow = false
        panel.animationBehavior = .utilityWindow
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.setAccessibilityLabel("Clipboard History")

        let chrome = RoundedPanelChromeView()
        let hosting = ClearHostingView(rootView: makeRootView())
        hosting.translatesAutoresizingMaskIntoConstraints = false
        chrome.contentView.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: chrome.contentView.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: chrome.contentView.trailingAnchor),
            hosting.topAnchor.constraint(equalTo: chrome.contentView.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: chrome.contentView.bottomAnchor),
        ])
        hostingView = hosting
        panel.contentView = chrome
        return panel
    }

    private func makeRootView() -> HistoryListView {
        HistoryListView(model: model) { [weak self] item, plainTextOnly in
            self?.choose(item, plainTextOnly: plainTextOnly)
        }
    }

    private func choose(_ item: ClipboardItem, plainTextOnly: Bool) {
        // Hide first so we are no longer the key window, then hand off. The
        // paster owns reactivation; calling it before the panel is gone races
        // the synthetic ⌘V against our own teardown.
        dismiss(reactivate: false)
        onChoose?(item, plainTextOnly)
    }

    // MARK: - Keyboard

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isVisible else { return event }
            return self.handle(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    /// Returns whether the event was consumed.
    ///
    /// Navigation and app shortcuts are handled here. Typing, ←/→ caret moves,
    /// Backspace, and standard text editing are left for the focused search field.
    private func handle(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let command = flags.contains(.command)

        switch event.keyCode {
        case VirtualKey.escape:
            if model.isFiltering {
                model.clearQuery()
            } else {
                dismiss()
            }
            return true

        case VirtualKey.arrowUp:
            model.moveSelection(by: -1)
            return true

        case VirtualKey.arrowDown:
            model.moveSelection(by: 1)
            return true

        case VirtualKey.returnKey, KeyCodes.keypadEnter:
            if let item = model.selectedItem {
                choose(item, plainTextOnly: flags.contains(.option))
            }
            return true

        case VirtualKey.delete where command:
            model.deleteSelection()
            return true

        case KeyCodes.pageUp:
            model.moveSelection(by: -HistoryPanelModel.maxVisibleRows)
            return true

        case KeyCodes.pageDown:
            model.moveSelection(by: HistoryPanelModel.maxVisibleRows)
            return true

        case KeyCodes.p where command:
            model.togglePinOnSelection()
            return true

        default:
            break
        }

        if command, let digit = Int(event.charactersIgnoringModifiers ?? ""), digit >= 1, digit <= 9 {
            if let item = model.item(forNumericShortcut: digit) {
                choose(item, plainTextOnly: flags.contains(.option))
            }
            return true
        }

        // Prefer the focused search field. If focus has not landed yet (common
        // on the first keystrokes after open), fall back to the model so those
        // characters are not dropped.
        if HistoryPanelTypingFallback.apply(
            keyCode: event.keyCode,
            characters: event.characters,
            command: command,
            control: flags.contains(.control),
            option: flags.contains(.option),
            searchFieldFocused: isSearchFieldFirstResponder,
            append: { model.appendToQuery($0) },
            deleteBackward: { model.deleteBackwardInQuery() }
        ) {
            return true
        }

        // ←/→, Home/End, ⌘A/⌘V, and focused typing reach the TextField.
        return false
    }

    /// SwiftUI's `TextField` uses an `NSTextField` / field-editor `NSTextView`.
    private var isSearchFieldFirstResponder: Bool {
        guard let responder = panel?.firstResponder else { return false }
        if responder is NSTextField { return true }
        if let textView = responder as? NSTextView, textView.isFieldEditor { return true }
        return false
    }

    private enum KeyCodes {
        static let p: UInt16 = 35
        static let keypadEnter: UInt16 = 76
        static let home: UInt16 = 115
        static let end: UInt16 = 119
        static let pageUp: UInt16 = 116
        static let pageDown: UInt16 = 121
    }

    // MARK: - Dismissal

    private func installDismissObservers(for panel: NSPanel) {
        guard observers.isEmpty else { return }
        // A non-activating panel can stay key while another app is frontmost, so
        // resigning key is not a reliable signal on its own.
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let frame = self.panel?.frame else { return }
                if !frame.contains(NSEvent.mouseLocation) { self.dismiss() }
            }
        }

        let center = NotificationCenter.default
        observers.append(
            center.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: panel,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.dismiss() }
            }
        )
        observers.append(
            center.addObserver(
                forName: NSApplication.didResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.dismiss() }
            }
        )
    }

    private func removeDismissObservers() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        outsideClickMonitor = nil
    }
}
