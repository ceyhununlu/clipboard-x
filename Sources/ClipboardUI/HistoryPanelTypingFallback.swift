import ClipboardCore
import Foundation

/// Applies search typing to the model when the search field is not yet first
/// responder (focus lands a beat after the panel opens).
///
/// Once the field is focused, events must pass through so the system caret,
/// selection, and IME behave normally.
enum HistoryPanelTypingFallback {
    /// - Returns: `true` when the event was applied to the query and should be
    ///   consumed by the panel key monitor.
    static func apply(
        keyCode: UInt16,
        characters: String?,
        command: Bool,
        control: Bool,
        option: Bool,
        searchFieldFocused: Bool,
        append: (String) -> Void,
        deleteBackward: () -> Void
    ) -> Bool {
        guard !searchFieldFocused else { return false }
        guard !command, !control, !option else { return false }

        if keyCode == VirtualKey.delete {
            deleteBackward()
            return true
        }

        guard let characters, !characters.isEmpty else { return false }
        guard characters.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else {
            return false
        }
        append(characters)
        return true
    }
}
