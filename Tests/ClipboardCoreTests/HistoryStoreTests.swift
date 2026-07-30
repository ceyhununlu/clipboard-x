import Foundation
import Testing
@testable import ClipboardCore

@Suite("HistoryStore") @MainActor
struct HistoryStoreTests {

    // MARK: - Insert ordering

    @Test("inserting multiple items keeps newest-first order")
    func insertNewestFirst() throws {
        let clock = makeSequentialClock()
        let (store, _, _) = makeStore(clock: clock)
        store.insert(textContent("first"))
        store.insert(textContent("second"))
        store.insert(textContent("third"))
        #expect(store.items.map(\.previewText) == ["third", "second", "first"])
    }

    // MARK: - Rejection of blank / oversized content

    @Test("blank text is rejected and nothing is stored")
    func blankTextRejected() {
        let (store, blobs, _) = makeStore()
        let result = store.insert(textContent(""))
        #expect(result == nil)
        #expect(store.items.isEmpty)
        #expect(blobs.writeCount == 0)
    }

    @Test("whitespace-only text is rejected")
    func whitespaceOnlyRejected() {
        let (store, _, _) = makeStore()
        let result = store.insert(textContent("   \n\t"))
        #expect(result == nil)
        #expect(store.items.isEmpty)
    }

    @Test("content over maxItemBytes is rejected")
    func oversizedContentRejected() {
        let (store, _, _) = makeStore()
        let huge = String(repeating: "x", count: HistoryStore.maxItemBytes + 1)
        let result = store.insert(textContent(huge))
        #expect(result == nil)
        #expect(store.items.isEmpty)
    }

    // MARK: - Deduplication

    @Test("inserting the same text twice moves the existing item to the top")
    func duplicateMovesToTop() throws {
        let clock = makeSequentialClock()
        let (store, _, _) = makeStore(clock: clock)
        store.insert(textContent("hello"))
        store.insert(textContent("world"))
        #expect(store.items[0].previewText == "world")
        store.insert(textContent("hello"))
        #expect(store.items.count == 2)
        #expect(store.items[0].previewText == "hello")
        #expect(store.items[1].previewText == "world")
    }

    @Test("duplicate keeps the same id")
    func duplicateKeepsSameId() throws {
        let clock = makeSequentialClock()
        let (store, _, _) = makeStore(clock: clock)
        store.insert(textContent("hello"))
        let originalId = try #require(store.items.first?.id)
        store.insert(textContent("world"))
        store.insert(textContent("hello"))
        #expect(store.items[0].id == originalId)
    }

    @Test("duplicate refreshes createdAt")
    func duplicateRefreshesCreatedAt() throws {
        let base = Date(timeIntervalSince1970: 1_000_000)
        let clock = makeSequentialClock(base: base)
        let (store, _, _) = makeStore(clock: clock)
        store.insert(textContent("hello"))  // t+0
        store.insert(textContent("world"))  // t+1
        store.insert(textContent("hello"))  // t+2 → moves "hello" to top, refreshes
        let item = try #require(store.items.first)
        #expect(item.createdAt == base.addingTimeInterval(2))
    }

    @Test("duplicate preserves isPinned")
    func duplicatePreservesPin() throws {
        let clock = makeSequentialClock()
        let (store, _, _) = makeStore(clock: clock)
        store.insert(textContent("hello"))
        let id = try #require(store.items.first?.id)
        store.togglePin(id)
        #expect(store.items[0].isPinned)
        store.insert(textContent("world"))
        store.insert(textContent("hello"))
        #expect(store.items[0].isPinned)
    }

    @Test("rich text whose plain text matches an existing text item deduplicates")
    func richTextDeduplicatesWithText() throws {
        let clock = makeSequentialClock()
        let (store, _, _) = makeStore(clock: clock)
        store.insert(textContent("hello"))
        let textId = try #require(store.items.first?.id)
        store.insert(richTextContent(plain: "hello"))
        #expect(store.items.count == 1)
        #expect(store.items[0].id == textId)
    }

    // MARK: - Capacity
    // Note: HistoryStore clamps maxItems to 5...200 (AppSettings.maxItemsRange).
    // Tests use maxItems: 5 (the minimum) and insert 8 items to trigger eviction.

