import Foundation

/// Content-addressed byte storage for clipboard payloads.
public protocol BlobStoring: AnyObject {
    /// Writes `data` and returns its name. Writing identical bytes twice yields
    /// the same name and does not duplicate storage.
    func write(_ data: Data, extension ext: String) throws -> String
    func read(_ name: String) throws -> Data
    func exists(_ name: String) -> Bool
    func delete(_ name: String) throws
    /// Total bytes currently held.
    func totalBytes() -> Int
}

public enum BlobStoreError: Error, Equatable {
    case notFound(String)
}

public final class FileBlobStore: BlobStoring {
    private let directory: URL
    private let fileManager: FileManager

    public init(directory: URL, fileManager: FileManager = .default) throws {
        self.directory = directory
        self.fileManager = fileManager
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func write(_ data: Data, extension ext: String) throws -> String {
        let name = Digest.hex(of: data, domain: "blob") + "." + ext
        let url = directory.appendingPathComponent(name)
        if !fileManager.fileExists(atPath: url.path) {
            try data.write(to: url, options: .atomic)
        }
        return name
    }

    public func read(_ name: String) throws -> Data {
        let url = directory.appendingPathComponent(name)
        guard fileManager.fileExists(atPath: url.path) else {
            throw BlobStoreError.notFound(name)
        }
        return try Data(contentsOf: url)
    }

    public func exists(_ name: String) -> Bool {
        fileManager.fileExists(atPath: directory.appendingPathComponent(name).path)
    }

    public func delete(_ name: String) throws {
        let url = directory.appendingPathComponent(name)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    public func totalBytes() -> Int {
        let names = (try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? []
        return names.reduce(into: 0) { total, name in
            let path = directory.appendingPathComponent(name).path
            let size = (try? fileManager.attributesOfItem(atPath: path)[.size]) as? Int
            total += size ?? 0
        }
    }

    /// Removes blobs no longer referenced by any item. Returns the count removed.
    @discardableResult
    public func prune(keeping referenced: Set<String>) -> Int {
        let names = (try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? []
        var removed = 0
        for name in names where !referenced.contains(name) {
            if (try? delete(name)) != nil { removed += 1 }
        }
        return removed
    }
}

public final class InMemoryBlobStore: BlobStoring {
    private var storage: [String: Data] = [:]
    public private(set) var writeCount = 0

    public init() {}

    public func write(_ data: Data, extension ext: String) throws -> String {
        let name = Digest.hex(of: data, domain: "blob") + "." + ext
        if storage[name] == nil {
            storage[name] = data
            writeCount += 1
        }
        return name
    }

    public func read(_ name: String) throws -> Data {
        guard let data = storage[name] else { throw BlobStoreError.notFound(name) }
        return data
    }

    public func exists(_ name: String) -> Bool { storage[name] != nil }

    public func delete(_ name: String) throws { storage.removeValue(forKey: name) }

    public func totalBytes() -> Int { storage.values.reduce(0) { $0 + $1.count } }

    public var names: Set<String> { Set(storage.keys) }
}
