import CoreGraphics
import Testing

@testable import ClipboardPlatform

@Suite("PanelPlacer")
struct PanelPlacerTests {
    private let panel = CGSize(width: 320, height: 400)
    private let mainScreen = CGRect(x: 0, y: 25, width: 1440, height: 875)

    @Test("Hangs below the caret with a gap")
    func belowCaret() {
        let caret = CGRect(x: 200, y: 700, width: 1, height: 18)
        let origin = PanelPlacer.origin(
            panelSize: panel, anchor: .belowRect(caret), visibleFrame: mainScreen
        )

        #expect(origin.x == caret.minX)
        #expect(origin.y == caret.minY - PanelPlacer.gap - panel.height)
        #expect(origin.y + panel.height == caret.minY - PanelPlacer.gap)
    }

    @Test("Flips above the caret when there is no room below")
    func flipsAboveWhenClipped() {
        let caret = CGRect(x: 200, y: 60, width: 1, height: 18)
        let origin = PanelPlacer.origin(
            panelSize: panel, anchor: .belowRect(caret), visibleFrame: mainScreen
        )

        #expect(origin.y == caret.maxY + PanelPlacer.gap)
        #expect(origin.y >= mainScreen.minY)
        #expect(origin.y + panel.height <= mainScreen.maxY)
    }

    @Test("Clamps to the right edge")
    func clampsRight() {
        let caret = CGRect(x: 1400, y: 700, width: 1, height: 18)
        let origin = PanelPlacer.origin(
            panelSize: panel, anchor: .belowRect(caret), visibleFrame: mainScreen
        )

        #expect(origin.x == mainScreen.maxX - panel.width)
    }

    @Test("Clamps to the left edge")
    func clampsLeft() {
        let caret = CGRect(x: -80, y: 700, width: 1, height: 18)
        let origin = PanelPlacer.origin(
            panelSize: panel, anchor: .belowRect(caret), visibleFrame: mainScreen
        )

        #expect(origin.x == mainScreen.minX)
    }

    @Test("Clamps into a secondary screen with a negative origin")
    func clampsOnSecondaryScreen() {
        let secondary = CGRect(x: -1920, y: -400, width: 1920, height: 1080)
        let caret = CGRect(x: -1800, y: -380, width: 1, height: 18)
        let origin = PanelPlacer.origin(
            panelSize: panel, anchor: .belowRect(caret), visibleFrame: secondary
        )

        #expect(origin.x == caret.minX)
        #expect(origin.y == caret.maxY + PanelPlacer.gap)
        #expect(origin.y >= secondary.minY)
        #expect(origin.y + panel.height <= secondary.maxY)
    }

    @Test("A caret at the far right of a negative-origin screen clamps left")
    func clampsRightOnSecondaryScreen() {
        let secondary = CGRect(x: -1920, y: -400, width: 1920, height: 1080)
        let caret = CGRect(x: -100, y: 400, width: 1, height: 18)
        let origin = PanelPlacer.origin(
            panelSize: panel, anchor: .belowRect(caret), visibleFrame: secondary
        )

        #expect(origin.x == secondary.maxX - panel.width)
    }

    @Test("A panel bigger than the screen is pinned to the screen's corner")
    func panelLargerThanScreen() {
        let tiny = CGRect(x: -50, y: -50, width: 200, height: 200)
        let origin = PanelPlacer.origin(
            panelSize: panel, anchor: .belowRect(CGRect(x: 0, y: 0, width: 1, height: 18)),
            visibleFrame: tiny
        )

        #expect(origin.x == tiny.minX)
        #expect(origin.y == tiny.minY)
        #expect(origin.x.isFinite)
        #expect(origin.y.isFinite)
    }

    @Test("A non-finite panel size still produces a usable origin")
    func nonFinitePanelSize() {
        let origin = PanelPlacer.origin(
            panelSize: CGSize(width: CGFloat.nan, height: CGFloat.nan), anchor: .centered,
            visibleFrame: mainScreen
        )

        #expect(origin.x == mainScreen.minX)
        #expect(origin.y == mainScreen.minY)
    }

    @Test("A point anchor behaves like a zero-height rect")
    func atPoint() {
        let point = CGPoint(x: 500, y: 600)
        let origin = PanelPlacer.origin(
            panelSize: panel, anchor: .atPoint(point), visibleFrame: mainScreen
        )

        #expect(origin.x == point.x)
        #expect(origin.y == point.y - PanelPlacer.gap - panel.height)
    }

    @Test("A point near the bottom flips above the point")
    func atPointFlips() {
        let point = CGPoint(x: 500, y: 100)
        let origin = PanelPlacer.origin(
            panelSize: panel, anchor: .atPoint(point), visibleFrame: mainScreen
        )

        #expect(origin.y == point.y + PanelPlacer.gap)
    }

    @Test("Centering splits the leftover space evenly")
    func centered() {
        let origin = PanelPlacer.origin(
            panelSize: panel, anchor: .centered, visibleFrame: mainScreen
        )

        #expect(origin.x == mainScreen.minX + (mainScreen.width - panel.width) / 2)
        #expect(origin.y == mainScreen.minY + (mainScreen.height - panel.height) / 2)
    }

    @Test("Centering on a negative-origin screen stays on that screen")
    func centeredOnSecondaryScreen() {
        let secondary = CGRect(x: -1920, y: -400, width: 1920, height: 1080)
        let origin = PanelPlacer.origin(
            panelSize: panel, anchor: .centered, visibleFrame: secondary
        )

        #expect(origin.x == -1120)
        #expect(origin.y == -60)
    }
}
