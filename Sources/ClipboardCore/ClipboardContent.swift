import CoreGraphics
import CryptoKit
import Foundation

/// A raster image read from, or destined for, the pasteboard.
///
/// Images travel as PNG bytes so that `ClipboardCore` stays free of AppKit;
/// converting to and from `NSImage` is the pasteboard adapter's job.
public struct ImagePayload: Equatable, Sendable {
    public let pngData: Data
    public let pixelWidth: Int
    public let pixelHeight: Int

    public init(pngData: Data, pixelWidth: Int, pixelHeight: Int) {
        self.pngData = pngData
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }

    public var pixelSize: CGSize {
        CGSize(width: pixelWidth, height: pixelHeight)
    }
}

public enum ClipboardKind: String, Codable, Sendable, CaseIterable {
    case text
    case richText
    case image
}

/// The value of a single clipboard change.
public enum ClipboardContent: Equatable, Sendable {
    case text(String)
    case richText(rtf: Data, plain: String)
    case image(ImagePayload)

    public var kind: ClipboardKind {
        switch self {
        case .text: .text
        case .richText: .richText
        case .image: .image
        }
    }

    /// The plain-text representation, or `nil` for images.
    public var plainText: String? {
        switch self {
        case .text(let string): string
        case .richText(_, let plain): plain
        case .image: nil
        }
    }

    public var byteCount: Int {
        switch self {
        case .text(let string): string.utf8.count
        case .richText(let rtf, let plain): rtf.count + plain.utf8.count
        case .image(let payload): payload.pngData.count
        }
    }

    /// Stable identity used for deduplication: equal fingerprints mean the user
    /// copied the same thing again.
    public var fingerprint: String {
        switch self {
        case .text(let string):
            Digest.hex(of: Data(string.utf8), domain: "text")
        case .richText(_, let plain):
            // Keyed on the plain text so that copying the same words twice from
            // an app that emits slightly different RTF still deduplicates.
            Digest.hex(of: Data(plain.utf8), domain: "text")
        case .image(let payload):
            Digest.hex(of: payload.pngData, domain: "image")
        }
    }

    /// Whether this content is worth recording. Blank text is not.
    public var isMeaningful: Bool {
        switch self {
        case .text(let string), .richText(_, let string):
            return !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .image(let payload):
            return !payload.pngData.isEmpty && payload.pixelWidth > 0 && payload.pixelHeight > 0
        }
    }
}

enum Digest {
    static func hex(of data: Data, domain: String) -> String {
        var hasher = SHA256()
        hasher.update(data: Data(domain.utf8))
        hasher.update(data: data)
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
