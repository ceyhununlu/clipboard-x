import ClipboardCore
import Foundation
import Testing

@testable import ClipboardUI

@MainActor
private func makeModel(_ texts: [String], maxItems: Int = 25) -> (HistoryPanelModel, HistoryStore) {
    let store = HistoryStore(
        index: InMemoryHistoryIndexStore(),
        blobs: InMemoryBlobStore(),
        maxItems: maxItems
    )
    // Inserted oldest-first so the resulting order is the reverse of `texts`.
    for text in texts {
        store.insert(.text(text))
    }
    return (HistoryPanelModel(store: store), store)
}

@Suite("History panel selection")
@MainActor
struct HistoryPanelSelectionTests {
    @Test("opens with the most recent item selected")
    func initialSelection() {
        let (model, _) = makeModel(["oldest", "newest"])
        #expect(model.visibleItems.map(\.previewText) == ["newest", "oldest"])
        #expect(model.selectedIndex == 0)
        #expect(model.selectedItem?.previewText == "newest")
    }

    @Test("arrow movement stops at both ends instead of wrapping")
    func clampedMovement() {
        let (model, _) = makeModel(["a", "b", "c"])
        model.moveSelection(by: -1)
        #expect(model.selectedIndex == 0)
        model.moveSelection(by: 1)
        #expect(model.selectedIndex == 1)
        model.moveSelection(by: 10)
        #expect(model.selectedIndex == 2)
        model.moveSelection(by: -10)
        #expect(model.selectedIndex == 0)
    }

    @Test("first and last jump to the ends")
    func endJumps() {
        let (model, _) = makeModel(["a", "b", "c"])
        model.selectLast()
        #expect(model.selectedIndex == 2)
        model.selectFirst()
        #expect(model.selectedIndex == 0)
    }

    @Test("selecting an out-of-range row is ignored")
    func invalidSelection() {
        let (model, _) = makeModel(["a", "b"])
        model.select(index: 1)
        model.select(index: 9)
        #expect(model.selectedIndex == 1)
        model.select(index: -1)
        #expect(model.selectedIndex == 1)
    }

    @Test("an empty history has no selected item and ignores movement")
    func emptyHistory() {
        let (model, _) = makeModel([])
        #expect(model.isEmpty)
        #expect(model.selectedItem == nil)
        model.moveSelection(by: 1)
        #expect(model.selectedIndex == 0)
    }
}

@Suite("History panel search")
@MainActor
struct HistoryPanelSearchTests {
    @Test("typing narrows the list and re-selects the top match")
    func filtering() {
        let (model, _) = makeModel(["alpha", "beta", "gamma"])
        model.selectLast()
        model.query = "bet"
        #expect(model.visibleItems.map(\.previewText) == ["beta"])
        #expect(model.selectedIndex == 0)
        #expect(model.isFiltering)
        #expect(model.totalCount == 3)
    }

    @Test("search is case-insensitive")
    func caseInsensitive() {
        let (model, _) = makeModel(["Hello World"])
        model.query = "WORLD"
        #expect(model.visibleItems.count == 1)
    }

    @Test("a query matching nothing empties the list")
    func noMatches() {
        let (model, _) = makeModel(["alpha", "beta"])
        model.query = "zzz"
        #expect(model.isEmpty)
        #expect(model.selectedItem == nil)
    }

    @Test("typed characters accumulate and backspace removes them")
    func queryEditing() {
        let (model, _) = makeModel(["alpha"])
        model.appendToQuery("a")
        model.appendToQuery("l")
        #expect(model.query == "al")
        model.deleteBackwardInQuery()
        #expect(model.query == "a")
        model.deleteBackwardInQuery()
        model.deleteBackwardInQuery()
        #expect(model.query.isEmpty)
        #expect(!model.isFiltering)
    }

    @Test("whitespace alone does not count as filtering")
    func whitespaceQuery() {
        let (model, _) = makeModel(["alpha", "beta"])
        model.query = "   "
        #expect(!model.isFiltering)
        #expect(model.visibleItems.count == 2)
    }

    @Test("reopening the popup clears the previous search")
    func resetClearsQuery() {
        let (model, _) = makeModel(["alpha", "beta"])
        model.query = "alp"
        model.reset()
        #expect(model.query.isEmpty)
        #expect(model.visibleItems.count == 2)
        #expect(model.selectedIndex == 0)
    }
}

