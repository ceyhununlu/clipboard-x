import Foundation

/// Substring search over history rows, ranked so the most obvious matches lead.
public enum HistoryFilter {
    private enum Rank: Int {
        case prefix = 0
        case wordPrefix = 1
        case substring = 2
    }

    /// Returns the items matching `query`, best matches first, recency breaking
    /// ties. An empty or whitespace-only query returns everything unchanged.
    public static func apply(_ query: String, to items: [ClipboardItem]) -> [ClipboardItem] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return items }

        let ranked: [(item: ClipboardItem, rank: Rank, position: Int)] = items.enumerated()
            .compactMap { position, item in
                guard let rank = rank(of: needle, in: item.searchText) else { return nil }
                return (item, rank, position)
            }

        return ranked
            .sorted { left, right in
                if left.rank != right.rank { return left.rank.rawValue < right.rank.rawValue }
                return left.position < right.position
            }
            .map(\.item)
    }

    private static func rank(of needle: String, in haystack: String) -> Rank? {
        guard let range = haystack.range(of: needle) else { return nil }
        if range.lowerBound == haystack.startIndex { return .prefix }
        let before = haystack[haystack.index(before: range.lowerBound)]
        if before == " " || before.isPunctuation || before.isSymbol { return .wordPrefix }
        return .substring
    }
}
