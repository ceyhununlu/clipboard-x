import Foundation
import os

enum AppLog {
    static let subsystem = Bundle.main.bundleIdentifier ?? "com.ceyhununlu.clipboardx"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let clipboard = Logger(subsystem: subsystem, category: "clipboard")
    static let hotkeys = Logger(subsystem: subsystem, category: "hotkeys")
    static let panel = Logger(subsystem: subsystem, category: "panel")
    static let permissions = Logger(subsystem: subsystem, category: "permissions")
}

enum AppInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    /// False under `swift run`, where there is no surrounding .app bundle.
    static var isBundled: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }
}
