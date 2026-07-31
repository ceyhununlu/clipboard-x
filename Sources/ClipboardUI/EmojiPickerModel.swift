import ClipboardCore
import Combine
import Foundation

/// Selection and filtering state for the emoji tab.
@MainActor
final class EmojiPickerModel: ObservableObject {
    nonisolated static let columns = 8

    @Published var query = "" {
        didSet {
            guard query != oldValue else { return }
            refresh(resettingSelection: true)
        }
    }

    @Published var selectedCategoryID: String? {
        didSet {
            guard selectedCategoryID != oldValue else { return }
            refresh(resettingSelection: true)
        }
    }

    @Published private(set) var visibleEmoji: [String] = []
    @Published private(set) var selectedIndex = 0
    @Published private(set) var searchFocusNonce: UInt = 0

    var categories: [EmojiCategory] { EmojiCatalog.categories }

    var selectedCategory: EmojiCategory? {
        guard let selectedCategoryID else { return nil }
        return categories.first { $0.id == selectedCategoryID }
    }

    var selectedEmoji: String? {
        guard visibleEmoji.indices.contains(selectedIndex) else { return nil }
        return visibleEmoji[selectedIndex]
    }

    var isFiltering: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    init() {
        // Assign through the storage path without double-refreshing.
        selectedCategoryID = EmojiCatalog.categories.first?.id
        refresh(resettingSelection: true)
    }

    func reset() {
        query = ""
        selectedCategoryID = categories.first?.id
        searchFocusNonce &+= 1
        refresh(resettingSelection: true)
    }

    func focusSearch() {
        searchFocusNonce &+= 1
    }

    func clearQuery() {
        query = ""
    }

    func appendToQuery(_ text: String) {
        query += text
    }

    func deleteBackwardInQuery() {
        guard !query.isEmpty else { return }
        query.removeLast()
    }

    func moveSelection(by delta: Int) {
        guard !visibleEmoji.isEmpty else { return }
        selectedIndex = clamp(selectedIndex + delta)
    }

    func moveSelection(rows rowDelta: Int, columns columnDelta: Int) {
        guard !visibleEmoji.isEmpty else { return }
        let columns = Self.columns
        let row = selectedIndex / columns
        let col = selectedIndex % columns
        let nextRow = max(0, row + rowDelta)
        let nextCol = min(columns - 1, max(0, col + columnDelta))
        let candidate = nextRow * columns + nextCol
        selectedIndex = clamp(candidate)
    }

    func select(index: Int) {
        selectedIndex = clamp(index)
    }

    private func refresh(resettingSelection: Bool) {
        // Typing a query searches the whole catalog; clearing restores the chip.
        let scope = isFiltering ? nil : selectedCategory
        visibleEmoji = EmojiCatalog.search(query, in: scope)
        selectedIndex = resettingSelection ? 0 : clamp(selectedIndex)
    }

    private func clamp(_ index: Int) -> Int {
        guard !visibleEmoji.isEmpty else { return 0 }
        return min(max(index, 0), visibleEmoji.count - 1)
    }
}
