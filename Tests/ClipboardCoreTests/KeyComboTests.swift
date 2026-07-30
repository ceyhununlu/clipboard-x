import AppKit
import Foundation
import Testing
@testable import ClipboardCore

@Suite("KeyCombo")
struct KeyComboTests {

    // MARK: - displayString

    @Test("displayString for shift+command+V is ⇧⌘V")
    func displayStringShiftCommandV() {
        let combo = KeyCombo(keyCode: VirtualKey.v, modifiers: [.command, .shift])
        #expect(combo.displayString == "⇧⌘V")
    }

    @Test("displayString for option+command+V is ⌥⌘V")
    func displayStringOptionCommandV() {
        let combo = KeyCombo(keyCode: VirtualKey.v, modifiers: [.command, .option])
        #expect(combo.displayString == "⌥⌘V")
    }

    @Test("displayString renders modifiers in order ⌃⌥⇧⌘ for control+option+shift+command")
    func displayStringModifierOrder() {
        let combo = KeyCombo(keyCode: 105, modifiers: [.control, .option, .shift, .command])
        #expect(combo.displayString == "⌃⌥⇧⌘F13")
    }

    @Test("arrow keys render as ←, →, ↑, ↓")
    func arrowKeysRender() {
        #expect(VirtualKey.name(for: VirtualKey.arrowLeft) == "←")
        #expect(VirtualKey.name(for: VirtualKey.arrowRight) == "→")
        #expect(VirtualKey.name(for: VirtualKey.arrowUp) == "↑")
        #expect(VirtualKey.name(for: VirtualKey.arrowDown) == "↓")
    }

    @Test("returnKey renders as ↩")
    func returnKeyRenders() {
        #expect(VirtualKey.name(for: VirtualKey.returnKey) == "↩")
    }

    @Test("escape renders as ⎋")
    func escapeRenders() {
        #expect(VirtualKey.name(for: VirtualKey.escape) == "⎋")
    }

    @Test("space renders as Space")
    func spaceRenders() {
        #expect(VirtualKey.name(for: VirtualKey.space) == "Space")
    }

    // MARK: - isValid

    @Test("isValid is false when no modifiers are set")
    func isValidFalseForNoModifiers() {
        let combo = KeyCombo(keyCode: VirtualKey.v, modifiers: [])
        #expect(!combo.isValid)
    }

    @Test("isValid is false when only shift is set")
    func isValidFalseForShiftOnly() {
        let combo = KeyCombo(keyCode: VirtualKey.a, modifiers: [.shift])
        #expect(!combo.isValid)
    }

    @Test("isValid is true when command is present")
    func isValidTrueWithCommand() {
        #expect(KeyCombo(keyCode: VirtualKey.v, modifiers: [.command]).isValid)
    }

    @Test("isValid is true when control is present")
    func isValidTrueWithControl() {
        #expect(KeyCombo(keyCode: VirtualKey.v, modifiers: [.control]).isValid)
    }

    @Test("isValid is true when option is present")
    func isValidTrueWithOption() {
        #expect(KeyCombo(keyCode: VirtualKey.v, modifiers: [.option]).isValid)
    }

    // MARK: - Carbon modifiers

    @Test("carbonModifiers command bit is 0x100")
    func carbonModifiersCommand() {
        let combo = KeyCombo(keyCode: VirtualKey.v, modifiers: [.command])
        #expect(combo.carbonModifiers == 0x0100)
    }

    @Test("carbonModifiers shift bit is 0x200")
    func carbonModifiersShift() {
        let combo = KeyCombo(keyCode: VirtualKey.v, modifiers: [.shift])
        #expect(combo.carbonModifiers == 0x0200)
    }

    @Test("carbonModifiers option bit is 0x800")
    func carbonModifiersOption() {
        let combo = KeyCombo(keyCode: VirtualKey.v, modifiers: [.option])
        #expect(combo.carbonModifiers == 0x0800)
    }

    @Test("carbonModifiers control bit is 0x1000")
    func carbonModifiersControl() {
        let combo = KeyCombo(keyCode: VirtualKey.v, modifiers: [.control])
        #expect(combo.carbonModifiers == 0x1000)
    }

