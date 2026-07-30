import AppKit
import ClipboardCore

/// Downscaled row images, cached so scrolling does not re-decode PNGs.
@MainActor
final class ThumbnailCache {
    static let shared = ThumbnailCache()

    /// Longest edge of a cached thumbnail, in points, at 2x.
    private static let maxEdge: CGFloat = 96

    private let cache = NSCache<NSString, NSImage>()

    init() {
        cache.countLimit = 256
    }

    func thumbnail(for item: ClipboardItem, data provider: () -> Data?) -> NSImage? {
        guard let key = item.imageBlob as NSString? else { return nil }
        if let cached = cache.object(forKey: key) { return cached }
        guard let data = provider(), let source = NSImage(data: data) else { return nil }
        let scaled = Self.downscale(source)
        cache.setObject(scaled, forKey: key)
        return scaled
    }

    func removeAll() {
        cache.removeAllObjects()
    }

    private static func downscale(_ image: NSImage) -> NSImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }
        let scale = min(1, maxEdge / max(size.width, size.height))
        guard scale < 1 else { return image }
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let result = NSImage(size: target)
        result.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(
            in: CGRect(origin: .zero, size: target),
            from: CGRect(origin: .zero, size: size),
            operation: .copy,
            fraction: 1
        )
        result.unlockFocus()
        return result
    }
}
