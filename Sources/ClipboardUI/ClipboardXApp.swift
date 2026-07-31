import AppKit
import ClipboardCore
import ClipboardPlatform
import Combine
import SwiftUI

/// The application: owns every long-lived object and wires them together.
@MainActor
public final class ClipboardXApp: NSObject, NSApplicationDelegate {
    private static var shared: ClipboardXApp?

    /// Entry point. The process starts on the main thread, so the hop to the
    /// main actor is a formality the compiler needs spelled out.
    public nonisolated static func launch() {
        MainActor.assumeIsolated { start() }
    }

    private static func start() {
        let application = NSApplication.shared
        let delegate = ClipboardXApp()
        shared = delegate
        application.delegate = delegate
        // Accessory: menu bar only, no Dock icon, no app menu.
        application.setActivationPolicy(.accessory)
        application.run()
    }

    private let settings: AppSettings
    private let permission = AccessibilityPermission()
    private let pasteboard = SystemPasteboard()
    private let tracker = FrontmostAppTracker()
    private let hotkeys = GlobalHotkeyManager()
    private let caretLocator = CaretLocator()
    private let loginItems = LoginItemManager()
    private let bridge = SettingsBridge()

    private var store: HistoryStore!
    private var monitor: ClipboardMonitor!
    private var paster: Paster!
    private var panelModel: HistoryPanelModel!
    private var panelSession: PanelSessionModel!
    private var panel: HistoryPanelController!
    private var menuBar: MenuBarController!
    private var settingsWindow: SettingsWindowController!
    private var paths: AppPaths!
    private var updater: UpdateController?

    private var cancellables: Set<AnyCancellable> = []
    private var appliedHotkeys: [HotkeySlot: KeyCombo] = [:]

    override init() {
        self.settings = AppSettings()
        super.init()
    }

    // MARK: - Lifecycle

    public func applicationDidFinishLaunching(_ notification: Notification) {
        guard !terminateIfAlreadyRunning() else { return }

        do {
            try buildStorage()
        } catch {
            presentFatalStorageError(error)
            return
        }

        buildInterface()
        buildClipboardPipeline()
        observeSettings()
        applySettings(initial: true)
        checkPermission()
        startUpdaterIfBundled()

        AppLog.app.info("ClipboardX \(AppInfo.version) started with \(self.store.items.count) items")
    }

    private func startUpdaterIfBundled() {
        // Sparkle needs a real app bundle + feed URL from Info.plist.
        guard AppInfo.isBundled else { return }
        let updater = UpdateController()
        self.updater = updater
        menuBar.onCheckForUpdates = { [weak updater] in
            updater?.checkForUpdates(nil)
        }
    }

    public func applicationWillTerminate(_ notification: Notification) {
        monitor?.stop()
        hotkeys.unregisterAll()
        permission.stopMonitoring()
        store?.flush()
    }

    /// Only one instance may run: two pasteboard monitors would fight over the
    /// same history file.
    private func terminateIfAlreadyRunning() -> Bool {
        guard let identifier = Bundle.main.bundleIdentifier, AppInfo.isBundled else { return false }
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
            .filter { $0 != .current }
        guard !others.isEmpty else { return false }
        AppLog.app.notice("Another ClipboardX instance is running; activating it and exiting")
        others.first?.activate()
        NSApp.terminate(nil)
        return true
    }

    // MARK: - Construction

    private func buildStorage() throws {
        paths = try AppPaths.standard()
        let index = try FileHistoryIndexStore(url: paths.indexURL)
        let blobs = try FileBlobStore(directory: paths.blobsDirectory)
        store = HistoryStore(index: index, blobs: blobs, maxItems: settings.maxItems)
        store.load()
        let removed = store.removeBrokenItems()
        if removed > 0 {
            AppLog.app.notice("Dropped \(removed) items whose payload files were missing")
        }
    }

    private func buildClipboardPipeline() {
        paster = Paster(pasteboard: pasteboard, permission: permission, tracker: tracker)
        monitor = ClipboardMonitor(source: pasteboard) { [weak self] content in
            self?.record(content)
        }
        paster.onPasteboardWrite = { [weak self] in
            self?.monitor.acknowledgeSelfWrite()
        }
        monitor.start()
    }

