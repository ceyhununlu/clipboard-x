import ClipboardCore
@testable import ClipboardUI
import Foundation
import Testing

@Suite("EmojiPickerModel")
@MainActor
struct EmojiPickerModelTests {
    @Test func filtersByQueryAcrossCategories() {
        let model = EmojiPickerModel()
        // Start on smileys, then search for something outside that chip.
        model.selectedCategoryID = "smileys"
        model.query = "rocket"
        #expect(model.visibleEmoji.contains("🚀"))
        #expect(model.selectedIndex == 0)
    }

    @Test func gridNavigationWrapsWithinBounds() {
        let model = EmojiPickerModel()
        model.selectedCategoryID = "smileys"
        model.moveSelection(rows: 0, columns: 3)
        #expect(model.selectedIndex == 3)
        model.moveSelection(rows: 1, columns: 0)
        #expect(model.selectedIndex == 3 + EmojiPickerModel.columns)
        model.moveSelection(by: 10_000)
        #expect(model.selectedIndex == model.visibleEmoji.count - 1)
    }

    @Test func clearQueryRestoresCategory() {
        let model = EmojiPickerModel()
        model.selectedCategoryID = "food"
        let baseline = model.visibleEmoji.count
        model.query = "zzz-no-match"
        #expect(model.visibleEmoji.isEmpty || model.visibleEmoji.count < baseline)
        model.clearQuery()
        #expect(model.visibleEmoji.count == baseline)
    }
}

@Suite("PanelSessionModel")
@MainActor
struct PanelSessionModelTests {
    @Test func resetReturnsToClipboard() async throws {
        let paths = try temporaryPaths()
        defer { try? FileManager.default.removeItem(at: paths.root) }
        let store = HistoryStore(
            index: try FileHistoryIndexStore(url: paths.indexURL),
            blobs: try FileBlobStore(directory: paths.blobsDirectory),
            maxItems: 25
        )
        let history = HistoryPanelModel(store: store)
        let session = PanelSessionModel(history: history)
        session.mode = .emoji
        session.reset()
        #expect(session.mode == .clipboard)
    }
}

@MainActor
private func temporaryPaths() throws -> (root: URL, indexURL: URL, blobsDirectory: URL) {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ClipboardX-UITests-\(UUID().uuidString)", isDirectory: true)
    let blobs = root.appendingPathComponent("blobs", isDirectory: true)
    try FileManager.default.createDirectory(at: blobs, withIntermediateDirectories: true)
    return (root, root.appendingPathComponent("history.json"), blobs)
}
