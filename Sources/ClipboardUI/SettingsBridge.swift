import ClipboardCore
import ClipboardPlatform
import Combine
import Foundation

/// Connects the settings UI to the parts of the app that live outside it.
///
/// The window is created lazily and can outlive individual actions, so the
/// composition root fills these in once at launch.
@MainActor
final class SettingsBridge: ObservableObject {
    @Published var hotkeyErrors: [HotkeySlot: String] = [:]
    @Published var loginItemError: String?
    @Published var isLoginItemAvailable = true
    @Published var loginItemStatus = ""
    @Published var storageBytes = 0

    var revealStorage: () -> Void = {}
    var clearHistory: (_ keepingPinned: Bool) -> Void = { _ in }
    var refreshStorage: () -> Void = {}
    var resetSettings: () -> Void = {}
    var quit: () -> Void = {}

    func error(for slot: HotkeySlot) -> String? {
        hotkeyErrors[slot]
    }

    func setError(_ message: String?, for slot: HotkeySlot) {
        if let message {
            hotkeyErrors[slot] = message
        } else {
            hotkeyErrors.removeValue(forKey: slot)
        }
    }
}