@Suite("History panel shortcuts")
@MainActor
struct HistoryPanelShortcutTests {
    @Test("command-number maps to the matching row")
    func numericShortcuts() {
        let (model, _) = makeModel(["c", "b", "a"])
        #expect(model.item(forNumericShortcut: 1)?.previewText == "a")
        #expect(model.item(forNumericShortcut: 3)?.previewText == "c")
    }

    @Test("command-number beyond the visible rows does nothing")
    func numericShortcutsOutOfRange() {
        let (model, _) = makeModel(["a", "b"])
        #expect(model.item(forNumericShortcut: 3) == nil)
        #expect(model.item(forNumericShortcut: 0) == nil)
        #expect(model.item(forNumericShortcut: 10) == nil)
    }

    @Test("only the first nine rows advertise a shortcut")
    func shortcutLabels() {
        let (model, _) = makeModel([])
        #expect(model.numericShortcutLabel(for: 0) == "⌘1")
        #expect(model.numericShortcutLabel(for: 8) == "⌘9")
        #expect(model.numericShortcutLabel(for: 9) == nil)
    }

    @Test("numeric shortcuts follow the filtered order")
    func numericShortcutsRespectFilter() {
        let (model, _) = makeModel(["apple", "banana", "avocado"])
        model.query = "an"
        #expect(model.visibleItems.map(\.previewText) == ["banana"])
        #expect(model.item(forNumericShortcut: 1)?.previewText == "banana")
        #expect(model.item(forNumericShortcut: 2) == nil)
    }
}

@Suite("History panel item actions")
@MainActor
struct HistoryPanelActionTests {
    @Test("pinning the selection updates the store")
    func pinning() {
        let (model, store) = makeModel(["a", "b"])
        model.togglePinOnSelection()
        #expect(store.items.first?.isPinned == true)
        #expect(store.pinnedCount == 1)
        model.togglePinOnSelection()
        #expect(store.pinnedCount == 0)
    }

    @Test("deleting the selection removes it and keeps a valid selection")
    func deleting() {
        let (model, store) = makeModel(["a", "b", "c"])
        model.deleteSelection()
        #expect(store.items.count == 2)
        #expect(model.visibleItems.count == 2)
        #expect(model.selectedItem?.previewText == "b")
    }

    @Test("deleting the last row moves the selection up")
    func deletingLastRow() {
        let (model, _) = makeModel(["a", "b"])
        model.selectLast()
        model.deleteSelection()
        #expect(model.visibleItems.count == 1)
        #expect(model.selectedIndex == 0)
        #expect(model.selectedItem?.previewText == "b")
    }

    @Test("deleting the only row leaves an empty list")
    func deletingOnlyRow() {
        let (model, _) = makeModel(["a"])
        model.deleteSelection()
        #expect(model.isEmpty)
        #expect(model.selectedItem == nil)
        model.deleteSelection()
        #expect(model.isEmpty)
    }

    @Test("content round-trips through the store")
    func contentLookup() throws {
        let (model, _) = makeModel(["hello"])
        let item = try #require(model.selectedItem)
        #expect(model.content(for: item) == .text("hello"))
    }

    @Test("a new copy appears in the list without losing the selection")
    func reactsToStoreChanges() async throws {
        let (model, store) = makeModel(["a", "b"])
        model.selectLast()
        store.insert(.text("c"))

        try await waitUntil { model.visibleItems.count == 3 }
        #expect(model.visibleItems.first?.previewText == "c")
        #expect(model.selectedIndex == 2)
    }
}

@Suite("Panel sizing")
struct PanelSizingTests {
    @Test("an empty list still gets a readable panel")
    func emptyHeight() {
        let height = HistoryListView.height(forRowCount: 0)
        #expect(height == HistoryListView.headerHeight + 92 + HistoryListView.footerHeight)
    }

    @Test("height grows with the row count")
    func growth() {
        let one = HistoryListView.height(forRowCount: 1)
        let three = HistoryListView.height(forRowCount: 3)
        #expect(three - one == HistoryListView.rowHeight * 2)
    }

    @Test("height stops growing past the scroll limit")
    func cap() {
        let atLimit = HistoryListView.height(forRowCount: HistoryPanelModel.maxVisibleRows)
        #expect(HistoryListView.height(forRowCount: 200) == atLimit)
    }
}

/// Polls a main-actor condition, giving Combine and `Task` hops a chance to run.
@MainActor
private func waitUntil(
    timeout: Duration = .seconds(2),
    _ condition: () -> Bool
) async throws {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    while ContinuousClock.now < deadline {
        if condition() { return }
        try await Task.sleep(for: .milliseconds(10))
    }
    Issue.record("Condition was not met before the timeout")
}
