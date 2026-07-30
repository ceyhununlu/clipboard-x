import AppKit
import ClipboardCore
import SwiftUI

/// The contents of the history popup.
///
/// Keyboard handling lives in `HistoryPanelController`: the panel owns a key
/// monitor rather than a focused text field, so every keystroke has one
/// unambiguous destination.
struct HistoryListView: View {
    @ObservedObject var model: HistoryPanelModel
    let onChoose: (ClipboardItem, Bool) -> Void

    static let width: CGFloat = 420
    static let rowHeight: CGFloat = 54
    static let headerHeight: CGFloat = 36
    static let footerHeight: CGFloat = 26

    /// Height the panel needs for the current row count, capped at the scroll limit.
    static func height(forRowCount count: Int) -> CGFloat {
        let rows = max(1, min(count, HistoryPanelModel.maxVisibleRows))
        let body = count == 0 ? 92 : CGFloat(rows) * rowHeight
        return headerHeight + body + footerHeight
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            separator
            if model.isEmpty {
                emptyState
            } else {
                rows
            }
            separator
            footer
        }
        .frame(width: Self.width)
        .background(Color.clear)
        .clipShape(panelShape)
    }

    private var panelShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: RoundedPanelChromeView.cornerRadius, style: .continuous)
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.10))
            .frame(height: 1)
            .padding(.horizontal, RoundedPanelChromeView.cornerRadius)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 11, weight: .semibold))
            if model.query.isEmpty {
                Text("Type to search")
                    .foregroundStyle(.tertiary)
            } else {
                Text(model.query)
                    .foregroundStyle(.primary)
                Text("|")
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 8)
            Text(countLabel)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
        .font(.system(size: 12))
        .padding(.horizontal, 12)
        .frame(height: Self.headerHeight)
    }

    private var countLabel: String {
        if model.isFiltering {
            return "\(model.visibleItems.count) of \(model.totalCount)"
        }
        return "\(model.totalCount) item\(model.totalCount == 1 ? "" : "s")"
    }

    private var rows: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(model.visibleItems.enumerated()), id: \.element.id) { index, item in
                        HistoryRowView(
                            item: item,
                            isSelected: index == model.selectedIndex,
                            shortcut: model.numericShortcutLabel(for: index),
                            thumbnail: ThumbnailCache.shared.thumbnail(for: item) {
                                model.imageData(for: item)
                            }
                        )
                        .frame(height: Self.rowHeight)
                        .id(item.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            model.select(index: index)
                            onChoose(item, NSEvent.modifierFlags.contains(.option))
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(height: CGFloat(min(model.visibleItems.count, HistoryPanelModel.maxVisibleRows)) * Self.rowHeight)
            .onChange(of: model.selectedIndex) { _, _ in
                guard let id = model.selectedItem?.id else { return }
                withAnimation(.easeOut(duration: 0.1)) { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 4) {
            Image(systemName: model.isFiltering ? "magnifyingglass" : "doc.on.clipboard")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(.tertiary)
            Text(model.isFiltering ? "No matches" : "Nothing copied yet")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(height: 92)
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            hint("↑↓", "move")
            hint("⏎", "paste")
            hint("⌥⏎", "plain")
            hint("⌘P", "pin")
            hint("⌘⌫", "delete")
            Spacer(minLength: 0)
            hint("esc", "close")
        }
        .font(.system(size: 10))
        .padding(.horizontal, 12)
        .frame(height: Self.footerHeight)
    }

    private func hint(_ keys: String, _ label: String) -> some View {
        HStack(spacing: 3) {
            Text(keys).foregroundStyle(.secondary)
            Text(label).foregroundStyle(.tertiary)
        }
    }
}

struct HistoryRowView: View {
    let item: ClipboardItem
    let isSelected: Bool
    let shortcut: String?
    let thumbnail: NSImage?

    var body: some View {
        HStack(spacing: 10) {
            leading
                .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.previewText)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? .white : .primary)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.75) : Color.secondary)
            }
            Spacer(minLength: 4)
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.9) : Color.secondary)
            }
            if let shortcut {
                Text(shortcut)
                    .font(.system(size: 10, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? Color.white.opacity(0.8) : Color.secondary.opacity(0.7))
            }
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor)
                    .padding(.horizontal, 10)
            }
        }
    }

    @ViewBuilder
    private var leading: some View {
        if let thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.12))
                )
        } else {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.12))
                .overlay(
                    Image(systemName: symbolName)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(isSelected ? Color.white : Color.secondary)
                )
        }
    }

    private var symbolName: String {
        switch item.kind {
        case .text: "textformat"
        case .richText: "doc.richtext"
        case .image: "photo"
        }
    }

    private var subtitle: String {
        var parts: [String] = [Formatting.age(of: item.createdAt)]
        if let pixels = item.pixelDescription {
            parts.append(pixels)
        } else if item.kind == .richText {
            parts.append("Rich text")
        }
        parts.append(Formatting.bytes(item.byteCount))
        return parts.joined(separator: " · ")
    }
}
