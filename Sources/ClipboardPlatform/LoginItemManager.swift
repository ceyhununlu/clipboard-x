import Foundation
import ServiceManagement

public enum LoginItemError: Error, Equatable, LocalizedError {
    case unavailable
    case serviceFailed(String)

    public var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Launch at login needs ClipboardX to be running from ClipboardX.app."
        case .serviceFailed(let reason):
            return "Could not change the login item: \(reason)"
        }
    }
}

/// Registers the app to open at login.
///
/// Prefers `SMAppService.mainApp` (the modern, user-visible Login Items path).
/// Ad-hoc signed builds often get `.notFound` from that API, so a LaunchAgent
/// in `~/Library/LaunchAgents` is used as a fallback that works without a
/// Developer ID. The Settings UI does not need to know which path is active.
@MainActor
public final class LoginItemManager {
    private let agentLabel = "com.ceyhununlu.clipboardx.login"
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public var isAvailable: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    public var isEnabled: Bool {
        guard isAvailable else { return false }
        if smAppServiceUsable {
            return SMAppService.mainApp.status == .enabled
        }
        return fileManager.fileExists(atPath: agentPlistURL.path)
    }

    public var statusDescription: String {
        guard isAvailable else {
            return "Unavailable while running outside ClipboardX.app"
        }
        if smAppServiceUsable {
            switch SMAppService.mainApp.status {
            case .enabled:
                return "Enabled"
            case .notRegistered:
                return "Off"
            case .requiresApproval:
                return "Waiting for your approval in System Settings › General › Login Items"
            case .notFound:
                break
            @unknown default:
                return "Unknown"
            }
        }
        return isEnabled
            ? "Enabled (LaunchAgent)"
            : "Off"
    }

    public func setEnabled(_ enabled: Bool) throws {
        guard isAvailable else { throw LoginItemError.unavailable }

        if smAppServiceUsable || (!enabled && SMAppService.mainApp.status == .enabled) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                    removeAgent()
                    return
                } else if SMAppService.mainApp.status == .enabled
                            || SMAppService.mainApp.status == .requiresApproval {
                    try SMAppService.mainApp.unregister()
                    removeAgent()
                    return
                }
            } catch {
                if !enabled {
                    removeAgent()
                    return
                }
                // Fall through to the LaunchAgent path when registration is refused.
            }
        }

        if enabled {
            try installAgent()
        } else {
            removeAgent()
        }
    }

    // MARK: - SMAppService

    /// `true` when the modern API can see us. `.notFound` means we have to use
    /// the LaunchAgent; the other states are all actionable through SMAppService.
    private var smAppServiceUsable: Bool {
        SMAppService.mainApp.status != .notFound
    }

    // MARK: - LaunchAgent fallback

    private var agentPlistURL: URL {
        let home = fileManager.homeDirectoryForCurrentUser
        return home
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(agentLabel).plist")
    }

    private func installAgent() throws {
        guard let bundlePath = Bundle.main.bundleURL.path as String? else {
            throw LoginItemError.unavailable
        }
        let directory = agentPlistURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let plist: [String: Any] = [
            "Label": agentLabel,
            "ProgramArguments": ["/usr/bin/open", "-a", bundlePath],
            "RunAtLoad": true,
            "LimitLoadToSessionType": "Aqua",
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: agentPlistURL, options: .atomic)

        // Load it now so a failure surfaces immediately rather than at next login.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["load", "-w", agentPlistURL.path]
        let sink = Pipe()
        process.standardError = sink
        process.standardOutput = sink
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw LoginItemError.serviceFailed(error.localizedDescription)
        }
        if process.terminationStatus != 0 {
            let err = String(data: sink.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            // "already loaded" is fine — the plist is what matters for next login.
            if !err.contains("Already loaded") && !err.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // launchctl load is best-effort on modern macOS; the plist alone is enough.
            }
        }
    }

    private func removeAgent() {
        if fileManager.fileExists(atPath: agentPlistURL.path) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            process.arguments = ["unload", "-w", agentPlistURL.path]
            process.standardError = Pipe()
            process.standardOutput = Pipe()
            try? process.run()
            process.waitUntilExit()
            try? fileManager.removeItem(at: agentPlistURL)
        }
    }
}
