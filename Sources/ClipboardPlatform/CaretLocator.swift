import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

/// Where the history panel should be anchored, and how confident we are about it.
///
/// The cases are ordered by quality: an exact caret rect is ideal, the focused
/// control's frame is acceptable, the pointer is a guess, and `unavailable`
/// means the panel has to fall back to the middle of the screen.
public enum CaretLocation: Equatable, Sendable {
    case caret(CGRect)
    case focusedElement(CGRect)
    case mouse(CGPoint)
    case unavailable

    public var anchor: PanelAnchor {
        switch self {
        case .caret(let rect), .focusedElement(let rect):
            return .belowRect(rect)
        case .mouse(let point):
            return .atPoint(point)
        case .unavailable:
            return .centered
        }
    }
}

/// Finds the text caret of another application through the Accessibility API.
///
/// Every lookup is best-effort and bounded: the caller is on the critical path
/// between the hotkey press and the panel appearing, and an unresponsive target
/// app must not stall that. Without Accessibility permission the AX queries all
/// fail silently and the pointer is used instead.
@MainActor
public final class CaretLocator {
    /// AX calls block the caller; a fifth of a second is long enough for a
    /// healthy app and short enough that a hung one is not noticeable.
    private static let messagingTimeout: Float = 0.2

    public init() {}

    public func locate(processIdentifier: pid_t?) -> CaretLocation {
        if AXIsProcessTrusted(), let pid = processIdentifier, pid > 0,
           let element = focusedElement(ofProcess: pid) {
            if let rect = caretRect(in: element) {
                return .caret(rect)
            }
            if let rect = elementRect(of: element) {
                return .focusedElement(rect)
            }
        }
        if let point = pointerLocation() {
            return .mouse(point)
        }
        return .unavailable
    }

    // MARK: - Accessibility lookups

    private func focusedElement(ofProcess pid: pid_t) -> AXUIElement? {
        let application = AXUIElementCreateApplication(pid)
        _ = AXUIElementSetMessagingTimeout(application, Self.messagingTimeout)
        return element(of: application, attribute: kAXFocusedUIElementAttribute)
    }

    private func caretRect(in element: AXUIElement) -> CGRect? {
        var rangeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element, kAXSelectedTextRangeAttribute as CFString, &rangeValue
        ) == .success, let range = rangeValue else { return nil }

        var boundsValue: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element, kAXBoundsForRangeParameterizedAttribute as CFString, range, &boundsValue
        ) == .success, let bounds = axValue(boundsValue) else { return nil }

        var rect = CGRect.zero
        guard AXValueGetValue(bounds, .cgRect, &rect), isUsable(rect) else { return nil }
        return converted(rect)
    }

    /// Falls back to position + size because `AXFrame` is not part of the
    /// documented attribute set and many apps omit it.
    private func elementRect(of element: AXUIElement) -> CGRect? {
        var origin = CGPoint.zero
        var size = CGSize.zero
        guard let positionValue = attribute(of: element, kAXPositionAttribute),
              AXValueGetValue(positionValue, .cgPoint, &origin),
              let sizeValue = attribute(of: element, kAXSizeAttribute),
              AXValueGetValue(sizeValue, .cgSize, &size) else { return nil }

        let rect = CGRect(origin: origin, size: size)
        guard isUsable(rect) else { return nil }
        return converted(rect)
    }

    private func attribute(of element: AXUIElement, _ name: String) -> AXValue? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else {
            return nil
        }
        return axValue(value)
    }

    private func element(of element: AXUIElement, attribute name: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private func axValue(_ value: CFTypeRef?) -> AXValue? {
        guard let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        return (value as! AXValue)
    }

    // MARK: - Geometry

    /// `NSEvent.mouseLocation` is already in Cocoa coordinates, so it must not go
    /// through `ScreenGeometry`. A pointer on no screen at all means we have
    /// nothing to anchor to.
    private func pointerLocation() -> CGPoint? {
        let point = NSEvent.mouseLocation
        guard point.x.isFinite, point.y.isFinite,
              NSScreen.screens.contains(where: { $0.frame.contains(point) }) else { return nil }
        return point
    }

    private func converted(_ quartzRect: CGRect) -> CGRect {
        ScreenGeometry.cocoaRect(
            fromQuartz: quartzRect,
            primaryScreenHeight: NSScreen.screens.first?.frame.height ?? 0
        )
    }

    private func isUsable(_ rect: CGRect) -> Bool {
        rect.height > 0 && rect.origin.x.isFinite && rect.origin.y.isFinite
            && rect.width.isFinite && rect.height.isFinite
    }
}