    @Test("with maxItems 5, inserting 8 items keeps the newest 5")
    func capacityKeepsNewest() {
        let clock = makeSequentialClock()
        let (store, _, _) = makeStore(maxItems: 5, clock: clock)
        for i in 1...8 { store.insert(textContent("item\(i)")) }
        #expect(store.items.count == 5)
        #expect(store.items.map(\.previewText) == ["item8", "item7", "item6", "item5", "item4"])
    }

    @Test("lowering maxItems evicts immediately")
    func loweringMaxItemsEvictsImmediately() {
        let clock = makeSequentialClock()
        let (store, _, _) = makeStore(maxItems: 10, clock: clock)
        for i in 1...8 { store.insert(textContent("item\(i)")) }
        store.maxItems = 5
        #expect(store.items.count == 5)
        #expect(store.items.map(\.previewText) == ["item8", "item7", "item6", "item5", "item4"])
    }

    @Test("raising maxItems does not resurrect evicted items")
    func raisingMaxItemsNoResurrection() {
        let clock = makeSequentialClock()
        let (store, _, _) = makeStore(maxItems: 5, clock: clock)
        for i in 1...8 { store.insert(textContent("item\(i)")) }
        store.maxItems = 10
        #expect(store.items.count == 5)
    }

    @Test("maxItems values outside 5...200 are clamped on HistoryStore")
    func maxItemsOutsideRangeClamped() {
        let (store, _, _) = makeStore(maxItems: 25)
        store.maxItems = 1
        #expect(store.maxItems == 5)
        store.maxItems = 500
        #expect(store.maxItems == 200)
    }

    // MARK: - Pinned item eviction

    @Test("pinned items are never evicted when capacity is exceeded")
    func pinnedItemsNeverEvicted() throws {
        let clock = makeSequentialClock()
        let (store, _, _) = makeStore(maxItems: 5, clock: clock)
        for i in 1...5 { store.insert(textContent("item\(i)")) }
        // items = [item5, item4, item3, item2, item1]; pin item1 (oldest)
        let oldestId = try #require(store.items.last?.id)
        store.togglePin(oldestId)
        store.insert(textContent("item6"))
        // trim must evict oldest unpinned (item2) and spare pinned (item1)
        #expect(store.items.count == 5)
        #expect(store.items.contains { $0.id == oldestId })
        #expect(!store.items.contains { $0.previewText == "item2" })
    }

    @Test("when all items are pinned and capacity is exceeded nothing is dropped")
    func allPinnedNothingDropped() throws {
        let clock = makeSequentialClock()
        // load() does not call trim(), so pre-pinned items that exceed capacity survive.
        let blobs = InMemoryBlobStore()
        var prebuilt: [ClipboardItem] = []
        for i in 1...6 {
            let text = "item\(i)"
            let blobName = try blobs.write(Data(text.utf8), extension: "txt")
            prebuilt.append(ClipboardItem(
                createdAt: Date(timeIntervalSince1970: Double(i)),
                kind: .text,
                isPinned: true,
                fingerprint: "fp\(i)",
                previewText: text,
                searchText: text,
                byteCount: text.utf8.count,
                textBlob: blobName
            ))
        }
        let index = InMemoryHistoryIndexStore(initial: prebuilt)
        let store = HistoryStore(index: index, blobs: blobs, maxItems: 5, clock: clock)
        store.load()
        #expect(store.items.count == 6)
    }

    @Test("unpinning an over-capacity item makes it evictable on the next trim")
    func unpinningTriggersEviction() throws {
        let clock = makeSequentialClock()
        let blobs = InMemoryBlobStore()
        var prebuilt: [ClipboardItem] = []
        for i in 1...6 {
            let text = "item\(i)"
            let blobName = try blobs.write(Data(text.utf8), extension: "txt")
            prebuilt.append(ClipboardItem(
                createdAt: Date(timeIntervalSince1970: Double(i)),
                kind: .text,
                isPinned: true,
                fingerprint: "fp\(i)",
                previewText: text,
                searchText: text,
                byteCount: text.utf8.count,
                textBlob: blobName
            ))
        }
        let index = InMemoryHistoryIndexStore(initial: prebuilt)
        let store = HistoryStore(index: index, blobs: blobs, maxItems: 5, clock: clock)
        store.load()
        #expect(store.items.count == 6)
        let oldestId = try #require(store.items.last?.id)
        store.togglePin(oldestId)  // unpin → trim fires → oldest evicted
        #expect(store.items.count == 5)
        #expect(!store.items.contains { $0.id == oldestId })
    }

    // MARK: - Delete / clear

