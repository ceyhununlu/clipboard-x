import CoreGraphics
import Testing

@testable import ClipboardPlatform

@Suite("ScreenGeometry")
struct ScreenGeometryTests {
    private let primaryHeight: CGFloat = 900

    @Test("A rect flips around the primary screen's height")
    func rectConversion() {
        let quartz = CGRect(x: 100, y: 50, width: 200, height: 30)
        let cocoa = ScreenGeometry.cocoaRect(
            fromQuartz: quartz, primaryScreenHeight: primaryHeight
        )

        #expect(cocoa.origin.x == 100)
        #expect(cocoa.origin.y == 820)
        #expect(cocoa.size == quartz.size)
    }

    @Test("Rect conversion is its own inverse")
    func rectRoundTrip() {
        let quartz = CGRect(x: 12.5, y: 640, width: 320, height: 18)
        let cocoa = ScreenGeometry.cocoaRect(
            fromQuartz: quartz, primaryScreenHeight: primaryHeight
        )
        let back = ScreenGeometry.cocoaRect(fromQuartz: cocoa, primaryScreenHeight: primaryHeight)

        #expect(back == quartz)
    }

    @Test("A point flips around the primary screen's height")
    func pointConversion() {
        let cocoa = ScreenGeometry.cocoaPoint(
            fromQuartz: CGPoint(x: 100, y: 50), primaryScreenHeight: primaryHeight
        )

        #expect(cocoa == CGPoint(x: 100, y: 850))
    }

    @Test("Point conversion is its own inverse")
    func pointRoundTrip() {
        let quartz = CGPoint(x: -33.25, y: 712.5)
        let cocoa = ScreenGeometry.cocoaPoint(
            fromQuartz: quartz, primaryScreenHeight: primaryHeight
        )
        let back = ScreenGeometry.cocoaPoint(fromQuartz: cocoa, primaryScreenHeight: primaryHeight)

        #expect(back == quartz)
    }

    @Test("A rect on a display left of and above the primary keeps its offsets")
    func negativeOriginDisplay() {
        let quartz = CGRect(x: -1920, y: -400, width: 100, height: 20)
        let cocoa = ScreenGeometry.cocoaRect(
            fromQuartz: quartz, primaryScreenHeight: 1080
        )

        #expect(cocoa.origin.x == -1920)
        #expect(cocoa.origin.y == 1460)
        #expect(ScreenGeometry.cocoaRect(fromQuartz: cocoa, primaryScreenHeight: 1080) == quartz)
    }

    @Test("The caret of a full-height window at the top of the screen stays near the top")
    func topOfScreenStaysNearTop() {
        let quartzCaret = CGRect(x: 40, y: 30, width: 1, height: 18)
        let cocoa = ScreenGeometry.cocoaRect(
            fromQuartz: quartzCaret, primaryScreenHeight: primaryHeight
        )

        #expect(cocoa.maxY == primaryHeight - quartzCaret.minY)
    }
}
