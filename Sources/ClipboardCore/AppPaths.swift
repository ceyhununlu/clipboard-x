import Foundation

/// Where ClipboardX keeps its data.
public struct AppPaths: Sendable {
    public static let directoryName = "ClipboardX"

    public let supportDirectory: URL

    public init(supportDirectory: URL) {
        self.supportDirectory = supportDirectory
    }

    /// `~/Library/Application Support/ClipboardX`
    public static func standard(fileManager: FileManager = .default) throws -> AppPaths {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return AppPaths(supportDirectory: base.appendingPathComponent(directoryName, isDirectory: true))
    }

    public var indexURL: URL {
        supportDirectory.appendingPathComponent("history.json")
    }

    public var blobsDirectory: URL {
        supportDirectory.appendingPathComponent("blobs", isDirectory: true)
    }
}