    @Test("carbonModifiers combines bits with OR for multiple modifiers")
    func carbonModifiersCombined() {
        let combo = KeyCombo(keyCode: VirtualKey.v, modifiers: [.command, .shift, .option, .control])
        #expect(combo.carbonModifiers == 0x0100 | 0x0200 | 0x0800 | 0x1000)
    }

    // MARK: - Cocoa modifier flags

    @Test("cocoaModifierFlags command matches NSEvent.ModifierFlags.command.rawValue")
    func cocoaFlagsCommand() {
        let combo = KeyCombo(keyCode: VirtualKey.v, modifiers: [.command])
        #expect(combo.cocoaModifierFlags == NSEvent.ModifierFlags.command.rawValue)
    }

    @Test("cocoaModifierFlags shift matches NSEvent.ModifierFlags.shift.rawValue")
    func cocoaFlagsShift() {
        let combo = KeyCombo(keyCode: VirtualKey.v, modifiers: [.shift])
        #expect(combo.cocoaModifierFlags == NSEvent.ModifierFlags.shift.rawValue)
    }

    @Test("cocoaModifierFlags option matches NSEvent.ModifierFlags.option.rawValue")
    func cocoaFlagsOption() {
        let combo = KeyCombo(keyCode: VirtualKey.v, modifiers: [.option])
        #expect(combo.cocoaModifierFlags == NSEvent.ModifierFlags.option.rawValue)
    }

    @Test("cocoaModifierFlags control matches NSEvent.ModifierFlags.control.rawValue")
    func cocoaFlagsControl() {
        let combo = KeyCombo(keyCode: VirtualKey.v, modifiers: [.control])
        #expect(combo.cocoaModifierFlags == NSEvent.ModifierFlags.control.rawValue)
    }

    // MARK: - from(keyCode:cocoaModifierFlags:)

    @Test("from(keyCode:cocoaModifierFlags:) round-trips a combo")
    func fromCocoaFlagsRoundTrips() {
        let original = KeyCombo(keyCode: VirtualKey.v, modifiers: [.command, .shift])
        let roundTripped = KeyCombo.from(keyCode: original.keyCode, cocoaModifierFlags: original.cocoaModifierFlags)
        #expect(roundTripped == original)
    }

    @Test("from(keyCode:cocoaModifierFlags:) ignores caps lock and function flags")
    func fromCocoaFlagsIgnoresIrrelevantFlags() {
        let capsLock: UInt = 1 << 16
        let function: UInt = 1 << 23
        let commandFlag = NSEvent.ModifierFlags.command.rawValue
        let combo = KeyCombo.from(
            keyCode: VirtualKey.v,
            cocoaModifierFlags: commandFlag | capsLock | function
        )
        #expect(combo.modifiers == [.command])
    }

    // MARK: - Codable

    @Test("KeyCombo survives a JSONEncoder / JSONDecoder round-trip")
    func codableRoundTrip() throws {
        let original = KeyCombo(keyCode: VirtualKey.v, modifiers: [.command, .shift, .option])
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(KeyCombo.self, from: data)
        #expect(decoded == original)
    }

    // MARK: - menuKeyEquivalent

    @Test("menuKeyEquivalent is lowercase 'v' for the V key")
    func menuKeyEquivalentV() {
        let combo = KeyCombo(keyCode: VirtualKey.v, modifiers: [.command])
        #expect(combo.menuKeyEquivalent == "v")
    }

    @Test("menuKeyEquivalent is empty for non-printable keys like return, arrows, F13")
    func menuKeyEquivalentNonPrintable() {
        #expect(KeyCombo(keyCode: VirtualKey.returnKey, modifiers: [.command]).menuKeyEquivalent == "")
        #expect(KeyCombo(keyCode: VirtualKey.arrowLeft, modifiers: [.command]).menuKeyEquivalent == "")
        #expect(KeyCombo(keyCode: 105, modifiers: [.command]).menuKeyEquivalent == "")
    }

    // MARK: - VirtualKey coverage

    @Test("VirtualKey.name returns a non-empty label for every key code 0 through 126")
    func virtualKeyNameCoversAll() {
        for code in UInt16(0)...UInt16(126) {
            let name = VirtualKey.name(for: code)
            #expect(!name.isEmpty, "keyCode \(code) returned empty string")
        }
    }
}
