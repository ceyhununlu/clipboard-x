import ClipboardCore
import Combine
import Foundation

/// Selection and filtering state for the history popup.
///
/// Holds no AppKit references so the navigation rules can be tested directly.
@MainActor
final class HistoryPanelModel: ObservableObject {
    /// The most rows the popup shows before it starts scrolling.
    nonisolated static let maxVisibleRows = 8
    /// How many rows carry a ⌘1…⌘9 shortcut.
    nonisolated static let numericShortcutCount = 9

    @Published var query = "" {
        didSet {
            guard query != oldValue else { return }
            refresh(resettingSelection: true)
        }
    }

    /// Bumped when the popup opens so the search field can reclaim focus.
    @Published private(set) var searchFocusNonce = 0

    @Published private(set) var visibleItems: [ClipboardItem] = []
    @Published private(set) var selectedIndex = 0

    private let store: HistoryStore
    private var cancellable: AnyCancellable?

    init(store: HistoryStore) {
        self.store = store
        refresh(resettingSelection: true)
        cancellable = store.$items
            .dropFirst()
            .sink { [weak self] _ in
                // The published value lands after this callback, so re-read on
                // the next turn of the run loop.
                Task { @MainActor in self?.refresh(resettingSelection: false) }
            }
    }

    var isEmpty: Bool { visibleItems.isEmpty }

    var selectedItem: ClipboardItem? {
        guard visibleItems.indices.contains(selectedIndex) else { return nil }
        return visibleItems[selectedIndex]
    }

    var totalCount: Int { store.items.count }

    var isFiltering: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func refresh(resettingSelection: Bool) {
        // Following the selected item rather than its row number keeps the
        // highlight put when a new copy arrives while the popup is open.
        let previousSelectionID = resettingSelection ? nil : selectedItem?.id
        visibleItems = HistoryFilter.apply(query, to: store.items)
        if let previousSelectionID,
           let index = visibleItems.firstIndex(where: { $0.id == previousSelectionID }) {
            selectedIndex = index
        } else {
            selectedIndex = resettingSelection ? 0 : clamp(selectedIndex)
        }
    }

    /// Called when the popup opens: clears any previous search and highlights the
    /// most recent item.
    func reset() {
        query = ""
        searchFocusNonce &+= 1
        refresh(resettingSelection: true)
    }

    // MARK: - Navigation

    func moveSelection(by delta: Int) {
        guard !visibleItems.isEmpty else { return }
        selectedIndex = clamp(selectedIndex + delta)
    }

    func selectFirst() {
        selectedIndex = 0
    }

    func selectLast() {
        selectedIndex = max(0, visibleItems.count - 1)
    }

    func select(index: Int) {
        guard visibleItems.indices.contains(index) else { return }
        selectedIndex = index
    }

    /// Maps ⌘1…⌘9 to a row, or `nil` when that row does not exist.
    func item(forNumericShortcut number: Int) -> ClipboardItem? {
        guard (1...Self.numericShortcutCount).contains(number) else { return nil }
        let index = number - 1
        guard visibleItems.indices.contains(index) else { return nil }
        return visibleItems[index]
    }

    /// The ⌘N label for a row, or `nil` beyond the ninth row.
    func numericShortcutLabel(for index: Int) -> String? {
        guard index < Self.numericShortcutCount else { return nil }
        return "⌘\(index + 1)"
    }

    // MARK: - Search editing

    func appendToQuery(_ text: String) {
        query.append(contentsOf: text)
    }

    func deleteBackwardInQuery() {
        guard !query.isEmpty else { return }
        query.removeLast()
    }

    func clearQuery() {
        query = ""
    }

    // MARK: - Item actions

    func togglePinOnSelection() {
        guard let selected = selectedItem else { return }
        store.togglePin(selected.id)
        refresh(resettingSelection: false)
    }

    func deleteSelection() {
        guard let selected = selectedItem else { return }
        let previousIndex = selectedIndex
        store.delete(selected.id)
        refresh(resettingSelection: false)
        selectedIndex = clamp(previousIndex)
    }

    func content(for item: ClipboardItem) -> ClipboardContent? {
        do {
            return try store.content(for: item)
        } catch {
            AppLog.panel.error("Could not read item payload: \(String(describing: error))")
            return nil
        }
    }

    func imageData(for item: ClipboardItem) -> Data? {
        store.imageData(for: item)
    }

    private func clamp(_ index: Int) -> Int {
        guard !visibleItems.isEmpty else { return 0 }
        return min(max(index, 0), visibleItems.count - 1)
    }
}
