import Foundation

/// A global shortcut: one virtual key code plus modifier flags.
///
/// Stored in the Carbon-friendly form the hotkey API needs, with conversions to
/// and from the Cocoa flags that `NSEvent` reports.
public struct KeyCombo: Codable, Equatable, Hashable, Sendable {
    public struct Modifiers: OptionSet, Codable, Hashable, Sendable {
        public let rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }

        public static let control = Modifiers(rawValue: 1 << 0)
        public static let option = Modifiers(rawValue: 1 << 1)
        public static let shift = Modifiers(rawValue: 1 << 2)
        public static let command = Modifiers(rawValue: 1 << 3)
    }

    public let keyCode: UInt16
    public let modifiers: Modifiers

    public init(keyCode: UInt16, modifiers: Modifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    // MARK: - Defaults

    public static let openHistoryDefault = KeyCombo(
        keyCode: VirtualKey.v, modifiers: [.command, .shift]
    )
    public static let pastePlainTextDefault = KeyCombo(
        keyCode: VirtualKey.v, modifiers: [.command, .option]
    )

    // MARK: - Validity

    /// A usable global shortcut needs at least one non-shift modifier, otherwise
    /// it would swallow ordinary typing.
    public var isValid: Bool {
        !modifiers.intersection([.command, .control, .option]).isEmpty
    }

    // MARK: - Carbon bridging

    private enum CarbonMask {
        static let command: UInt32 = 0x0100
        static let shift: UInt32 = 0x0200
        static let option: UInt32 = 0x0800
        static let control: UInt32 = 0x1000
    }

    public var carbonModifiers: UInt32 {
        var value: UInt32 = 0
        if modifiers.contains(.command) { value |= CarbonMask.command }
        if modifiers.contains(.shift) { value |= CarbonMask.shift }
        if modifiers.contains(.option) { value |= CarbonMask.option }
        if modifiers.contains(.control) { value |= CarbonMask.control }
        return value
    }

    // MARK: - Cocoa bridging

    private enum CocoaMask {
        static let shift: UInt = 1 << 17
        static let control: UInt = 1 << 18
        static let option: UInt = 1 << 19
        static let command: UInt = 1 << 20
    }

    public var cocoaModifierFlags: UInt {
        var value: UInt = 0
        if modifiers.contains(.command) { value |= CocoaMask.command }
        if modifiers.contains(.shift) { value |= CocoaMask.shift }
        if modifiers.contains(.option) { value |= CocoaMask.option }
        if modifiers.contains(.control) { value |= CocoaMask.control }
        return value
    }

    /// Builds a combo from an `NSEvent`'s key code and raw modifier flags.
    public static func from(keyCode: UInt16, cocoaModifierFlags flags: UInt) -> KeyCombo {
        var modifiers: Modifiers = []
        if flags & CocoaMask.command != 0 { modifiers.insert(.command) }
        if flags & CocoaMask.shift != 0 { modifiers.insert(.shift) }
        if flags & CocoaMask.option != 0 { modifiers.insert(.option) }
        if flags & CocoaMask.control != 0 { modifiers.insert(.control) }
        return KeyCombo(keyCode: keyCode, modifiers: modifiers)
    }

    // MARK: - Display

    /// Menu-style rendering, e.g. `⇧⌘V`. Modifier order matches Apple's.
    public var displayString: String {
        var result = ""
        if modifiers.contains(.control) { result += "⌃" }
        if modifiers.contains(.option) { result += "⌥" }
        if modifiers.contains(.shift) { result += "⇧" }
        if modifiers.contains(.command) { result += "⌘" }
        result += VirtualKey.name(for: keyCode)
        return result
    }

    /// The key character alone, for `NSMenuItem.keyEquivalent`.
    public var menuKeyEquivalent: String {
        VirtualKey.menuEquivalent(for: keyCode)
    }
}

/// Virtual key codes and their display names, without pulling in Carbon.
public enum VirtualKey {
    public static let a: UInt16 = 0
    public static let c: UInt16 = 8
    public static let v: UInt16 = 9
    public static let space: UInt16 = 49
    public static let escape: UInt16 = 53
    public static let returnKey: UInt16 = 36
    public static let tab: UInt16 = 48
    public static let delete: UInt16 = 51
    public static let arrowLeft: UInt16 = 123
    public static let arrowRight: UInt16 = 124
    public static let arrowDown: UInt16 = 125
    public static let arrowUp: UInt16 = 126

    private static let names: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2",
        20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8",
        29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "↩", 37: "L",
        38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M",
        47: ".", 48: "⇥", 49: "Space", 50: "`", 51: "⌫", 53: "⎋",
        65: "Keypad .", 67: "Keypad *", 69: "Keypad +", 71: "Clear", 75: "Keypad /",
        76: "Keypad ↩", 78: "Keypad -", 81: "Keypad =", 82: "Keypad 0", 83: "Keypad 1",
        84: "Keypad 2", 85: "Keypad 3", 86: "Keypad 4", 87: "Keypad 5", 88: "Keypad 6",
        89: "Keypad 7", 91: "Keypad 8", 92: "Keypad 9",
        96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11",
        105: "F13", 107: "F14", 109: "F10", 111: "F12", 113: "F15", 114: "Help",
        115: "Home", 116: "Page Up", 117: "⌦", 118: "F4", 119: "End", 120: "F2",
        121: "Page Down", 122: "F1", 123: "←", 124: "→", 125: "↓", 126: "↑",
    ]

    public static func name(for keyCode: UInt16) -> String {
        names[keyCode] ?? "Key \(keyCode)"
    }

    /// Lowercased single character suitable for a menu key equivalent, or empty
    /// when the key has no printable equivalent.
    public static func menuEquivalent(for keyCode: UInt16) -> String {
        let name = name(for: keyCode)
        guard name.count == 1, let scalar = name.unicodeScalars.first, scalar.isASCII else {
            return ""
        }
        return name.lowercased()
    }
}
