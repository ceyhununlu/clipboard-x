import Foundation

/// How ClipboardX should present itself relative to macOS appearance.
public enum AppearancePreference: String, CaseIterable, Codable, Sendable, Equatable {
    case system
    case light
    case dark

    public var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}