    @Test("delete removes only the specified item")
    func deleteRemovesOnlyTarget() throws {
        let clock = makeSequentialClock()
        let (store, _, _) = makeStore(clock: clock)
        store.insert(textContent("a"))
        store.insert(textContent("b"))
        store.insert(textContent("c"))
        let bId = try #require(store.items.first(where: { $0.previewText == "b" })?.id)
        store.delete(bId)
        #expect(store.items.count == 2)
        #expect(!store.items.contains { $0.id == bId })
        #expect(store.items.map(\.previewText).sorted() == ["a", "c"])
    }

    @Test("clear(keepingPinned: true) keeps only pinned items")
    func clearKeepingPinnedTrue() throws {
        let clock = makeSequentialClock()
        let (store, _, _) = makeStore(clock: clock)
        store.insert(textContent("a"))
        store.insert(textContent("b"))
        store.insert(textContent("c"))
        let bId = try #require(store.items.first(where: { $0.previewText == "b" })?.id)
        store.togglePin(bId)
        store.clear(keepingPinned: true)
        #expect(store.items.count == 1)
        #expect(store.items[0].id == bId)
    }

    @Test("clear(keepingPinned: false) empties everything")
    func clearKeepingPinnedFalse() throws {
        let clock = makeSequentialClock()
        let (store, _, _) = makeStore(clock: clock)
        store.insert(textContent("a"))
        store.insert(textContent("b"))
        let id = try #require(store.items.first?.id)
        store.togglePin(id)
        store.clear(keepingPinned: false)
        #expect(store.items.isEmpty)
    }

    // MARK: - Blob garbage collection

    @Test("after delete, orphaned blobs are removed and referenced blobs survive")
    func blobGCAfterDelete() throws {
        let clock = makeSequentialClock()
        let (store, blobs, _) = makeStore(clock: clock)
        store.insert(textContent("hello"))
        store.insert(textContent("world"))
        let helloItem = try #require(store.items.first(where: { $0.previewText == "hello" }))
        let helloBlobName = try #require(helloItem.textBlob)
        let worldItem = try #require(store.items.first(where: { $0.previewText == "world" }))
        let worldBlobName = try #require(worldItem.textBlob)
        store.delete(helloItem.id)
        #expect(!blobs.exists(helloBlobName))
        #expect(blobs.exists(worldBlobName))
    }

    @Test("after clear, orphaned blobs are removed but pinned item blobs survive")
    func blobGCAfterClear() throws {
        let clock = makeSequentialClock()
        let (store, blobs, _) = makeStore(clock: clock)
        store.insert(textContent("a"))
        store.insert(textContent("b"))
        let bItem = try #require(store.items.first(where: { $0.previewText == "b" }))
        store.togglePin(bItem.id)
        let aBlobName = try #require(store.items.first(where: { $0.previewText == "a" })?.textBlob)
        let bBlobName = try #require(bItem.textBlob)
        store.clear(keepingPinned: true)
        #expect(!blobs.exists(aBlobName))
        #expect(blobs.exists(bBlobName))
    }

    @Test("content-addressed dedup: writing identical bytes twice yields same name and writeCount 1")
    func contentAddressedDedup() throws {
        let blobStore = InMemoryBlobStore()
        let data = Data("shared content".utf8)
        let name1 = try blobStore.write(data, extension: "txt")
        let name2 = try blobStore.write(data, extension: "txt")
        #expect(name1 == name2)
        #expect(blobStore.writeCount == 1)
        #expect(blobStore.names == [name1])
    }

    // MARK: - Content round-trip

    @Test("content(for:) round-trips text content")
    func contentRoundTripsText() throws {
        let (store, _, _) = makeStore()
        let original: ClipboardContent = .text("round-trip test")
        let item = try #require(store.insert(original))
        let recovered = try store.content(for: item)
        #expect(recovered == original)
    }

    @Test("content(for:) round-trips rich text content")
    func contentRoundTripsRichText() throws {
        let (store, _, _) = makeStore()
        let rtfData = Data("{\rtf1 hello}".utf8)
        let original: ClipboardContent = .richText(rtf: rtfData, plain: "hello")
        let item = try #require(store.insert(original))
        let recovered = try store.content(for: item)
        #expect(recovered == original)
    }

    @Test("content(for:) round-trips image content including dimensions")
    func contentRoundTripsImage() throws {
        let (store, _, _) = makeStore()
        let pngData = Data(repeating: 0xDE, count: 128)
        let payload = ImagePayload(pngData: pngData, pixelWidth: 640, pixelHeight: 480)
        let original: ClipboardContent = .image(payload)
        let item = try #require(store.insert(original))
        let recovered = try store.content(for: item)
        #expect(recovered == original)
    }

