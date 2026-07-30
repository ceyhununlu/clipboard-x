import Foundation
import Testing
@testable import ClipboardCore

@Suite("ClipboardContent and preview")
struct ClipboardContentTests {

    // MARK: - kind

    @Test("kind is .text for text content, .richText for rich text, .image for image")
    func kindValues() {
        #expect(ClipboardContent.text("hi").kind == .text)
        #expect(ClipboardContent.richText(rtf: Data(), plain: "hi").kind == .richText)
        #expect(ClipboardContent.image(ImagePayload(pngData: Data(), pixelWidth: 1, pixelHeight: 1)).kind == .image)
    }

    // MARK: - plainText

    @Test("plainText returns the string for text and richText, nil for image")
    func plainTextValues() {
        #expect(ClipboardContent.text("hello").plainText == "hello")
        #expect(ClipboardContent.richText(rtf: Data(), plain: "world").plainText == "world")
        let img = ClipboardContent.image(ImagePayload(pngData: Data(), pixelWidth: 1, pixelHeight: 1))
        #expect(img.plainText == nil)
    }

    // MARK: - byteCount

    @Test("byteCount reflects UTF-8 bytes for text and sum of rtf+plain for richText")
    func byteCountValues() {
        let text = "hello"
        #expect(ClipboardContent.text(text).byteCount == 5)
        let rtfData = Data(repeating: 0xAB, count: 10)
        let plain = "hi"
        #expect(ClipboardContent.richText(rtf: rtfData, plain: plain).byteCount == 12)
        let png = Data(repeating: 0xFF, count: 64)
        #expect(ClipboardContent.image(ImagePayload(pngData: png, pixelWidth: 1, pixelHeight: 1)).byteCount == 64)
    }

    // MARK: - fingerprint

    @Test("fingerprint is stable across multiple calls")
    func fingerprintStable() {
        let content = ClipboardContent.text("stable")
        #expect(content.fingerprint == content.fingerprint)
    }

    @Test("fingerprint differs between different texts")
    func fingerprintDiffers() {
        #expect(ClipboardContent.text("foo").fingerprint != ClipboardContent.text("bar").fingerprint)
    }

    @Test("fingerprint for text and image that share the same raw bytes differs due to domain separation")
    func fingerprintDomainSeparation() {
        let data = Data("bytes".utf8)
        let textFP = ClipboardContent.text("bytes").fingerprint
        let imageFP = ClipboardContent.image(ImagePayload(pngData: data, pixelWidth: 1, pixelHeight: 1)).fingerprint
        #expect(textFP != imageFP)
    }

    @Test("fingerprint for .text('x') equals fingerprint for .richText(rtf:, plain: 'x')")
    func fingerprintTextEqualsRichTextSamePlain() {
        let textFP = ClipboardContent.text("hello").fingerprint
        let richFP = ClipboardContent.richText(rtf: Data("rtf".utf8), plain: "hello").fingerprint
        #expect(textFP == richFP)
    }

    // MARK: - isMeaningful

    @Test("isMeaningful is false for empty text")
    func isMeaningfulFalseEmptyText() {
        #expect(!ClipboardContent.text("").isMeaningful)
    }

    @Test("isMeaningful is false for whitespace-only text")
    func isMeaningfulFalseWhitespaceText() {
        #expect(!ClipboardContent.text("   \n\t").isMeaningful)
        #expect(!ClipboardContent.richText(rtf: Data(), plain: "  ").isMeaningful)
    }

    @Test("isMeaningful is false for empty PNG data")
    func isMeaningfulFalseEmptyPNG() {
        let img = ClipboardContent.image(ImagePayload(pngData: Data(), pixelWidth: 10, pixelHeight: 10))
        #expect(!img.isMeaningful)
    }

    @Test("isMeaningful is false for zero-dimension images")
    func isMeaningfulFalseZeroDimension() {
        let zeroW = ClipboardContent.image(ImagePayload(pngData: Data(repeating: 1, count: 10), pixelWidth: 0, pixelHeight: 10))
        let zeroH = ClipboardContent.image(ImagePayload(pngData: Data(repeating: 1, count: 10), pixelWidth: 10, pixelHeight: 0))
        #expect(!zeroW.isMeaningful)
        #expect(!zeroH.isMeaningful)
    }

    @Test("isMeaningful is true for non-empty text and valid image")
    func isMeaningfulTrue() {
        #expect(ClipboardContent.text("hello").isMeaningful)
        let img = ClipboardContent.image(ImagePayload(pngData: Data(repeating: 1, count: 64), pixelWidth: 8, pixelHeight: 8))
        #expect(img.isMeaningful)
    }

    // MARK: - ClipboardPreview.text

    @Test("ClipboardPreview.text collapses newlines tabs and multiple spaces into single spaces")
    func previewTextCollapsesWhitespace() {
        let raw = "hello\nworld\t\t  foo"
        #expect(ClipboardPreview.text(from: raw) == "hello world foo")
    }

