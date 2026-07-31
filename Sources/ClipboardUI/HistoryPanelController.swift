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

/// Shows, places, and drives the history / emoji popup.
@MainActor
final class HistoryPanelController {
    /// `plainTextOnly` is true when the user held Option.
    var onChooseClipboard: ((ClipboardItem, Bool) -> Void)?
    var onChooseEmoji: ((String) -> Void)?
    var onDismiss: (() -> Void)?

    private let session: PanelSessionModel
    private var panel: HistoryPanel?
    private var hostingView: ClearHostingView<PanelRootView>?
    private var keyMonitor: Any?
    private var outsideClickMonitor: Any?
    private var observers: [NSObjectProtocol] = []
    private var anchor: PanelAnchor = .centered
    private var isDismissing = false

    init(session: PanelSessionModel) {
        self.session = session
    }

    /// Convenience for call sites that still construct from a history model.
    convenience init(model: HistoryPanelModel) {
        self.init(session: PanelSessionModel(history: model))
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
        session.reset()

        let panel = panel ?? makePanel()
        self.panel = panel
        layout(panel)

        // Activate so the local key monitor receives typing / Return. Stay
        // `.accessory` — flipping to `.regular` breaks paste reactivation on
        // macOS 14+.
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()

        installKeyMonitor()
        installDismissObservers(for: panel)
        AppLog.panel.debug("Panel shown in \(self.session.mode.rawValue) mode")
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

    private func layout(_ panel: HistoryPanel) {
        let size = CGSize(width: PanelRootView.width, height: PanelRootView.panelHeight)
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
            contentRect: CGRect(x: 0, y: 0, width: PanelRootView.width, height: 300),
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

    private func makeRootView() -> PanelRootView {
        PanelRootView(
            session: session,
            onChooseClipboard: { [weak self] item, plain in
                self?.chooseClipboard(item, plainTextOnly: plain)
            },
            onChooseEmoji: { [weak self] emoji in
                self?.chooseEmoji(emoji)
            }
        )
    }

    private func chooseClipboard(_ item: ClipboardItem, plainTextOnly: Bool) {
        dismiss(reactivate: false)
        onChooseClipboard?(item, plainTextOnly)
    }

    private func chooseEmoji(_ emoji: String) {
        dismiss(reactivate: false)
        onChooseEmoji?(emoji)
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

    private func handle(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let command = flags.contains(.command)

        let control = flags.contains(.control)

        // ⌃1 / ⌃2 switch tabs without stealing ⌘1–⌘9 history shortcuts.
        if control, !command, let digit = Int(event.charactersIgnoringModifiers ?? ""),
           (1...PanelMode.allCases.count).contains(digit) {
            session.mode = PanelMode.allCases[digit - 1]
            return true
        }

        switch session.mode {
        case .clipboard:
            return handleClipboard(event, flags: flags, command: command)
        case .emoji:
            return handleEmoji(event, flags: flags, command: command)
        }
    }

    private func handleClipboard(_ event: NSEvent, flags: NSEvent.ModifierFlags, command: Bool) -> Bool {
        let model = session.history
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
                chooseClipboard(item, plainTextOnly: flags.contains(.option))
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
                chooseClipboard(item, plainTextOnly: flags.contains(.option))
            }
            return true
        }

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
        return false
    }

    private func handleEmoji(_ event: NSEvent, flags: NSEvent.ModifierFlags, command: Bool) -> Bool {
        let model = session.emoji
        switch event.keyCode {
        case VirtualKey.escape:
            if model.isFiltering {
                model.clearQuery()
            } else {
                dismiss()
            }
            return true
        case VirtualKey.arrowUp:
            model.moveSelection(rows: -1, columns: 0)
            return true
        case VirtualKey.arrowDown:
            model.moveSelection(rows: 1, columns: 0)
            return true
        case VirtualKey.arrowLeft:
            if isSearchFieldFirstResponder { return false }
            model.moveSelection(rows: 0, columns: -1)
            return true
        case VirtualKey.arrowRight:
            if isSearchFieldFirstResponder { return false }
            model.moveSelection(rows: 0, columns: 1)
            return true
        case VirtualKey.returnKey, KeyCodes.keypadEnter:
            if let emoji = model.selectedEmoji {
                chooseEmoji(emoji)
            }
            return true
        default:
            break
        }

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
        return false
    }

    private var isSearchFieldFirstResponder: Bool {
        guard let responder = panel?.firstResponder else { return false }
        if responder is NSTextField { return true }
        if let textView = responder as? NSTextView, textView.isFieldEditor { return true }
        return false
    }

    private enum KeyCodes {
        static let p: UInt16 = 35
        static let keypadEnter: UInt16 = 76
        static let pageUp: UInt16 = 116
        static let pageDown: UInt16 = 121
    }

    // MARK: - Dismissal

    private func installDismissObservers(for panel: NSPanel) {
        guard observers.isEmpty else { return }
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
