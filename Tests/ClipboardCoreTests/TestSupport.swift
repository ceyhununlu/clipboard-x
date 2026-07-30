import Foundation
import Testing
@testable import ClipboardCore

// MARK: - Content factories

func textContent(_ text: String) -> ClipboardContent { .text(text) }

func richTextContent(rtf: Data = Data("rtf-payload".utf8), plain: String) -> ClipboardContent {
    .richText(rtf: rtf, plain: plain)
}

func imageContent(width: Int = 10, height: Int = 10, pngData: Data? = nil) -> ClipboardContent {
    let data = pngData ?? Data(repeating: 0xAB, count: 64)
    return .image(ImagePayload(pngData: data, pixelWidth: width, pixelHeight: height))
}

// MARK: - Store factory

@MainActor
func makeStore(
    maxItems: Int = 25,
    clock: @escaping () -> Date = { Date(timeIntervalSinceReferenceDate: 0) }
) -> (store: HistoryStore, blobs: InMemoryBlobStore, index: InMemoryHistoryIndexStore) {
    let blobs = InMemoryBlobStore()
    let index = InMemoryHistoryIndexStore()
    let store = HistoryStore(index: index, blobs: blobs, maxItems: maxItems, clock: clock)
    return (store, blobs, index)
}

// MARK: - Sequential clock

func makeSequentialClock(base: Date = Date(timeIntervalSince1970: 1_000_000)) -> () -> Date {
    var n = 0
    return {
        defer { n += 1 }
        return base.addingTimeInterval(Double(n))
    }
}

// MARK: - Pasteboard test double

final class FakePasteboard: PasteboardSource {
    var changeCount: Int = 0
    var content: ClipboardContent?
    func readContent() -> ClipboardContent? { content }
}

// MARK: - Filter item factory

func makeFilterItem(
    searchText: String,
    previewText: String = "",
    createdAt: Date = Date(timeIntervalSince1970: 0)
) -> ClipboardItem {
    ClipboardItem(
        createdAt: createdAt,
        kind: .text,
        fingerprint: UUID().uuidString,
        previewText: previewText,
        searchText: searchText,
        byteCount: searchText.utf8.count
    )
}
