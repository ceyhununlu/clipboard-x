import CoreGraphics

/// Where the history panel wants to appear, in Cocoa screen coordinates.
public enum PanelAnchor: Equatable, Sendable {
    /// The caret or focused-element rect the panel should hang below.
    case belowRect(CGRect)
    /// A bare location, such as the mouse, treated as a zero-height rect.
    case atPoint(CGPoint)
    /// No usable anchor; fall back to the middle of the screen.
    case centered
}

/// Pure placement arithmetic for the history panel.
///
/// Kept free of AppKit so the flipping and clamping rules can be tested without
/// a window server: callers pass the panel size and the target screen's visible
/// frame and receive the origin to assign to the window.
public enum PanelPlacer {
    /// Breathing room between the panel and whatever it is anchored to.
    public static let gap: CGFloat = 8

    /// Returns the panel's bottom-left origin in Cocoa screen coordinates.
    ///
    /// Staying on screen outranks honouring the anchor: the panel is first
    /// placed below the anchor, flipped above it when that would run off the
    /// bottom, and finally clamped into `visibleFrame` on both axes. When the
    /// panel is larger than `visibleFrame` on an axis it is pinned to that
    /// axis' minimum rather than pushed off the opposite edge.
    public static func origin(
        panelSize: CGSize, anchor: PanelAnchor, visibleFrame: CGRect
    ) -> CGPoint {
        let preferred: CGPoint
        switch anchor {
        case .belowRect(let rect):
            preferred = belowOrigin(panelSize: panelSize, rect: rect, visibleFrame: visibleFrame)
        case .atPoint(let point):
            let rect = CGRect(origin: point, size: .zero)
            preferred = belowOrigin(panelSize: panelSize, rect: rect, visibleFrame: visibleFrame)
        case .centered:
            preferred = CGPoint(
                x: visibleFrame.minX + (visibleFrame.width - panelSize.width) / 2,
                y: visibleFrame.minY + (visibleFrame.height - panelSize.height) / 2
            )
        }
        return clamped(preferred, panelSize: panelSize, in: visibleFrame)
    }

    // MARK: - Internals

    private static func belowOrigin(
        panelSize: CGSize, rect: CGRect, visibleFrame: CGRect
    ) -> CGPoint {
        let below = rect.minY - gap - panelSize.height
        let y = below < visibleFrame.minY ? rect.maxY + gap : below
        return CGPoint(x: rect.minX, y: y)
    }

    private static func clamped(
        _ origin: CGPoint, panelSize: CGSize, in frame: CGRect
    ) -> CGPoint {
        CGPoint(
            x: clamped(origin.x, extent: panelSize.width, lower: frame.minX, upper: frame.maxX),
            y: clamped(origin.y, extent: panelSize.height, lower: frame.minY, upper: frame.maxY)
        )
    }

    private static func clamped(
        _ value: CGFloat, extent: CGFloat, lower: CGFloat, upper: CGFloat
    ) -> CGFloat {
        let maximum = upper - extent
        guard value.isFinite, maximum > lower else { return lower }
        return min(max(value, lower), maximum)
    }
}
