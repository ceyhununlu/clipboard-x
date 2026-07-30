import Combine
import Foundation

/// The subset of `UserDefaults` the settings need, so tests can run against a
/// dictionary instead of the real defaults database.
public protocol KeyValueStore: AnyObject {
    func object(forKey defaultName: String) -> Any?
    func set(_ value: Any?, forKey defaultName: String)
}

extension UserDefaults: KeyValueStore {}

public final class InMemoryKeyValueStore: KeyValueStore {
    private var storage: [String: Any]

    public init(_ initial: [String: Any] = [:]) {
        self.storage = initial
    }

    public func object(forKey defaultName: String) -> Any? { storage[defaultName] }

    public func set(_ value: Any?, forKey defaultName: String) {
        if let value {
            storage[defaultName] = value
        } else {
            storage.removeValue(forKey: defaultName)
        }
    }
}

/// User-visible preferences, persisted as they change.
@MainActor
public final class AppSettings: ObservableObject {
    public static let maxItemsRange = 5...200
    public static let defaultMaxItems = 25

    public static func clampMaxItems(_ value: Int) -> Int {
        min(max(value, maxItemsRange.lowerBound), maxItemsRange.upperBound)
    }

    private enum Key {
        static let maxItems = "maxItems"
        static let openHistoryHotkey = "openHistoryHotkey"
        static let pastePlainTextHotkey = "pastePlainTextHotkey"
        static let pastePlainTextEnabled = "pastePlainTextEnabled"
        static let launchAtLogin = "launchAtLogin"
        static let autoPaste = "autoPaste"
        static let captureImages = "captureImages"
        static let showsMenuBarIcon = "showsMenuBarIcon"
        static let dismissedAccessibilityPrompt = "dismissedAccessibilityPrompt"
        static let appearance = "appearance"
    }

    private let store: KeyValueStore
    private var isLoading = true

    @Published public var maxItems: Int = defaultMaxItems {
        didSet {
            let clamped = Self.clampMaxItems(maxItems)
            if clamped != maxItems {
                maxItems = clamped
                return
            }
            write(maxItems, Key.maxItems)
        }
    }

    @Published public var openHistoryHotkey: KeyCombo = .openHistoryDefault {
        didSet { writeCombo(openHistoryHotkey, Key.openHistoryHotkey) }
    }

    @Published public var pastePlainTextHotkey: KeyCombo = .pastePlainTextDefault {
        didSet { writeCombo(pastePlainTextHotkey, Key.pastePlainTextHotkey) }
    }

    @Published public var isPastePlainTextEnabled: Bool = true {
        didSet { write(isPastePlainTextEnabled, Key.pastePlainTextEnabled) }
    }

    @Published public var launchAtLogin: Bool = false {
        didSet { write(launchAtLogin, Key.launchAtLogin) }
    }

    /// Whether selecting an item also synthesizes ⌘V into the previous app.
    @Published public var autoPaste: Bool = true {
        didSet { write(autoPaste, Key.autoPaste) }
    }

    @Published public var captureImages: Bool = true {
        didSet { write(captureImages, Key.captureImages) }
    }

    @Published public var showsMenuBarIcon: Bool = true {
        didSet { write(showsMenuBarIcon, Key.showsMenuBarIcon) }
    }

    /// Set when the user dismisses the launch-time Accessibility alert with
    /// "Not Now". Cleared automatically once the process becomes trusted so a
    /// later revoke can prompt again.
    @Published public var dismissedAccessibilityPrompt: Bool = false {
        didSet { write(dismissedAccessibilityPrompt, Key.dismissedAccessibilityPrompt) }
    }

    /// Follow the system appearance by default; Light/Dark force a mode.
    @Published public var appearance: AppearancePreference = .system {
        didSet { write(appearance.rawValue, Key.appearance) }
    }

    public init(store: KeyValueStore = UserDefaults.standard) {
        self.store = store
        maxItems = Self.clampMaxItems(read(Key.maxItems) ?? Self.defaultMaxItems)
        openHistoryHotkey = readCombo(Key.openHistoryHotkey) ?? .openHistoryDefault
        pastePlainTextHotkey = readCombo(Key.pastePlainTextHotkey) ?? .pastePlainTextDefault
        isPastePlainTextEnabled = read(Key.pastePlainTextEnabled) ?? true
        launchAtLogin = read(Key.launchAtLogin) ?? false
        autoPaste = read(Key.autoPaste) ?? true
        captureImages = read(Key.captureImages) ?? true
        showsMenuBarIcon = read(Key.showsMenuBarIcon) ?? true
        dismissedAccessibilityPrompt = read(Key.dismissedAccessibilityPrompt) ?? false
        if let raw: String = read(Key.appearance),
           let preference = AppearancePreference(rawValue: raw) {
            appearance = preference
        } else {
            appearance = .system
        }
        isLoading = false
    }

    /// Restores the in-app preferences to their shipped defaults.
    ///
    /// Launch-at-login is left alone on purpose: it is also a system setting,
    /// and resetting shortcuts should not silently unregister the login item.
    public func resetToDefaults() {
        maxItems = Self.defaultMaxItems
        openHistoryHotkey = .openHistoryDefault
        pastePlainTextHotkey = .pastePlainTextDefault
        isPastePlainTextEnabled = true
        autoPaste = true
        captureImages = true
        showsMenuBarIcon = true
        appearance = .system
    }

    // MARK: - Storage

    private func read<T>(_ key: String) -> T? {
        store.object(forKey: key) as? T
    }

    private func write(_ value: Any, _ key: String) {
        guard !isLoading else { return }
        store.set(value, forKey: key)
    }

    private func readCombo(_ key: String) -> KeyCombo? {
        guard let data = store.object(forKey: key) as? Data else { return nil }
        return try? JSONDecoder().decode(KeyCombo.self, from: data)
    }

    private func writeCombo(_ combo: KeyCombo, _ key: String) {
        guard !isLoading, let data = try? JSONEncoder().encode(combo) else { return }
        store.set(data, forKey: key)
    }
}