    private func buildInterface() {
        panelModel = HistoryPanelModel(store: store)
        panelSession = PanelSessionModel(history: panelModel)
        panel = HistoryPanelController(session: panelSession)
        panel.onChooseClipboard = { [weak self] item, plainTextOnly in
            self?.deliver(item, plainTextOnly: plainTextOnly)
        }
        panel.onChooseEmoji = { [weak self] emoji in
            self?.deliverEmoji(emoji)
        }
        panel.onDismiss = { [weak self] in
            self?.tracker.reactivate()
            self?.tracker.clear()
        }

        menuBar = MenuBarController(store: store, settings: settings, permission: permission)
        menuBar.onOpenHistory = { [weak self] in self?.openHistory() }
        menuBar.onOpenSettings = { [weak self] in self?.openSettings() }
        menuBar.onMenuWillOpen = { [weak self] in self?.tracker.capture() }
        menuBar.onChoose = { [weak self] item in
            self?.deliver(item, plainTextOnly: false)
        }
        menuBar.onClearHistory = { [weak self] in self?.confirmClearHistory() }
        menuBar.onFixPermission = { [weak self] in self?.permission.presentExplanation() }
        menuBar.onQuit = { NSApp.terminate(nil) }

        bridge.revealStorage = { [weak self] in
            guard let self else { return }
            NSWorkspace.shared.activateFileViewerSelecting([self.paths.indexURL])
        }
        bridge.clearHistory = { [weak self] keepingPinned in
            self?.store.clear(keepingPinned: keepingPinned)
            self?.bridge.storageBytes = self?.store.storageBytes ?? 0
            ThumbnailCache.shared.removeAll()
        }
        bridge.refreshStorage = { [weak self] in
            self?.bridge.storageBytes = self?.store.storageBytes ?? 0
        }
        bridge.resetSettings = { [weak self] in self?.settings.resetToDefaults() }
        bridge.quit = { NSApp.terminate(nil) }

        let settings = settings
        let store = store!
        let permission = permission
        let bridge = bridge
        settingsWindow = SettingsWindowController {
            SettingsView(settings: settings, store: store, permission: permission, bridge: bridge)
        }
    }

    private func observeSettings() {
        // `objectWillChange` fires before the new value is readable, so the work
        // is deferred by one run-loop turn and then applied idempotently.
        settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.applySettings(initial: false) }
            .store(in: &cancellables)

