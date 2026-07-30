import AppKit
import Sparkle

/// Owns the Sparkle updater for background checks and “Check for Updates…”.
@MainActor
final class UpdateController: NSObject {
    private let controller: SPUStandardUpdaterController

    override init() {
        // startingUpdater: true begins periodic checks after launch.
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
    }

    /// Menu / Settings entry point.
    @objc func checkForUpdates(_ sender: Any?) {
        controller.checkForUpdates(sender)
    }

    var canCheckForUpdates: Bool {
        controller.updater.canCheckForUpdates
    }
}