    @Test("ClipboardPreview.text truncates over the limit with a trailing … and exact resulting length")
    func previewTextTruncatesAtLimit() {
        let raw = String(repeating: "x", count: 450)
        let preview = ClipboardPreview.text(from: raw, limit: 400)
        #expect(preview.hasSuffix("…"))
        #expect(preview.count == 401)
    }

    @Test("ClipboardPreview.text does not truncate when within the limit")
    func previewTextNoTruncateWithinLimit() {
        let raw = String(repeating: "x", count: 300)
        let preview = ClipboardPreview.text(from: raw, limit: 400)
        #expect(preview.count == 300)
        #expect(!preview.hasSuffix("…"))
    }

    // MARK: - ClipboardPreview.searchText

    @Test("ClipboardPreview.searchText lowercases the input")
    func searchTextLowercases() {
        #expect(ClipboardPreview.searchText(from: "Hello World") == "hello world")
    }

    @Test("ClipboardPreview.searchText caps at 4000 characters")
    func searchTextCapsAt4000() {
        let raw = String(repeating: "a", count: 5000)
        let result = ClipboardPreview.searchText(from: raw)
        #expect(result.count == 4000)
    }

    // MARK: - ClipboardItem.pixelDescription

    @Test("pixelDescription formats width × height with the multiplication sign")
    func pixelDescriptionFormat() {
        let item = ClipboardItem(
            createdAt: Date(),
            kind: .image,
            fingerprint: "fp",
            previewText: "img",
            searchText: "img",
            byteCount: 64,
            pixelWidth: 1920,
            pixelHeight: 1080
        )
        #expect(item.pixelDescription == "1920 × 1080")
    }

    @Test("pixelDescription is nil when dimensions are absent")
    func pixelDescriptionNilWhenMissing() {
        let item = ClipboardItem(
            createdAt: Date(),
            kind: .image,
            fingerprint: "fp",
            previewText: "img",
            searchText: "img",
            byteCount: 64
        )
        #expect(item.pixelDescription == nil)
    }

    // MARK: - ClipboardItem.blobNames

    @Test("blobNames for a text item contains only textBlob")
    func blobNamesText() {
        let item = ClipboardItem(
            createdAt: Date(), kind: .text, fingerprint: "fp",
            previewText: "x", searchText: "x", byteCount: 1,
            textBlob: "abc.txt"
        )
        #expect(item.blobNames == ["abc.txt"])
    }

    @Test("blobNames for a richText item contains textBlob and rtfBlob")
    func blobNamesRichText() {
        let item = ClipboardItem(
            createdAt: Date(), kind: .richText, fingerprint: "fp",
            previewText: "x", searchText: "x", byteCount: 1,
            textBlob: "abc.txt", rtfBlob: "abc.rtf"
        )
        #expect(item.blobNames == ["abc.txt", "abc.rtf"])
    }

    @Test("blobNames for an image item contains only imageBlob")
    func blobNamesImage() {
        let item = ClipboardItem(
            createdAt: Date(), kind: .image, fingerprint: "fp",
            previewText: "img", searchText: "img", byteCount: 64,
            imageBlob: "img.png"
        )
        #expect(item.blobNames == ["img.png"])
    }

    @Test("blobNames is empty when all blob references are nil")
    func blobNamesEmpty() {
        let item = ClipboardItem(
            createdAt: Date(), kind: .text, fingerprint: "fp",
            previewText: "x", searchText: "x", byteCount: 1
        )
        #expect(item.blobNames.isEmpty)
    }

    // MARK: - Formatting.age

    @Test("Formatting.age returns 'now' for intervals under 45 seconds")
    func formattingAgeNow() {
        let now = Date()
        #expect(Formatting.age(of: now, now: now) == "now")
        #expect(Formatting.age(of: now.addingTimeInterval(-44), now: now) == "now")
    }

    @Test("Formatting.age returns minutes for intervals between 45s and 1h")
    func formattingAgeMinutes() {
        let now = Date()
        #expect(Formatting.age(of: now.addingTimeInterval(-60), now: now) == "1m")
        #expect(Formatting.age(of: now.addingTimeInterval(-120), now: now) == "2m")
    }

    @Test("Formatting.age returns hours for intervals between 1h and 1d")
    func formattingAgeHours() {
        let now = Date()
        #expect(Formatting.age(of: now.addingTimeInterval(-3600), now: now) == "1h")
        #expect(Formatting.age(of: now.addingTimeInterval(-7200), now: now) == "2h")
    }

    @Test("Formatting.age returns days for intervals of 1 day or more")
    func formattingAgeDays() {
        let now = Date()
        #expect(Formatting.age(of: now.addingTimeInterval(-86400), now: now) == "1d")
        #expect(Formatting.age(of: now.addingTimeInterval(-172800), now: now) == "2d")
    }

    @Test("Formatting.bytes returns a non-empty string for 0 and for large values")
    func formattingBytesNonEmpty() {
        #expect(!Formatting.bytes(0).isEmpty)
        #expect(!Formatting.bytes(1_000_000_000).isEmpty)
    }
}
