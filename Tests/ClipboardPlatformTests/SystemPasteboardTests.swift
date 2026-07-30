import AppKit
import ClipboardCore
import Testing

@testable import ClipboardPlatform

/// Every test runs against its own private pasteboard so the developer's real
/// clipboard is never touched.
@MainActor
private struct Board {
    let native: NSPasteboard
    let subject: SystemPasteboard

    init() {
        native = NSPasteboard(name: NSPasteboard.Name("com.clipboardx.tests.\(UUID().uuidString)"))
        native.clearContents()
        subject = SystemPasteboard(pasteboard: native)
    }

    func release() {
        native.releaseGlobally()
    }
}

@MainActor
private func makePNG(width: Int, height: Int) throws -> Data {
    let rep = try #require(
        NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: width * 4,
            bitsPerPixel: 32
        )
    )
    let context = try #require(NSGraphicsContext(bitmapImageRep: rep))
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    NSColor.systemTeal.setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()
    NSGraphicsContext.restoreGraphicsState()
    return try #require(rep.representation(using: .png, properties: [:]))
}

@MainActor
private func makeRTF(_ string: String) throws -> Data {
    let attributed = NSAttributedString(
        string: string, attributes: [.font: NSFont.boldSystemFont(ofSize: 13)]
    )
    return try #require(
        attributed.rtf(
            from: NSRange(location: 0, length: attributed.length), documentAttributes: [:]
        )
    )
}

@Suite("SystemPasteboard")
@MainActor
struct SystemPasteboardTests {
    @Test("Text survives a write/read round trip")
    func textRoundTrip() {
        let board = Board()
        defer { board.release() }

        board.subject.write(.text("Hello clipboard"))

        #expect(board.native.string(forType: .string) == "Hello clipboard")
        #expect(board.subject.readContent() == .text("Hello clipboard"))
    }

    @Test("Rich text reads back as rich text with its plain projection")
    func richTextRoundTrip() throws {
        let board = Board()
        defer { board.release() }
        let rtf = try makeRTF("Formatted")

        board.subject.write(.richText(rtf: rtf, plain: "Formatted"))

        let content = try #require(board.subject.readContent())
        #expect(content.kind == .richText)
        #expect(content.plainText == "Formatted")
        guard case .richText(let readRTF, _) = content else { return }
        #expect(!readRTF.isEmpty)
    }

    @Test("An image reads back as PNG with true pixel dimensions")
    func imageRoundTrip() throws {
        let board = Board()
        defer { board.release() }
        let png = try makePNG(width: 12, height: 7)

        board.subject.write(.image(ImagePayload(pngData: png, pixelWidth: 12, pixelHeight: 7)))

        let content = try #require(board.subject.readContent())
        guard case .image(let payload) = content else {
            Issue.record("expected an image, got \(content.kind)")
            return
        }
        #expect(payload.pixelWidth == 12)
        #expect(payload.pixelHeight == 7)
        #expect(NSBitmapImageRep(data: payload.pngData)?.pixelsWide == 12)
    }

    @Test("A TIFF-only pasteboard is rasterised to PNG")
    func tiffIsConvertedToPNG() throws {
        let board = Board()
        defer { board.release() }
        let rep = try #require(NSBitmapImageRep(data: try makePNG(width: 9, height: 4)))
        let tiff = try #require(rep.representation(using: .tiff, properties: [:]))

        board.native.clearContents()
        board.native.setData(tiff, forType: .tiff)

        let content = try #require(board.subject.readContent())
        guard case .image(let payload) = content else {
            Issue.record("expected an image, got \(content.kind)")
            return
        }
        #expect(payload.pixelWidth == 9)
        #expect(payload.pixelHeight == 4)
        #expect(NSBitmapImageRep(data: payload.pngData)?.representation(using: .png, properties: [:]) != nil)
    }

    @Test("Image capture can be switched off")
    func imagesIgnoredWhenDisabled() throws {
        let board = Board()
        defer { board.release() }
        let png = try makePNG(width: 4, height: 4)

        board.subject.write(.image(ImagePayload(pngData: png, pixelWidth: 4, pixelHeight: 4)))
        board.subject.capturesImages = false

        #expect(board.subject.readContent() == nil)
    }

    @Test("Text wins over an image on the same pasteboard")
    func textBeatsImage() throws {
        let board = Board()
        defer { board.release() }

        board.native.clearContents()
        board.native.setData(try makePNG(width: 4, height: 4), forType: .png)
        board.native.setString("Copied from a table", forType: .string)

        #expect(board.subject.readContent() == .text("Copied from a table"))
    }

    @Test("A blank pasteboard reads as nothing")
    func blankPasteboard() {
        let board = Board()
        defer { board.release() }

        board.native.clearContents()

        #expect(board.subject.readContent() == nil)
    }

    @Test("Whitespace-only text reads as nothing")
    func whitespaceOnly() {
        let board = Board()
        defer { board.release() }

        board.subject.write(.text("   \n\t "))

        #expect(board.subject.readContent() == nil)
    }

    @Test("writePlainText strips the formatting off rich text")
    func writePlainTextStripsRTF() throws {
        let board = Board()
        defer { board.release() }
        let rtf = try makeRTF("Formatted")

        board.subject.write(.richText(rtf: rtf, plain: "Formatted"))
        #expect(board.subject.writePlainText(.richText(rtf: rtf, plain: "Formatted")))

        #expect(board.native.data(forType: .rtf) == nil)
        #expect(board.subject.readContent() == .text("Formatted"))
    }

    @Test("writePlainText refuses images and leaves the pasteboard alone")
    func writePlainTextRejectsImages() throws {
        let board = Board()
        defer { board.release() }
        let payload = ImagePayload(
            pngData: try makePNG(width: 4, height: 4), pixelWidth: 4, pixelHeight: 4
        )

        board.subject.write(.image(payload))
        let countAfterWrite = board.subject.changeCount

        #expect(board.subject.writePlainText(.image(payload)) == false)
        #expect(board.subject.changeCount == countAfterWrite)
        #expect(board.subject.readContent()?.kind == .image)
    }

    @Test("changeCount advances on every write")
    func changeCountAdvances() {
        let board = Board()
        defer { board.release() }

        let before = board.subject.changeCount
        board.subject.write(.text("one"))
        let afterFirst = board.subject.changeCount
        board.subject.write(.text("two"))

        #expect(afterFirst > before)
        #expect(board.subject.changeCount > afterFirst)
        #expect(board.subject.changeCount == board.native.changeCount)
    }

    @Test("Oversized text is rejected rather than handed to the store")
    func oversizedPayloadRejected() {
        let board = Board()
        defer { board.release() }
        let huge = String(repeating: "x", count: HistoryStore.maxItemBytes + 1)

        board.subject.write(.text(huge))

        #expect(board.subject.readContent() == nil)
    }
}
