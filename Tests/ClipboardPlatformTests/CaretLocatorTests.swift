import ApplicationServices
import CoreGraphics
import Foundation
import Testing

@testable import ClipboardPlatform

@Suite("CaretLocation")
struct CaretLocationTests {
    @Test("A caret anchors the panel below its rect")
    func caretAnchor() {
        let rect = CGRect(x: 10, y: 20, width: 1, height: 18)
        #expect(CaretLocation.caret(rect).anchor == .belowRect(rect))
    }

    @Test("A focused element anchors the panel below its frame")
    func focusedElementAnchor() {
        let rect = CGRect(x: 0, y: 0, width: 200, height: 40)
        #expect(CaretLocation.focusedElement(rect).anchor == .belowRect(rect))
    }

    @Test("The mouse anchors the panel at the pointer")
    func mouseAnchor() {
        let point = CGPoint(x: 300, y: 400)
        #expect(CaretLocation.mouse(point).anchor == .atPoint(point))
    }

    @Test("No location centers the panel")
    func unavailableAnchor() {
        #expect(CaretLocation.unavailable.anchor == .centered)
    }
}

@Suite("CaretLocator")
@MainActor
struct CaretLocatorTests {
    @Test("Without a process to inspect it falls back to the pointer or nothing")
    func fallsBackWithoutProcess() {
        let location = CaretLocator().locate(processIdentifier: nil)

        switch location {
        case .mouse, .unavailable:
            break
        case .caret, .focusedElement:
            Issue.record("no process was given, so no AX rect should be reported")
        }
    }

    @Test("An impossible process identifier never yields an AX rect")
    func rejectsInvalidProcess() {
        let location = CaretLocator().locate(processIdentifier: -1)

        switch location {
        case .mouse, .unavailable:
            break
        case .caret, .focusedElement:
            Issue.record("pid -1 cannot have a focused element")
        }
    }

    @Test("Locating our own process is safe with or without permission")
    func locatingSelfDoesNotCrash() {
        let location = CaretLocator().locate(
            processIdentifier: ProcessInfo.processInfo.processIdentifier
        )

        switch location {
        case .caret(let rect), .focusedElement(let rect):
            #expect(rect.height > 0)
        case .mouse(let point):
            #expect(point.x.isFinite)
            #expect(point.y.isFinite)
        case .unavailable:
            #expect(location.anchor == .centered)
        }
    }
}
