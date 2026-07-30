import Combine
import Foundation

/// The clipboard history: an ordered, deduplicated, capped list of items backed
/// by an index store for metadata and a blob store for payload bytes.
///
/// Ordering is strictly newest-first regardless of pinning; pinning only makes
/// an item immune to eviction.
@MainActor
public final class HistoryStore: ObservableObject {
    /// Payloads larger than this are ignored so a stray huge copy cannot fill the disk.
    public static let maxItemBytes = 16 * 1024 * 1024

    @Published public private(set) var items: [ClipboardItem] = []
    /// Set when persistence fails; surfaced in Settings → Storage.
    @Published public private(set) var lastError: String?

    private let index: HistoryIndexStoring
    private let blobs: BlobStoring
    private let clock: () -> Date
    private var capacity: Int

    public init(
        index: HistoryIndexStoring,
        blobs: BlobStoring,
        maxItems: Int = 25,
        clock: @escaping () -> Date = Date.init
    ) {
        self.index = index
        self.blobs = blobs
        self.capacity = AppSettings.clampMaxItems(maxItems)
        self.clock = clock
    }

    /// The number of items kept. Lowering it evicts immediately.
    public var maxItems: Int {
        get { capacity }
        set {
            let clamped = AppSettings.clampMaxItems(newValue)
            guard clamped != capacity else { return }
            capacity = clamped
            if trim() { persist() }
        }
    }

    public var pinnedCount: Int {
        items.count { $0.isPinned }
    }

    public func load() {
        do {
            items = try index.load()
        } catch {
            items = []
            report(error, while: "loading history")
        }
    }

    // MARK: - Mutation

    /// Records a clipboard change. Returns the resulting item, or `nil` when the
    /// content was blank, oversized, or could not be stored.
    @discardableResult
    public func insert(_ content: ClipboardContent) -> ClipboardItem? {
        guard content.isMeaningful else { return nil }
        guard content.byteCount <= Self.maxItemBytes else { return nil }

        let fingerprint = content.fingerprint
        if let existing = items.firstIndex(where: { $0.fingerprint == fingerprint }) {
            var item = items.remove(at: existing)
            item.createdAt = clock()
            items.insert(item, at: 0)
            persist()
            return item
        }

        do {
            let item = try makeItem(from: content)
            items.insert(item, at: 0)
            trim()
            persist()
            return item
        } catch {
            report(error, while: "saving clipboard content")
            return nil
        }
    }

    public func togglePin(_ id: UUID) {
        guard let position = items.firstIndex(where: { $0.id == id }) else { return }
        items[position].isPinned.toggle()
        // Unpinning can make the item evictable and put us back within capacity.
        trim()
        persist()
    }

    public func delete(_ id: UUID) {
        guard let position = items.firstIndex(where: { $0.id == id }) else { return }
        items.remove(at: position)
        collectGarbage()
        persist()
    }

    public func clear(keepingPinned: Bool = true) {
        items = keepingPinned ? items.filter(\.isPinned) : []
        collectGarbage()
        persist()
    }

    // MARK: - Reading

    /// Rebuilds the full content of an item from its blobs.
    public func content(for item: ClipboardItem) throws -> ClipboardContent {
        switch item.kind {
        case .text:
            guard let name = item.textBlob else { throw HistoryStoreError.missingPayload(item.id) }
            return .text(try string(from: name))
        case .richText:
            guard let rtfName = item.rtfBlob, let textName = item.textBlob else {
                throw HistoryStoreError.missingPayload(item.id)
            }
            return .richText(rtf: try blobs.read(rtfName), plain: try string(from: textName))
        case .image:
            guard let name = item.imageBlob else { throw HistoryStoreError.missingPayload(item.id) }
            return .image(
                ImagePayload(
                    pngData: try blobs.read(name),
                    pixelWidth: item.pixelWidth ?? 0,
                    pixelHeight: item.pixelHeight ?? 0
                )
            )
        }
    }

