import AppKit
import ClipboardCore
import ClipboardPlatform

/// The status bar item and its menu.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    /// How many recent entries the menu lists directly.
    private static let recentItemLimit = 8
    private static let recentTitleLimit = 52

    var onOpenHistory: () -> Void = {}
    var onOpenSettings: () -> Void = {}
    var onChoose: (ClipboardItem) -> Void = { _ in }
    var onClearHistory: () -> Void = {}
    var onFixPermission: () -> Void = {}
    var onQuit: () -> Void = {}

    private let store: HistoryStore
    private let settings: AppSettings
    private let permission: AccessibilityPermission
    private var statusItem: NSStatusItem?

    init(store: HistoryStore, settings: AppSettings, permission: AccessibilityPermission) {
        self.store = store
        self.settings = settings
        self.permission = permission
        super.init()
    }

    func setVisible(_ visible: Bool) {
        if visible {
            guard statusItem == nil else { return }
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.button?.image = Self.menuBarIcon()
            item.button?.image?.isTemplate = true
            item.button?.toolTip = "ClipboardX — \(settings.openHistoryHotkey.displayString)"
            item.button?.setAccessibilityLabel("ClipboardX clipboard history")
            let menu = NSMenu()
            menu.delegate = self
            item.menu = menu
            statusItem = item
        } else if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    func refreshTooltip() {
        statusItem?.button?.toolTip = "ClipboardX — \(settings.openHistoryHotkey.displayString)"
    }

    private static func menuBarIcon() -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
        for name in ["list.clipboard", "doc.on.clipboard"] {
            if let image = NSImage(systemSymbolName: name, accessibilityDescription: "ClipboardX") {
                return image.withSymbolConfiguration(configuration)
            }
        }
        return nil
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let open = NSMenuItem(
            title: "Open Clipboard History",
            action: #selector(openHistory),
            keyEquivalent: settings.openHistoryHotkey.menuKeyEquivalent
        )
        open.keyEquivalentModifierMask = NSEvent.ModifierFlags(
            rawValue: settings.openHistoryHotkey.cocoaModifierFlags
        )
        open.target = self
        menu.addItem(open)

        if !permission.isTrusted {
            menu.addItem(.separator())
            let warning = NSMenuItem(
                title: "Grant Accessibility Permission…",
                action: #selector(fixPermission),
                keyEquivalent: ""
            )
            warning.target = self
            warning.image = NSImage(
                systemSymbolName: "exclamationmark.triangle.fill",
                accessibilityDescription: nil
            )
            menu.addItem(warning)
        }

        let recent = Array(store.items.prefix(Self.recentItemLimit))
        if !recent.isEmpty {
            menu.addItem(.separator())
            menu.addItem(.sectionHeader(title: "Recent"))

            for (offset, item) in recent.enumerated() {
                let entry = NSMenuItem(
                    title: Self.title(for: item),
                    action: #selector(chooseRecent(_:)),
                    keyEquivalent: offset < 9 ? "\(offset + 1)" : ""
                )
                entry.keyEquivalentModifierMask = [.command]
                entry.target = self
                entry.representedObject = item.id
                entry.image = Self.menuThumbnail(for: item, store: store)
                // A checkmark is the only marker a status menu can show without
                // stealing space from the preview text.
                entry.state = item.isPinned ? .on : .off
                menu.addItem(entry)
            }
        }

        menu.addItem(.separator())

        let clear = NSMenuItem(
            title: "Clear History",
            action: #selector(clearHistory),
            keyEquivalent: ""
        )
        clear.target = self
        clear.isEnabled = !store.items.isEmpty
        menu.addItem(clear)

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit ClipboardX", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    private static func title(for item: ClipboardItem) -> String {
        let preview = item.previewText
        guard preview.count > recentTitleLimit else { return preview }
        return String(preview.prefix(recentTitleLimit)) + "…"
    }

    private static func menuThumbnail(for item: ClipboardItem, store: HistoryStore) -> NSImage? {
        guard item.kind == .image else { return nil }
        guard let thumbnail = ThumbnailCache.shared.thumbnail(for: item, data: {
            store.imageData(for: item)
        }) else { return nil }
        let sized = NSImage(size: CGSize(width: 16, height: 16))
        sized.lockFocus()
        thumbnail.draw(in: CGRect(x: 0, y: 0, width: 16, height: 16))
        sized.unlockFocus()
        return sized
    }

    // MARK: - Actions

    @objc private func openHistory() { onOpenHistory() }
    @objc private func openSettings() { onOpenSettings() }
    @objc private func clearHistory() { onClearHistory() }
    @objc private func fixPermission() { onFixPermission() }
    @objc private func quit() { onQuit() }

    @objc private func chooseRecent(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID,
              let item = store.items.first(where: { $0.id == id })
        else { return }
        onChoose(item)
    }
}
