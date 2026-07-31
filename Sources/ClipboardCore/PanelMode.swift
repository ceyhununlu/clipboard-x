import Foundation

/// Which surface the history popup is showing.
public enum PanelMode: String, CaseIterable, Sendable, Equatable {
    case clipboard
    case emoji

    public var title: String {
        switch self {
        case .clipboard: "Clipboard"
        case .emoji: "Emoji"
        }
    }

    public var systemImage: String {
        switch self {
        case .clipboard: "doc.on.clipboard"
        case .emoji: "face.smiling"
        }
    }
}
