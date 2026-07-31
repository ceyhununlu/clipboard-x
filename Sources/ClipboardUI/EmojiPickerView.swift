import ClipboardCore
import SwiftUI

struct EmojiPickerView: View {
    @ObservedObject var model: EmojiPickerModel
    let onChoose: (String) -> Void

    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchHeader
            categoryBar
            separator
            grid
        }
        .onAppear { isSearchFocused = true }
        .onChange(of: model.searchFocusNonce) { _, _ in
            isSearchFocused = true
        }
    }

    private var searchHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 12, weight: .semibold))
            TextField("Search emoji", text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isSearchFocused)
                .onSubmit {
                    if let emoji = model.selectedEmoji {
                        onChoose(emoji)
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
        }
        .padding(.horizontal, 12)
        .frame(height: HistoryListView.headerHeight)
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(model.categories) { category in
                    let selected = model.selectedCategoryID == category.id
                    Button {
                        model.selectedCategoryID = category.id
                    } label: {
                        Text(category.symbol)
                            .font(.system(size: 16))
                            .frame(width: 28, height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(selected ? Color.accentColor.opacity(0.2) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(category.name)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
        }
        .frame(height: 36)
    }

    private var separator: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.10))
            .frame(height: HistoryListView.separatorHeight)
            .padding(.horizontal, RoundedPanelChromeView.cornerRadius)
    }

    private var grid: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.flexible(), spacing: 4),
                        count: EmojiPickerModel.columns
                    ),
                    spacing: 4
                ) {
                    ForEach(Array(model.visibleEmoji.enumerated()), id: \.offset) { index, emoji in
                        Text(emoji)
                            .font(.system(size: 28))
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background {
                                if index == model.selectedIndex {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.accentColor.opacity(0.25))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .strokeBorder(Color.accentColor, lineWidth: 2)
                                        )
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                model.select(index: index)
                                onChoose(emoji)
                            }
                            .id(index)
                    }
                }
                .padding(10)
            }
            .frame(maxHeight: .infinity)
            .onChange(of: model.selectedIndex) { _, index in
                withAnimation(.easeOut(duration: 0.1)) {
                    proxy.scrollTo(index, anchor: .center)
                }
            }
        }
    }
}
