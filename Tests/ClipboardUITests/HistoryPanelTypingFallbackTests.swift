import ClipboardCore
import Foundation
import Testing

@testable import ClipboardUI

@Suite("History panel typing fallback")
struct HistoryPanelTypingFallbackTests {

    @Test("when the search field is unfocused, printable characters append to the query")
    func unfocusedTypingAppends() {
        var query = ""
        let consumed = HistoryPanelTypingFallback.apply(
            keyCode: VirtualKey.a,
            characters: "a",
            command: false,
            control: false,
            option: false,
            searchFieldFocused: false,
            append: { query.append(contentsOf: $0) },
            deleteBackward: {}
        )
        #expect(consumed)
        #expect(query == "a")
    }

    @Test("when the search field is focused, typing is left for the TextField")
    func focusedTypingPassesThrough() {
        var query = ""
        let consumed = HistoryPanelTypingFallback.apply(
            keyCode: VirtualKey.a,
            characters: "a",
            command: false,
            control: false,
            option: false,
            searchFieldFocused: true,
            append: { query.append(contentsOf: $0) },
            deleteBackward: {}
        )
        #expect(!consumed)
        #expect(query.isEmpty)
    }

    @Test("unfocused backspace deletes from the query so early keystrokes are not lost")
    func unfocusedBackspaceDeletes() {
        var query = "ab"
        let consumed = HistoryPanelTypingFallback.apply(
            keyCode: VirtualKey.delete,
            characters: "\u{8}",
            command: false,
            control: false,
            option: false,
            searchFieldFocused: false,
            append: { query.append(contentsOf: $0) },
            deleteBackward: {
                if !query.isEmpty { query.removeLast() }
            }
        )
        #expect(consumed)
        #expect(query == "a")
    }

    @Test("focused backspace is left for the TextField")
    func focusedBackspacePassesThrough() {
        var deleted = false
        let consumed = HistoryPanelTypingFallback.apply(
            keyCode: VirtualKey.delete,
            characters: "\u{8}",
            command: false,
            control: false,
            option: false,
            searchFieldFocused: true,
            append: { _ in },
            deleteBackward: { deleted = true }
        )
        #expect(!consumed)
        #expect(!deleted)
    }

    @Test("modifier chords are never treated as search fallback typing")
    func modifierChordsPassThrough() {
        var query = ""
        let consumed = HistoryPanelTypingFallback.apply(
            keyCode: VirtualKey.a,
            characters: "a",
            command: true,
            control: false,
            option: false,
            searchFieldFocused: false,
            append: { query.append(contentsOf: $0) },
            deleteBackward: {}
        )
        #expect(!consumed)
        #expect(query.isEmpty)
    }

    @Test("control characters are ignored")
    func controlCharactersIgnored() {
        var query = ""
        let consumed = HistoryPanelTypingFallback.apply(
            keyCode: 0,
            characters: "\n",
            command: false,
            control: false,
            option: false,
            searchFieldFocused: false,
            append: { query.append(contentsOf: $0) },
            deleteBackward: {}
        )
        #expect(!consumed)
        #expect(query.isEmpty)
    }

    @Test("multi-character input appends in full while unfocused")
    func multiCharacterAppend() {
        var query = ""
        let consumed = HistoryPanelTypingFallback.apply(
            keyCode: 0,
            characters: "ö",
            command: false,
            control: false,
            option: false,
            searchFieldFocused: false,
            append: { query.append(contentsOf: $0) },
            deleteBackward: {}
        )
        #expect(consumed)
        #expect(query == "ö")
    }
}
