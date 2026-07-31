import AppKit
import SwiftUI

/// Transparent SwiftUI host — no opaque theme backdrop.
final class ClearHostingView<Content: View>: NSHostingView<Content> {
    required init(rootView: Content) {
        super.init(rootView: rootView)
        wantsLayer = true
        layer?.backgroundColor = .clear
        focusRingType = .none
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isOpaque: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.isOpaque = false
        window?.backgroundColor = .clear
        layer?.backgroundColor = .clear
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // Never let clicks fall through the popup into the app behind it
        // (that dismisses the panel via resign-key).
        guard bounds.contains(point) else { return nil }
        return super.hitTest(point) ?? self
    }
}

/// Rounded vibrancy plate.
///
/// Uses `NSVisualEffectView.maskImage` to clip the material. Layer
/// `cornerRadius` alone does not clip vibrancy and was the square “border”
/// leaking past the rounded corners.
final class RoundedPanelChromeView: NSView {
    static let cornerRadius: CGFloat = 12
    static let shadowPadding: CGFloat = 0

    let contentView = NSView()
    private let effectView = NSVisualEffectView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = .clear

        effectView.material = .popover
        effectView.blendingMode = .behindWindow
        effectView.state = .active
        effectView.maskImage = Self.resizableRoundedMask(cornerRadius: Self.cornerRadius)
        addSubview(effectView)

        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = .clear
        contentView.layer?.cornerRadius = Self.cornerRadius
        contentView.layer?.cornerCurve = .continuous
        contentView.layer?.masksToBounds = true
        addSubview(contentView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isOpaque: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard bounds.contains(point) else { return nil }
        return super.hitTest(point) ?? self
    }

    override func layout() {
        super.layout()
        effectView.frame = bounds
        contentView.frame = bounds
    }

    private static func resizableRoundedMask(cornerRadius: CGFloat) -> NSImage {
        let side = cornerRadius * 2 + 1
        let size = NSSize(width: side, height: side)
        let image = NSImage(size: size, flipped: false) { bounds in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: bounds, xRadius: cornerRadius, yRadius: cornerRadius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(
            top: cornerRadius,
            left: cornerRadius,
            bottom: cornerRadius,
            right: cornerRadius
        )
        image.resizingMode = .stretch
        return image
    }
}