    @Test("content(for:) throws missingPayload when textBlob reference is absent")
    func contentThrowsMissingPayload() throws {
        let (store, _, _) = makeStore()
        let id = UUID()
        let item = ClipboardItem(
            id: id,
            createdAt: Date(),
            kind: .text,
            fingerprint: "fp",
            previewText: "x",
            searchText: "x",
            byteCount: 1
        )
        #expect(throws: HistoryStoreError.missingPayload(id)) {
            try store.content(for: item)
        }
    }

    @Test("lastError is set and store does not crash when index save throws")
    func lastErrorSetOnSaveFailure() throws {
        let (store, _, index) = makeStore()
        index.saveError = NSError(domain: "test", code: 42, userInfo: nil)
        store.insert(textContent("hello"))
        #expect(store.lastError != nil)
    }

    // MARK: - Persistence

    @Test("insert persists: saveCount increments and saved matches items")
    func insertPersists() throws {
        let (store, _, index) = makeStore()
        store.insert(textContent("first"))
        #expect(index.saveCount == 1)
        store.insert(textContent("second"))
        #expect(index.saveCount == 2)
        #expect(index.saved.map(\.previewText) == store.items.map(\.previewText))
    }

    @Test("load restores items from the index store")
    func loadRestoresItems() throws {
        let clock = makeSequentialClock()
        let blobs = InMemoryBlobStore()
        let textData = Data("hello".utf8)
        let blobName = try blobs.write(textData, extension: "txt")
        let item = ClipboardItem(
            createdAt: Date(timeIntervalSince1970: 100),
            kind: .text,
            fingerprint: "fp",
            previewText: "hello",
            searchText: "hello",
            byteCount: 5,
            textBlob: blobName
        )
        let index = InMemoryHistoryIndexStore(initial: [item])
        let store = HistoryStore(index: index, blobs: blobs, clock: clock)
        store.load()
        #expect(store.items.count == 1)
        #expect(store.items[0].previewText == "hello")
    }

    @Test("load with a throwing index store leaves empty history and sets lastError")
    func loadWithThrowingStoreReportsError() {
        let (store, _, index) = makeStore()
        index.loadError = NSError(domain: "test", code: 99, userInfo: nil)
        store.load()
        #expect(store.items.isEmpty)
        #expect(store.lastError != nil)
    }

    // MARK: - Integrity

    @Test("isIntact returns false when a blob is deleted behind the store's back")
    func isIntactReturnsFalseForMissingBlob() throws {
        let (store, blobs, _) = makeStore()
        store.insert(textContent("hello"))
        let item = try #require(store.items.first)
        let blobName = try #require(item.textBlob)
        try blobs.delete(blobName)
        #expect(!store.isIntact(item))
    }

    @Test("removeBrokenItems drops items whose blobs have been deleted")
    func removeBrokenItems() throws {
        let (store, blobs, _) = makeStore()
        store.insert(textContent("hello"))
        store.insert(textContent("world"))
        let helloItem = try #require(store.items.first(where: { $0.previewText == "hello" }))
        let blobName = try #require(helloItem.textBlob)
        try blobs.delete(blobName)
        let removed = store.removeBrokenItems()
        #expect(removed == 1)
        #expect(store.items.count == 1)
        #expect(store.items[0].previewText == "world")
    }

    // MARK: - Aggregate metrics

    @Test("pinnedCount reports the correct number of pinned items")
    func pinnedCountReportsCorrectly() {
        let clock = makeSequentialClock()
        let (store, _, _) = makeStore(clock: clock)
        store.insert(textContent("a"))
        store.insert(textContent("b"))
        store.insert(textContent("c"))
        #expect(store.pinnedCount == 0)
        store.togglePin(store.items[0].id)
        #expect(store.pinnedCount == 1)
        store.togglePin(store.items[1].id)
        #expect(store.pinnedCount == 2)
        store.togglePin(store.items[0].id)
        #expect(store.pinnedCount == 1)
    }

    @Test("storageBytes matches the blob store total")
    func storageBytesMatchesBlobStore() throws {
        let (store, blobs, _) = makeStore()
        store.insert(textContent("hello"))
        #expect(store.storageBytes == blobs.totalBytes())
        #expect(store.storageBytes > 0)
    }
}