        permission.$isTrusted
            .removeDuplicates()
            .sink { [weak self] isTrusted in
                AppLog.permissions.info("Accessibility trusted: \(isTrusted)")
                // Once macOS reports a live grant, allow a future revoke to
                // prompt again and stop treating a stale Settings row as "done".
                if isTrusted {
                    self?.settings.dismissedAccessibilityPrompt = false
                }
            }
            .store(in: &cancellables)
    }

    private func applySettings(initial: Bool) {
        store.maxItems = settings.maxItems
        pasteboard.capturesImages = settings.captureImages
        menuBar.setVisible(settings.showsMenuBarIcon)
        menuBar.refreshTooltip()
        applyAppearance()
        applyHotkeys()
        applyLoginItem(initial: initial)
        bridge.storageBytes = store.storageBytes
    }

    private func applyAppearance() {
        switch settings.appearance {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    // MARK: - Hotkeys

    private func applyHotkeys() {
        register(settings.openHistoryHotkey, for: .openHistory) { [weak self] in
            self?.openHistory()
        }

        if settings.isPastePlainTextEnabled {
            register(settings.pastePlainTextHotkey, for: .pastePlainText) { [weak self] in
                self?.pasteMostRecentAsPlainText()
            }
        } else if appliedHotkeys[.pastePlainText] != nil {
            hotkeys.unregister(.pastePlainText)
            appliedHotkeys[.pastePlainText] = nil
            bridge.setError(nil, for: .pastePlainText)
        }
    }

    private func register(
        _ combo: KeyCombo,
        for slot: HotkeySlot,
        handler: @escaping @MainActor () -> Void
    ) {
        guard appliedHotkeys[slot] != combo else { return }
        switch hotkeys.register(combo, for: slot, handler: handler) {
        case .success:
            appliedHotkeys[slot] = combo
            bridge.setError(nil, for: slot)
            AppLog.hotkeys.info("Registered \(combo.displayString) for \(slot.rawValue)")
        case .failure(let error):
            appliedHotkeys[slot] = nil
            bridge.setError(error.localizedDescription, for: slot)
            AppLog.hotkeys.error("Could not register \(combo.displayString): \(error.localizedDescription)")
        }
    }

    // MARK: - Login item

    private func applyLoginItem(initial: Bool) {
        bridge.isLoginItemAvailable = loginItems.isAvailable
        guard loginItems.isAvailable else {
            bridge.loginItemStatus = loginItems.statusDescription
            return
        }
        if initial {
            // Trust the system's record over ours in case the user changed it in
            // System Settings while the app was closed.
            settings.launchAtLogin = loginItems.isEnabled
        } else if settings.launchAtLogin != loginItems.isEnabled {
            do {
                try loginItems.setEnabled(settings.launchAtLogin)
                bridge.loginItemError = nil
            } catch {
                bridge.loginItemError = error.localizedDescription
                AppLog.app.error("Login item change failed: \(error.localizedDescription)")
            }
        }
        bridge.loginItemStatus = loginItems.statusDescription
    }

    // MARK: - Clipboard flow

    private func record(_ content: ClipboardContent) {
        guard settings.captureImages || content.kind != .image else { return }
        guard let item = store.insert(content) else { return }
        AppLog.clipboard.debug("Recorded \(item.kind.rawValue) item, \(item.byteCount) bytes")
    }

    private func openHistory() {
        tracker.capture()
        let location = caretLocator.locate(
            processIdentifier: tracker.capturedApp?.processIdentifier
        )
        AppLog.panel.debug("Opening at \(String(describing: location))")
        panel.toggle(anchor: location.anchor)
    }

    private func deliver(_ item: ClipboardItem, plainTextOnly: Bool) {
        guard let content = panelModel.content(for: item) else {
            NSSound.beep()
            return
        }
        paster.deliver(
            content,
            plainTextOnly: plainTextOnly,
            autoPaste: settings.autoPaste
        ) { [weak self] pasted in
            AppLog.clipboard.debug("Delivered item, synthesized paste: \(pasted)")
            self?.tracker.clear()
        }
    }

    private func deliverEmoji(_ emoji: String) {
        paster.deliverText(emoji, autoPaste: settings.autoPaste) { [weak self] pasted in
            AppLog.clipboard.debug("Delivered emoji, synthesized paste: \(pasted)")
            self?.tracker.clear()
        }
    }

    private func pasteMostRecentAsPlainText() {
        tracker.capture()
        guard let item = store.items.first else {
            NSSound.beep()
            return
        }
        deliver(item, plainTextOnly: true)
    }

    // MARK: - Commands

    private func openSettings() {
        bridge.storageBytes = store.storageBytes
        settingsWindow.show()
    }

    private func confirmClearHistory() {
        let alert = NSAlert()
        alert.messageText = "Clear clipboard history?"
        alert.informativeText = store.pinnedCount > 0
            ? "Pinned items are kept. This cannot be undone."
            : "This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        store.clear(keepingPinned: true)
        ThumbnailCache.shared.removeAll()
        bridge.storageBytes = store.storageBytes
    }

    private func checkPermission() {
        permission.startMonitoring()
        // Re-read immediately: TCC can lag a moment after launch, and a stale
        // "enabled" row in System Settings does not mean AXIsProcessTrusted().
        permission.refresh()
        guard !permission.isTrusted, !settings.dismissedAccessibilityPrompt else { return }

        // Let the menu bar item appear first so the alert has visible context.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self else { return }
            self.permission.refresh()
            guard !self.permission.isTrusted, !self.settings.dismissedAccessibilityPrompt else { return }
            NSApp.activate()
            _ = self.permission.presentExplanation()
            // Whether they chose Settings or Not Now, do not reappear on every
            // launch — the menu bar item still offers a way back.
            self.settings.dismissedAccessibilityPrompt = true
        }
    }

    private func presentFatalStorageError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "ClipboardX cannot access its storage"
        alert.informativeText = """
            \(error.localizedDescription)

            Check that ~/Library/Application Support is writable, then reopen ClipboardX.
            """
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Quit")
        NSApp.activate()
        alert.runModal()
        NSApp.terminate(nil)
    }
}
