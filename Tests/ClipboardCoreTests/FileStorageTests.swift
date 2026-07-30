import Foundation
import Testing
@testable import ClipboardCore

@Suite("FileStorage") @MainActor
struct FileStorageTests {

    private func makeTmp() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    // MARK: - FileHistoryIndexStore

    @Test("save then load round-trips items including dates, pins, and optional blob fields")
    func indexStoreRoundTrip() throws {
        let tmp = makeTmp()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let indexURL = tmp.appendingPathComponent("history.json")
        let store = try FileHistoryIndexStore(url: indexURL)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let item = ClipboardItem(
            id: UUID(),
            createdAt: date,
            kind: .richText,
            isPinned: true,
            fingerprint: "fp123",
            previewText: "Hello",
            searchText: "hello",
            byteCount: 42,
            textBlob: "abc.txt",
            rtfBlob: "abc.rtf",
            imageBlob: nil,
            pixelWidth: nil,
            pixelHeight: nil
        )
        try store.save([item])
        let loaded = try store.load()
        #expect(loaded.count == 1)
        let l = try #require(loaded.first)
        #expect(l.id == item.id)
        #expect(l.isPinned == true)
        #expect(l.kind == .richText)
        #expect(l.textBlob == "abc.txt")
        #expect(l.rtfBlob == "abc.rtf")
        #expect(l.imageBlob == nil)
        #expect(abs(l.createdAt.timeIntervalSince(date)) < 1)
    }

    @Test("loading a missing file returns empty array")
    func loadMissingFileReturnsEmpty() throws {
        let tmp = makeTmp()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let store = try FileHistoryIndexStore(url: tmp.appendingPathComponent("history.json"))
        let items = try store.load()
        #expect(items.isEmpty)
    }

    @Test("loading a corrupt file returns empty and moves file to quarantine URL")
    func loadCorruptFileQuarantines() throws {
        let tmp = makeTmp()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let indexURL = tmp.appendingPathComponent("history.json")
        let store = try FileHistoryIndexStore(url: indexURL)
        try Data("{not json".utf8).write(to: indexURL)
        let items = try store.load()
        #expect(items.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: indexURL.path))
        #expect(FileManager.default.fileExists(atPath: store.quarantineURL.path))
    }

    @Test("a second load after quarantine also returns empty without throwing")
    func secondLoadAfterQuarantineIsEmpty() throws {
        let tmp = makeTmp()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let indexURL = tmp.appendingPathComponent("history.json")
        let store = try FileHistoryIndexStore(url: indexURL)
        try Data("{not json".utf8).write(to: indexURL)
        _ = try store.load()
        let secondLoad = try store.load()
        #expect(secondLoad.isEmpty)
    }

    @Test("loading a file with future schemaVersion quarantines and returns empty")
    func loadFutureSchemaVersionQuarantines() throws {
        let tmp = makeTmp()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let indexURL = tmp.appendingPathComponent("history.json")
        let store = try FileHistoryIndexStore(url: indexURL)
        let futureJSON = #"{"schemaVersion":999,"items":[]}"#
        try Data(futureJSON.utf8).write(to: indexURL)
        let items = try store.load()
        #expect(items.isEmpty)
        #expect(FileManager.default.fileExists(atPath: store.quarantineURL.path))
    }

    // MARK: - FileBlobStore

    @Test("identical bytes written twice produce the same name and one file on disk")
    func blobStoreDeduplicatesSameBytes() throws {
        let tmp = makeTmp()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let store = try FileBlobStore(directory: tmp)
        let data = Data("hello world".utf8)
        let name1 = try store.write(data, extension: "txt")
        let name2 = try store.write(data, extension: "txt")
        #expect(name1 == name2)
        let files = try FileManager.default.contentsOfDirectory(atPath: tmp.path)
        #expect(files.count == 1)
    }

