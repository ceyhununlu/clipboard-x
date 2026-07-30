import AppKit
import ClipboardCore
import SwiftUI

/// The contents of the history popup.
///
/// List navigation (↑↓, Return, ⌘ shortcuts) is handled by
/// `HistoryPanelController`'s key monitor. Typing, caret movement, and editing
/// go to the focused search field so the header behaves like a normal text box.
struct HistoryListView: View {
    @ObservedObject var model: HistoryPanelModel
    let onChoose: (ClipboardItem, Bool) -> Void

    @FocusState private var isSearchFocused: Bool

    static let width: CGFloat = 420
    static let rowHeight: CGFloat = 54
    static let headerHeight: CGFloat = 36
    static let footerHeight: CGFloat = 26
    static let separatorHeight: CGFloat = 1
    /// Always reserve room for the scroll limit so filtering does not resize the panel.
    static let bodyHeight: CGFloat = CGFloat(HistoryPanelModel.maxVisibleRows) * rowHeight

    /// Fixed panel height — independent of the current row count.
    static var panelHeight: CGFloat {
        headerHeight
            + separatorHeight
            + bodyHeight
            + separatorHeight
            + footerHeight
    }

    /// Kept for call sites / tests; height no longer depends on `count`.
    static func height(forRowCount _: Int) -> CGFloat {
        panelHeight
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            separator
            bodyContent
            separator
            footer
        }
        .frame(width: Self.width, height: Self.panelHeight)
        .background(Color.clear)
        .clipShape(panelShape)
        .onAppear { isSearchFocused = true }
        .onChange(of: model.searchFocusNonce) { _, _ in
            isSearchFocused = true
        }
    }

    private var panelShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: RoundedPanelChromeView.cornerRadius, style: .continuous)
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.10))
            .frame(height: Self.separatorHeight)
            .padding(.horizontal, RoundedPanelChromeView.cornerRadius)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 12, weight: .semibold))

            TextField("Type to search", text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isSearchFocused)
                .onSubmit {
                    if let item = model.selectedItem {
                        onChoose(item, NSEvent.modifierFlags.contains(.option))
                    }
                }

            if !model.query.isEmpty {
                Button {
                    model.clearQuery()
                    isSearchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }

            Text(countLabel)
                .foregroundStyle(.tertiary)
                .font(.system(size: 11))
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .frame(height: Self.headerHeight)
    }

    private var countLabel: String {
        if model.isFiltering {
            return "\(model.visibleItems.count) of \(model.totalCount)"
        }
        return "\(model.totalCount) item\(model.totalCount == 1 ? "" : "s")"
    }

    @ViewBuilder
    private var bodyContent: some View {
        if model.isEmpty {
            emptyState
        } else {
            rows
        }
    }

    private var rows: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
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
            .frame(height: Self.bodyHeight)
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
        .frame(height: Self.bodyHeight)
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
        // Fill the fixed row height so the selection chrome can inset from the
        // row edges (like the left/right gap) without shrinking to the text.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor)
                    .padding(10)
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
