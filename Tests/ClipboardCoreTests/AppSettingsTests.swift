import Foundation
import Testing
@testable import ClipboardCore

@Suite("AppSettings") @MainActor
struct AppSettingsTests {

    // MARK: - Defaults

    @Test("defaults when store is empty: maxItems 25, correct hotkey, autoPaste, captureImages, launchAtLogin, system appearance")
    func defaultsWithEmptyStore() {
        let settings = AppSettings(store: InMemoryKeyValueStore())
        #expect(settings.maxItems == 25)
        #expect(settings.openHistoryHotkey == .openHistoryDefault)
        #expect(settings.autoPaste == true)
        #expect(settings.captureImages == true)
        #expect(settings.launchAtLogin == false)
        #expect(settings.appearance == .system)
    }

    @Test("appearance preference round-trips through the store")
    func appearanceRoundTrip() {
        let store = InMemoryKeyValueStore()
        let s1 = AppSettings(store: store)
        s1.appearance = .dark
        let s2 = AppSettings(store: store)
        #expect(s2.appearance == .dark)
        #expect(store.object(forKey: "appearance") as? String == "dark")
    }

    @Test("unknown appearance string falls back to system")
    func unknownAppearanceFallsBackToSystem() {
        let store = InMemoryKeyValueStore(["appearance": "neon"])
        let settings = AppSettings(store: store)
        #expect(settings.appearance == .system)
    }

    @Test("openHistoryDefault is shift+command+V")
    func openHistoryDefaultIsShiftCommandV() {
        let combo = KeyCombo.openHistoryDefault
        #expect(combo.keyCode == VirtualKey.v)
        #expect(combo.modifiers.contains(.command))
        #expect(combo.modifiers.contains(.shift))
        #expect(!combo.modifiers.contains(.option))
        #expect(!combo.modifiers.contains(.control))
    }

    // MARK: - Write-through

    @Test("mutating maxItems writes through to the store")
    func maxItemsWritesThrough() {
        let store = InMemoryKeyValueStore()
        let settings = AppSettings(store: store)
        settings.maxItems = 50
        #expect(store.object(forKey: "maxItems") as? Int == 50)
    }

    @Test("mutating autoPaste writes through and a second AppSettings reads the mutated value")
    func autoPasteRoundTrip() {
        let store = InMemoryKeyValueStore()
        let s1 = AppSettings(store: store)
        s1.autoPaste = false
        let s2 = AppSettings(store: store)
        #expect(s2.autoPaste == false)
    }

    @Test("mutating captureImages writes through and round-trips")
    func captureImagesRoundTrip() {
        let store = InMemoryKeyValueStore()
        let s1 = AppSettings(store: store)
        s1.captureImages = false
        let s2 = AppSettings(store: store)
        #expect(s2.captureImages == false)
    }

    @Test("mutating launchAtLogin writes through and round-trips")
    func launchAtLoginRoundTrip() {
        let store = InMemoryKeyValueStore()
        let s1 = AppSettings(store: store)
        s1.launchAtLogin = true
        let s2 = AppSettings(store: store)
        #expect(s2.launchAtLogin == true)
    }

    @Test("KeyCombo hotkey round-trips through the store as encoded Data")
    func keyComboRoundTrips() {
        let store = InMemoryKeyValueStore()
        let s1 = AppSettings(store: store)
        let newCombo = KeyCombo(keyCode: VirtualKey.c, modifiers: [.command, .option])
        s1.openHistoryHotkey = newCombo
        let s2 = AppSettings(store: store)
        #expect(s2.openHistoryHotkey == newCombo)
    }

    // MARK: - Clamping

    @Test("maxItems is clamped to 5 when assigned values below the minimum")
    func maxItemsClampedBelowMinimum() {
        let settings = AppSettings(store: InMemoryKeyValueStore())
        settings.maxItems = 1
        #expect(settings.maxItems == 5)
        settings.maxItems = 0
        #expect(settings.maxItems == 5)
        settings.maxItems = -5
        #expect(settings.maxItems == 5)
    }

    @Test("maxItems is clamped to 200 when assigned values above the maximum")
    func maxItemsClampedAboveMaximum() {
        let settings = AppSettings(store: InMemoryKeyValueStore())
        settings.maxItems = 1000
        #expect(settings.maxItems == 200)
    }

    @Test("maxItems is clamped on load when the stored value is out of range")
    func maxItemsClampedOnLoad() {
        let store = InMemoryKeyValueStore(["maxItems": 0])
        let settings = AppSettings(store: store)
        #expect(settings.maxItems == 5)

        let store2 = InMemoryKeyValueStore(["maxItems": 9999])
        let settings2 = AppSettings(store: store2)
        #expect(settings2.maxItems == 200)
    }

    // MARK: - resetToDefaults

    @Test("resetToDefaults restores maxItems, hotkeys, autoPaste, captureImages")
    func resetToDefaultsRestoresValues() {
        let settings = AppSettings(store: InMemoryKeyValueStore())
        settings.maxItems = 100
        settings.autoPaste = false
        settings.captureImages = false
        settings.appearance = .light
        settings.openHistoryHotkey = KeyCombo(keyCode: VirtualKey.c, modifiers: [.command])
        settings.resetToDefaults()
        #expect(settings.maxItems == 25)
        #expect(settings.autoPaste == true)
        #expect(settings.captureImages == true)
        #expect(settings.appearance == .system)
        #expect(settings.openHistoryHotkey == .openHistoryDefault)
    }

    @Test("resetToDefaults leaves launchAtLogin alone")
    func resetToDefaultsLeavesLaunchAtLoginAlone() {
        let settings = AppSettings(store: InMemoryKeyValueStore())
        settings.launchAtLogin = true
        settings.resetToDefaults()
        #expect(settings.launchAtLogin == true)

        settings.launchAtLogin = false
        settings.resetToDefaults()
        #expect(settings.launchAtLogin == false)
    }

    // MARK: - Garbage values fallback

    @Test("a String stored for the hotkey key falls back to the default instead of crashing")
    func garbageHotkeyStringFallsBackToDefault() {
        let store = InMemoryKeyValueStore(["openHistoryHotkey": "not data at all"])
        let settings = AppSettings(store: store)
        #expect(settings.openHistoryHotkey == .openHistoryDefault)
    }

    @Test("random bytes stored for the hotkey key fall back to the default instead of crashing")
    func garbageHotkeyDataFallsBackToDefault() {
        let randomData = Data(repeating: 0xFF, count: 100)
        let store = InMemoryKeyValueStore(["openHistoryHotkey": randomData])
        let settings = AppSettings(store: store)
        #expect(settings.openHistoryHotkey == .openHistoryDefault)
    }
}
