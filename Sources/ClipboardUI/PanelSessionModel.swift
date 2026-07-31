import ClipboardCore
import Combine
import Foundation

/// Owns the active popup tab and the per-tab models.
@MainActor
final class PanelSessionModel: ObservableObject {
    @Published var mode: PanelMode = .clipboard {
        didSet {
            guard mode != oldValue else { return }
            focusActiveSearch()
        }
    }

    let history: HistoryPanelModel
    let emoji: EmojiPickerModel

    init(history: HistoryPanelModel) {
        self.history = history
        self.emoji = EmojiPickerModel()
    }

    func reset() {
        mode = .clipboard
        history.reset()
        emoji.reset()
    }

    func focusActiveSearch() {
        switch mode {
        case .clipboard: history.resetFocusOnly()
        case .emoji: emoji.focusSearch()
        }
    }
}
