import Foundation

/// A persisted history entry.
///
/// Payload bytes live in the blob store; the item keeps only what the UI needs
/// to draw and search a row, so the on-disk index stays small.
public struct ClipboardItem: Identifiable, Codable, Equatable, Sendable {
    public static let previewCharacterLimit = 400

    public let id: UUID
    public var createdAt: Date
    public var kind: ClipboardKind
    public var isPinned: Bool
    public var fingerprint: String
    /// Single-line, length-capped text drawn in the row.
    public var previewText: String
    /// Lowercased text the search filter matches against.
    public var searchText: String
    public var byteCount: Int
    /// Full plain text, UTF-8 (`.txt`). Present for text and rich text.
    public var textBlob: String?
    /// Rich text bytes (`.rtf`). Present for rich text only.
    public var rtfBlob: String?
    /// Image bytes (`.png`). Present for images only.
    public var imageBlob: String?
    public var pixelWidth: Int?
    public var pixelHeight: Int?

    public init(
        id: UUID = UUID(),
        createdAt: Date,
        kind: ClipboardKind,
        isPinned: Bool = false,
        fingerprint: String,
        previewText: String,
        searchText: String,
        byteCount: Int,
        textBlob: String? = nil,
        rtfBlob: String? = nil,
        imageBlob: String? = nil,
        pixelWidth: Int? = nil,
        pixelHeight: Int? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.kind = kind
        self.isPinned = isPinned
        self.fingerprint = fingerprint
        self.previewText = previewText
        self.searchText = searchText
        self.byteCount = byteCount
        self.textBlob = textBlob
        self.rtfBlob = rtfBlob
        self.imageBlob = imageBlob
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }

    public var blobNames: [String] {
        [textBlob, rtfBlob, imageBlob].compactMap { $0 }
    }

    /// A short human-readable dimension label for image rows, e.g. `1920 × 1080`.
    public var pixelDescription: String? {
        guard let pixelWidth, let pixelHeight else { return nil }
        return "\(pixelWidth) × \(pixelHeight)"
    }
}

public enum ClipboardPreview {
    /// Collapses whitespace runs into single spaces and caps the length so that
    /// pasting a whole file does not produce a giant row.
    public static func text(from raw: String, limit: Int = ClipboardItem.previewCharacterLimit) -> String {
        let collapsed = raw
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if collapsed.count <= limit {
            return collapsed
        }
        return String(collapsed.prefix(limit)) + "…"
    }

    /// The text the filter searches. Capped far above the preview limit so long
    /// snippets remain findable without keeping megabytes in the index.
    public static func searchText(from raw: String, limit: Int = 4_000) -> String {
        String(raw.prefix(limit)).lowercased()
    }
}