    /// Raw image bytes for a row thumbnail, or `nil` when unavailable.
    public func imageData(for item: ClipboardItem) -> Data? {
        guard let name = item.imageBlob else { return nil }
        return try? blobs.read(name)
    }

    /// True when the item's payload is still on disk.
    public func isIntact(_ item: ClipboardItem) -> Bool {
        item.blobNames.allSatisfy { blobs.exists($0) }
    }

    public var storageBytes: Int {
        blobs.totalBytes()
    }

    /// Drops items whose payload files have vanished. Returns the number removed.
    @discardableResult
    public func removeBrokenItems() -> Int {
        let before = items.count
        items = items.filter { isIntact($0) }
        let removed = before - items.count
        if removed > 0 { persist() }
        return removed
    }

    public func flush() {
        persist()
    }

    // MARK: - Internals

    private func makeItem(from content: ClipboardContent) throws -> ClipboardItem {
        let now = clock()
        switch content {
        case .text(let string):
            let blob = try blobs.write(Data(string.utf8), extension: "txt")
            return ClipboardItem(
                createdAt: now,
                kind: .text,
                fingerprint: content.fingerprint,
                previewText: ClipboardPreview.text(from: string),
                searchText: ClipboardPreview.searchText(from: string),
                byteCount: content.byteCount,
                textBlob: blob
            )
        case .richText(let rtf, let plain):
            let textBlob = try blobs.write(Data(plain.utf8), extension: "txt")
            let rtfBlob = try blobs.write(rtf, extension: "rtf")
            return ClipboardItem(
                createdAt: now,
                kind: .richText,
                fingerprint: content.fingerprint,
                previewText: ClipboardPreview.text(from: plain),
                searchText: ClipboardPreview.searchText(from: plain),
                byteCount: content.byteCount,
                textBlob: textBlob,
                rtfBlob: rtfBlob
            )
        case .image(let payload):
            let blob = try blobs.write(payload.pngData, extension: "png")
            let label = "Image \(payload.pixelWidth) × \(payload.pixelHeight)"
            return ClipboardItem(
                createdAt: now,
                kind: .image,
                fingerprint: content.fingerprint,
                previewText: label,
                searchText: ClipboardPreview.searchText(from: label),
                byteCount: content.byteCount,
                imageBlob: blob,
                pixelWidth: payload.pixelWidth,
                pixelHeight: payload.pixelHeight
            )
        }
    }

    private func string(from blobName: String) throws -> String {
        let data = try blobs.read(blobName)
        guard let string = String(data: data, encoding: .utf8) else {
            throw HistoryStoreError.undecodableText(blobName)
        }
        return string
    }

    /// Evicts the oldest unpinned items until within capacity. Returns whether
    /// anything was removed.
    @discardableResult
    private func trim() -> Bool {
        guard items.count > capacity else { return false }
        var removedAny = false
        while items.count > capacity,
              let victim = items.lastIndex(where: { !$0.isPinned }) {
            items.remove(at: victim)
            removedAny = true
        }
        if removedAny { collectGarbage() }
        return removedAny
    }

    private func collectGarbage() {
        let referenced = Set(items.flatMap(\.blobNames))
        if let fileStore = blobs as? FileBlobStore {
            fileStore.prune(keeping: referenced)
        } else if let memoryStore = blobs as? InMemoryBlobStore {
            for name in memoryStore.names.subtracting(referenced) {
                try? memoryStore.delete(name)
            }
        }
    }

    private func persist() {
        do {
            try index.save(items)
            if lastError != nil { lastError = nil }
        } catch {
            report(error, while: "saving history")
        }
    }

    private func report(_ error: Error, while action: String) {
        lastError = "Failed \(action): \(error.localizedDescription)"
    }
}

public enum HistoryStoreError: Error, Equatable {
    case missingPayload(UUID)
    case undecodableText(String)
}
