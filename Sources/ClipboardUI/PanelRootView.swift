import ClipboardCore
import SwiftUI

/// Root of the history popup: mode tabs + Clipboard / Emoji content.
struct PanelRootView: View {
    @ObservedObject var session: PanelSessionModel
    let onChooseClipboard: (ClipboardItem, Bool) -> Void
    let onChooseEmoji: (String) -> Void

    static let tabBarHeight: CGFloat = 36

    /// Total popup height including the mode tab strip.
    static var panelHeight: CGFloat {
        tabBarHeight + HistoryListView.panelHeight
    }

    static var width: CGFloat { HistoryListView.width }

    var body: some View {
        VStack(spacing: 0) {
            PanelModeTabBar(session: session)
                .frame(width: Self.width, height: Self.tabBarHeight)
            content
                .frame(height: HistoryListView.panelHeight)
        }
        .frame(width: Self.width, height: Self.panelHeight)
        .background(Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: RoundedPanelChromeView.cornerRadius, style: .continuous))
    }

    @ViewBuilder
    private var content: some View {
        switch session.mode {
        case .clipboard:
            HistoryListView(model: session.history, onChoose: onChooseClipboard)
        case .emoji:
            EmojiPickerView(model: session.emoji, onChoose: onChooseEmoji)
        }
    }
}