    @Test("read returns the bytes that were written")
    func blobStoreReadReturnsBytes() throws {
        let tmp = makeTmp()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let store = try FileBlobStore(directory: tmp)
        let data = Data("payload".utf8)
        let name = try store.write(data, extension: "bin")
        let read = try store.read(name)
        #expect(read == data)
    }

    @Test("exists returns true for written blobs and false after delete")
    func blobStoreExistsAndDelete() throws {
        let tmp = makeTmp()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let store = try FileBlobStore(directory: tmp)
        let name = try store.write(Data("x".utf8), extension: "txt")
        #expect(store.exists(name))
        try store.delete(name)
        #expect(!store.exists(name))
    }

    @Test("reading a missing blob name throws BlobStoreError.notFound")
    func blobStoreReadMissingThrows() throws {
        let tmp = makeTmp()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let store = try FileBlobStore(directory: tmp)
        #expect(throws: BlobStoreError.notFound("ghost.txt")) {
            try store.read("ghost.txt")
        }
    }

    @Test("totalBytes reflects the sum of all stored files")
    func blobStoreTotalBytes() throws {
        let tmp = makeTmp()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let store = try FileBlobStore(directory: tmp)
        let d1 = Data(repeating: 0x01, count: 100)
        let d2 = Data(repeating: 0x02, count: 200)
        _ = try store.write(d1, extension: "bin")
        _ = try store.write(d2, extension: "bin")
        #expect(store.totalBytes() == 300)
    }

    @Test("prune removes exactly the unreferenced files and returns the count")
    func blobStorePrune() throws {
        let tmp = makeTmp()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let store = try FileBlobStore(directory: tmp)
        let name1 = try store.write(Data("keep".utf8), extension: "txt")
        _ = try store.write(Data("prune-me".utf8), extension: "txt")
        let removed = store.prune(keeping: [name1])
        #expect(removed == 1)
        #expect(store.exists(name1))
        let files = try FileManager.default.contentsOfDirectory(atPath: tmp.path)
        #expect(files.count == 1)
    }

    // MARK: - End-to-end round-trip

    @Test("HistoryStore backed by file stores can save and reload identical items")
    func endToEndRoundTrip() throws {
        let tmp = makeTmp()
        defer { try? FileManager.default.removeItem(at: tmp) }
        let indexURL = tmp.appendingPathComponent("history.json")
        let blobDir = tmp.appendingPathComponent("blobs")

        let index1 = try FileHistoryIndexStore(url: indexURL)
        let blobs1 = try FileBlobStore(directory: blobDir)
        let store1 = HistoryStore(index: index1, blobs: blobs1)

        store1.insert(textContent("hello"))
        store1.insert(textContent("world"))
        store1.togglePin(store1.items[0].id)

        let pinnedId = store1.items[0].id
        let pinnedPreview = store1.items[0].previewText

        let index2 = try FileHistoryIndexStore(url: indexURL)
        let blobs2 = try FileBlobStore(directory: blobDir)
        let store2 = HistoryStore(index: index2, blobs: blobs2)
        store2.load()

        #expect(store2.items.count == 2)
        #expect(store2.items[0].id == pinnedId)
        #expect(store2.items[0].isPinned)
        #expect(store2.items[0].previewText == pinnedPreview)

        let recovered = try store2.content(for: store2.items[0])
        if case .text(let text) = recovered {
            #expect(text == pinnedPreview)
        } else {
            Issue.record("Expected text content")
        }
    }

    // MARK: - AppPaths

    @Test("AppPaths.standard() produces expected paths under Application Support")
    func appPathsStandard() throws {
        let paths = try AppPaths.standard()
        #expect(paths.indexURL.lastPathComponent == "history.json")
        #expect(paths.blobsDirectory.lastPathComponent == "blobs")
        #expect(paths.supportDirectory.lastPathComponent == AppPaths.directoryName)
        #expect(paths.supportDirectory.path.contains("Application Support"))
    }
}
