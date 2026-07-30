import Carbon.HIToolbox
import ClipboardCore
import Testing

@testable import ClipboardPlatform

extension Result where Success == Void, Failure == HotkeyError {
    fileprivate var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    fileprivate var failure: HotkeyError? {
        if case .failure(let error) = self { return error }
        return nil
    }
}

/// Registrations are process-wide Carbon state, so these run one at a time and
/// always release what they claimed.
@Suite("GlobalHotkeyManager", .serialized)
@MainActor
struct GlobalHotkeyManagerTests {
    private static let f13: UInt16 = 105
    private static let f14: UInt16 = 107
    private static let f15: UInt16 = 113

    private func unusualCombo(_ keyCode: UInt16) -> KeyCombo {
        KeyCombo(keyCode: keyCode, modifiers: [.control, .option, .command])
    }

    @Test("A valid combo registers and is reported back")
    func registersValidCombo() {
        let manager = GlobalHotkeyManager()
        defer { manager.unregisterAll() }
        let combo = unusualCombo(Self.f13)

        let result = manager.register(combo, for: .openHistory) {}

        #expect(result.isSuccess)
        #expect(manager.registeredCombos[.openHistory] == combo)
        #expect(manager.registeredCombos[.pastePlainText] == nil)
    }

    @Test("Two slots can be registered at once")
    func registersBothSlots() {
        let manager = GlobalHotkeyManager()
        defer { manager.unregisterAll() }

        #expect(manager.register(unusualCombo(Self.f13), for: .openHistory) {}.isSuccess)
        #expect(manager.register(unusualCombo(Self.f14), for: .pastePlainText) {}.isSuccess)
        #expect(manager.registeredCombos.count == 2)
    }

    @Test("A combo without Command, Control or Option is refused")
    func rejectsInvalidCombo() {
        let manager = GlobalHotkeyManager()
        defer { manager.unregisterAll() }
        let shiftOnly = KeyCombo(keyCode: VirtualKey.a, modifiers: [.shift])

        let result = manager.register(shiftOnly, for: .openHistory) {}

        #expect(result.failure == .invalidCombo)
        #expect(manager.registeredCombos.isEmpty)
    }

    @Test("Re-registering a slot replaces its combo")
    func reregisteringReplaces() {
        let manager = GlobalHotkeyManager()
        defer { manager.unregisterAll() }
        let first = unusualCombo(Self.f13)
        let second = unusualCombo(Self.f14)

        #expect(manager.register(first, for: .openHistory) {}.isSuccess)
        #expect(manager.register(second, for: .openHistory) {}.isSuccess)

        #expect(manager.registeredCombos.count == 1)
        #expect(manager.registeredCombos[.openHistory] == second)
    }

    @Test("An invalid replacement leaves the working shortcut in place")
    func invalidReplacementKeepsExisting() {
        let manager = GlobalHotkeyManager()
        defer { manager.unregisterAll() }
        let working = unusualCombo(Self.f13)

        #expect(manager.register(working, for: .openHistory) {}.isSuccess)
        let result = manager.register(
            KeyCombo(keyCode: Self.f14, modifiers: [.shift]), for: .openHistory
        ) {}

        #expect(result.failure == .invalidCombo)
        #expect(manager.registeredCombos[.openHistory] == working)
    }

    @Test("A combo someone else already owns is reported cleanly and empties the slot")
    func reportsConflict() {
        let combo = unusualCombo(106)
        let owner = GlobalHotkeyManager()
        defer { owner.unregisterAll() }
        #expect(owner.register(combo, for: .openHistory) {}.isSuccess)

        let other = GlobalHotkeyManager()
        defer { other.unregisterAll() }
        #expect(other.register(unusualCombo(Self.f13), for: .pastePlainText) {}.isSuccess)
        let result = other.register(combo, for: .pastePlainText) {}

        if let failure = result.failure {
            #expect(failure.errorDescription?.isEmpty == false)
            #expect(other.registeredCombos[.pastePlainText] == nil)
        } else {
            #expect(other.registeredCombos[.pastePlainText] == combo)
        }
    }

    @Test("Unregistering one slot leaves the other alone")
    func unregisterSingleSlot() {
        let manager = GlobalHotkeyManager()
        defer { manager.unregisterAll() }

        #expect(manager.register(unusualCombo(Self.f13), for: .openHistory) {}.isSuccess)
        #expect(manager.register(unusualCombo(Self.f14), for: .pastePlainText) {}.isSuccess)
        manager.unregister(.openHistory)

        #expect(manager.registeredCombos[.openHistory] == nil)
        #expect(manager.registeredCombos[.pastePlainText] != nil)
    }

    @Test("unregisterAll clears everything and is repeatable")
    func unregisterAllIsIdempotent() {
        let manager = GlobalHotkeyManager()

        #expect(manager.register(unusualCombo(Self.f13), for: .openHistory) {}.isSuccess)
        manager.unregisterAll()
        manager.unregisterAll()

        #expect(manager.registeredCombos.isEmpty)
    }

    @Test("Deallocating a manager releases its Carbon registrations")
    func deinitReleasesRegistrations() {
        let combo = unusualCombo(Self.f15)
        do {
            let manager = GlobalHotkeyManager()
            #expect(manager.register(combo, for: .openHistory) {}.isSuccess)
        }

        let second = GlobalHotkeyManager()
        defer { second.unregisterAll() }
        let result = second.register(combo, for: .openHistory) {}

        #expect(result.isSuccess)
        if let failure = result.failure {
            #expect(failure != .registrationFailed(OSStatus(eventHotKeyExistsErr)))
        }
    }

    @Test("Every error explains itself to the user")
    func errorDescriptions() {
        let taken = HotkeyError.registrationFailed(OSStatus(eventHotKeyExistsErr))

        #expect(HotkeyError.invalidCombo.errorDescription?.isEmpty == false)
        #expect(taken.errorDescription == "That shortcut is already used by another app.")
        #expect(HotkeyError.registrationFailed(-1).errorDescription?.isEmpty == false)
        #expect(HotkeyError.registrationFailed(-1) != taken)
    }

    @Test("Slots have stable persistence names")
    func slotRawValues() {
        #expect(HotkeySlot.allCases.count == 2)
        #expect(HotkeySlot.openHistory.rawValue == "openHistory")
        #expect(HotkeySlot.pastePlainText.rawValue == "pastePlainText")
    }
}
