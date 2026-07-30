import Foundation

/// Load/save of the ordered item index.
public protocol HistoryIndexStoring: AnyObject {
    func load() throws -> [ClipboardItem]
    func save(_ items: [ClipboardItem]) throws
}

struct HistoryIndex: Codable {
    static let currentSchemaVersion = 1
    var schemaVersion: Int
    var items: [ClipboardItem]
}

public final class FileHistoryIndexStore: HistoryIndexStoring {
    private let url: URL
    private let fileManager: FileManager

    public init(url: URL, fileManager: FileManager = .default) throws {
        self.url = url
        self.fileManager = fileManager
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    /// Where a file that failed to decode gets moved so the user can recover it.
    public var quarantineURL: URL {
        url.appendingPathExtension("corrupt")
    }

    public func load() throws -> [ClipboardItem] {
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        let data = try Data(contentsOf: url)
        guard !data.isEmpty else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let index = try decoder.decode(HistoryIndex.self, from: data)
            guard index.schemaVersion <= HistoryIndex.currentSchemaVersion else {
                // Written by a newer build: keep it, start empty rather than
                // silently dropping fields we do not understand.
                try quarantine()
                return []
            }
            return index.items
        } catch {
            try quarantine()
            return []
        }
    }

    public func save(_ items: [ClipboardItem]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.withoutEscapingSlashes]
        let data = try encoder.encode(
            HistoryIndex(schemaVersion: HistoryIndex.currentSchemaVersion, items: items)
        )
        try data.write(to: url, options: .atomic)
    }

    private func quarantine() throws {
        if fileManager.fileExists(atPath: quarantineURL.path) {
            try fileManager.removeItem(at: quarantineURL)
        }
        try fileManager.moveItem(at: url, to: quarantineURL)
    }
}

public final class InMemoryHistoryIndexStore: HistoryIndexStoring {
    public private(set) var saved: [ClipboardItem]
    public private(set) var saveCount = 0
    public var loadError: Error?
    public var saveError: Error?

    public init(initial: [ClipboardItem] = []) {
        self.saved = initial
    }

    public func load() throws -> [ClipboardItem] {
        if let loadError { throw loadError }
        return saved
    }

    public func save(_ items: [ClipboardItem]) throws {
        if let saveError { throw saveError }
        saved = items
        saveCount += 1
    }
}
