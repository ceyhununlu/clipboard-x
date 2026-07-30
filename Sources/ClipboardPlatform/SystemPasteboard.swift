import AppKit
import ClipboardCore
import Foundation

/// `PasteboardSource` backed by a real `NSPasteboard`.
///
/// Reading is deliberately lossy in one direction only: whatever comes off the
/// pasteboard is reduced to the three kinds `ClipboardCore` understands, and
/// anything larger than `HistoryStore.maxItemBytes` is dropped so a stray huge
/// copy never reaches the store.
///
/// `PasteboardSource` is a nonisolated protocol, but reading the pasteboard's
/// contents belongs on the main actor next to the rest of the UI; the conformance
/// is therefore `@preconcurrency`, which checks the isolation at runtime instead
/// of forcing the whole class off the main actor. `ClipboardMonitor`, the only
/// consumer of the protocol, is itself `@MainActor`.
@MainActor
public final class SystemPasteboard: @preconcurrency PasteboardSource {
    /// `changeCount` is documented as safe to read from any thread and the
    /// `PasteboardSource` requirement is nonisolated, so the pasteboard itself
    /// is held outside this class' isolation. Every other use is main-actor
    /// bound by the surrounding methods.
    private nonisolated(unsafe) let pasteboard: NSPasteboard

    /// When false, an image-only pasteboard reads as nothing at all. Mirrors the
    /// user's "capture images" preference.
    public var capturesImages = true

    public init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    public nonisolated var changeCount: Int {
        pasteboard.changeCount
    }

    // MARK: - Reading

    /// Text wins over images: apps that copy a rendered image alongside their
    /// text (spreadsheets, browsers) should still land in history as text.
    public func readContent() -> ClipboardContent? {
        if let string = meaningfulString() {
            if let rtf = pasteboard.data(forType: .rtf), !rtf.isEmpty,
               let content = sized(.richText(rtf: rtf, plain: string)) {
                return content
            }
            return sized(.text(string))
        }
        guard capturesImages, let payload = imagePayload() else { return nil }
        return sized(.image(payload))
    }

    private func meaningfulString() -> String? {
        if let string = pasteboard.string(forType: .string), isMeaningful(string) {
            return string
        }
        // A file copied in Finder carries no plain string on some paths; its path
        // is still the most useful thing we can record for it.
        guard let urlString = pasteboard.string(forType: .fileURL),
              let path = URL(string: urlString)?.path, isMeaningful(path) else { return nil }
        return path
    }

    private func isMeaningful(_ string: String) -> Bool {
        !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// PNG bytes are taken verbatim when present; anything else is rasterised so
    /// the store only ever holds PNG.
    private func imagePayload() -> ImagePayload? {
        if let png = pasteboard.data(forType: .png), let rep = NSBitmapImageRep(data: png) {
            return ImagePayload(
                pngData: png, pixelWidth: rep.pixelsWide, pixelHeight: rep.pixelsHigh
            )
        }
        if let tiff = pasteboard.data(forType: .tiff), let rep = NSBitmapImageRep(data: tiff) {
            return payload(from: rep)
        }
        guard NSImage.canInit(with: pasteboard),
              let image = NSImage(pasteboard: pasteboard),
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return payload(from: rep)
    }

    /// Pixel dimensions come from the representation rather than the image's
    /// point size, which would halve them on a Retina display.
    private func payload(from rep: NSBitmapImageRep) -> ImagePayload? {
        guard let png = rep.representation(using: .png, properties: [:]) else { return nil }
        return ImagePayload(pngData: png, pixelWidth: rep.pixelsWide, pixelHeight: rep.pixelsHigh)
    }

    private func sized(_ content: ClipboardContent) -> ClipboardContent? {
        content.byteCount <= HistoryStore.maxItemBytes ? content : nil
    }

    // MARK: - Writing

    /// Replaces the pasteboard with this content at full fidelity.
    public func write(_ content: ClipboardContent) {
        pasteboard.clearContents()
        switch content {
        case .text(let string):
            pasteboard.setString(string, forType: .string)
        case .richText(let rtf, let plain):
            pasteboard.setData(rtf, forType: .rtf)
            pasteboard.setString(plain, forType: .string)
        case .image(let payload):
            pasteboard.setData(payload.pngData, forType: .png)
            if let rep = NSBitmapImageRep(data: payload.pngData),
               let tiff = rep.representation(using: .tiff, properties: [:]) {
                pasteboard.setData(tiff, forType: .tiff)
            }
        }
    }

    /// Replaces the pasteboard with the plain-text projection of this content,
    /// which is how "paste without formatting" is implemented.
    ///
    /// Returns false and leaves the pasteboard untouched for images, which have
    /// no text to project.
    @discardableResult
    public func writePlainText(_ content: ClipboardContent) -> Bool {
        guard let plain = content.plainText else { return false }
        pasteboard.clearContents()
        pasteboard.setString(plain, forType: .string)
        return true
    }
}
