import Foundation
import Testing
@testable import ClipboardCore

@Suite("HistoryFilter")
struct HistoryFilterTests {

    @Test("empty query returns the input unchanged and in order")
    func emptyQueryReturnsAll() {
        let items = [
            makeFilterItem(searchText: "apple"),
            makeFilterItem(searchText: "banana"),
            makeFilterItem(searchText: "cherry"),
        ]
        let result = HistoryFilter.apply("", to: items)
        #expect(result.map(\.searchText) == items.map(\.searchText))
    }

    @Test("whitespace-only query returns the input unchanged and in order")
    func whitespaceQueryReturnsAll() {
        let items = [
            makeFilterItem(searchText: "one"),
            makeFilterItem(searchText: "two"),
        ]
        let result = HistoryFilter.apply("   \t\n", to: items)
        #expect(result.map(\.searchText) == items.map(\.searchText))
    }

    @Test("matching is case-insensitive")
    func caseInsensitiveMatching() {
        let items = [
            makeFilterItem(searchText: "hello world"),
        ]
        let result = HistoryFilter.apply("HELLO", to: items)
        #expect(result.count == 1)
    }

    @Test("prefix rank outranks word-prefix rank which outranks substring rank")
    func rankingOrder() {
        let prefixItem = makeFilterItem(
            searchText: "hello world",
            createdAt: Date(timeIntervalSince1970: 3)
        )
        let wordPrefixItem = makeFilterItem(
            searchText: "say hello world",
            createdAt: Date(timeIntervalSince1970: 2)
        )
        let substringItem = makeFilterItem(
            searchText: "wherehelp",
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let items = [substringItem, wordPrefixItem, prefixItem]
        let result = HistoryFilter.apply("hel", to: items)
        #expect(result.count == 3)
        #expect(result[0].searchText == "hello world")
        #expect(result[1].searchText == "say hello world")
        #expect(result[2].searchText == "wherehelp")
    }

    @Test("within the same rank the more recent item (earlier array position) wins")
    func recencyBreaksTiesWithinSameRank() {
        let recent = makeFilterItem(searchText: "hello recent", createdAt: Date(timeIntervalSince1970: 2))
        let older = makeFilterItem(searchText: "hello older", createdAt: Date(timeIntervalSince1970: 1))
        let items = [recent, older]
        let result = HistoryFilter.apply("hello", to: items)
        #expect(result[0].searchText == "hello recent")
        #expect(result[1].searchText == "hello older")
    }

    @Test("non-matching items are excluded from results")
    func nonMatchingExcluded() {
        let items = [
            makeFilterItem(searchText: "apple"),
            makeFilterItem(searchText: "banana"),
            makeFilterItem(searchText: "cherry"),
        ]
        let result = HistoryFilter.apply("ban", to: items)
        #expect(result.count == 1)
        #expect(result[0].searchText == "banana")
    }

    @Test("a query matching nothing returns an empty array")
    func noMatchReturnsEmpty() {
        let items = [
            makeFilterItem(searchText: "apple"),
            makeFilterItem(searchText: "banana"),
        ]
        let result = HistoryFilter.apply("xyz123", to: items)
        #expect(result.isEmpty)
    }

    @Test("filter matches text beyond the 400-character preview cap but within the 4000-character search cap")
    func matchesBeyondPreviewCapWithinSearchCap() {
        let padding = String(repeating: "a", count: 410)
        let uniqueWord = "uniquetoken"
        let fullText = padding + uniqueWord
        let searchText = ClipboardPreview.searchText(from: fullText)
        #expect(searchText.count > 400)
        let item = makeFilterItem(searchText: searchText, previewText: "aaa…")
        let result = HistoryFilter.apply(uniqueWord, to: [item])
        #expect(result.count == 1)
    }
}
