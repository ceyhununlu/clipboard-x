import CoreGraphics

/// Conversions between the two screen coordinate systems macOS exposes.
///
/// Quartz and the Accessibility APIs report geometry with the origin at the
/// top-left corner of the primary display and y growing downward, while
/// `NSScreen`, `NSWindow` and `NSEvent.mouseLocation` use a bottom-left origin
/// with y growing upward. Both conversions are their own inverse, so feeding a
/// converted value back through the same call restores the original.
public enum ScreenGeometry {
    /// Converts a rect from Quartz/AX coordinates to Cocoa coordinates.
    ///
    /// `primaryScreenHeight` must be the height of the zero-origin display, not
    /// of the display the rect happens to sit on: Quartz measures every display
    /// from that one origin.
    public static func cocoaRect(fromQuartz rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: primaryScreenHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    /// Converts a point from Quartz/AX coordinates to Cocoa coordinates.
    public static func cocoaPoint(
        fromQuartz point: CGPoint, primaryScreenHeight: CGFloat
    ) -> CGPoint {
        CGPoint(x: point.x, y: primaryScreenHeight - point.y)
    }
}
