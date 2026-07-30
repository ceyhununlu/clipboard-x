#!/usr/bin/env swift

// Renders the drag-to-Applications DMG window background.
// Usage: swift Scripts/make-dmg-background.swift <output.png>
//
// Pixel size MUST match WINDOW_WIDTH × WINDOW_HEIGHT in Scripts/package-dmg.sh.
// Finder maps the background 1:1 in points — a 2× PNG only shows its top-left
// half, which is why the chevrons were missing between the icons.
//
// Finder always draws icon labels in near-black when a background picture
// is set, so this canvas stays light for readability.

import AppKit
import Foundation

// Keep in sync with Scripts/package-dmg.sh
let windowWidth = 660
let windowHeight = 400
let appIcon = CGPoint(x: 160, y: 185)   // Finder coords (origin top-left)
let appsIcon = CGPoint(x: 500, y: 185)

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: make-dmg-background.swift <output.png>\n".utf8))
    exit(2)
}

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: windowWidth,
    pixelsHigh: windowHeight,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fatalError("cannot allocate bitmap")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

let canvas = CGRect(x: 0, y: 0, width: CGFloat(windowWidth), height: CGFloat(windowHeight))

/// Convert Finder (top-left origin) Y to AppKit (bottom-left origin) Y.
func appKitY(_ finderY: CGFloat) -> CGFloat {
    CGFloat(windowHeight) - finderY
}

NSGradient(
    colors: [
        NSColor(srgbRed: 0.94, green: 0.95, blue: 0.97, alpha: 1),
        NSColor(srgbRed: 0.88, green: 0.90, blue: 0.94, alpha: 1),
        NSColor(srgbRed: 0.91, green: 0.92, blue: 0.95, alpha: 1),
    ],
    atLocations: [0, 0.55, 1],
    colorSpace: .deviceRGB
)?.draw(in: canvas, angle: -55)

let midX = (appIcon.x + appsIcon.x) / 2
let midYFinder = (appIcon.y + appsIcon.y) / 2
let midY = appKitY(midYFinder)

let wash = NSBezierPath(
    ovalIn: CGRect(x: midX - 140, y: midY - 80, width: 280, height: 160)
)
NSGradient(
    colors: [
        NSColor(srgbRed: 0.42, green: 0.36, blue: 0.95, alpha: 0.10),
        NSColor(srgbRed: 0.42, green: 0.36, blue: 0.95, alpha: 0),
    ]
)?.draw(in: wash, angle: -90)

func drawChevron(centerX: CGFloat, centerY: CGFloat, size: CGFloat, color: NSColor) {
    let path = NSBezierPath()
    let half = size / 2
    // Pointing right, centered at (centerX, centerY) in AppKit space.
    path.move(to: CGPoint(x: centerX - size * 0.20, y: centerY + half * 0.70))
    path.line(to: CGPoint(x: centerX + size * 0.22, y: centerY))
    path.line(to: CGPoint(x: centerX - size * 0.20, y: centerY - half * 0.70))
    path.lineWidth = size * 0.14
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    color.setStroke()
    path.stroke()
}

let arrowColor = NSColor(srgbRed: 0.18, green: 0.20, blue: 0.26, alpha: 1)
let chevronSize: CGFloat = 36
// Span most of the gap between the 128px icons (edges ≈ 224 … 436).
let chevronXs: [CGFloat] = [midX - 40, midX - 12, midX + 16]
for (index, x) in chevronXs.enumerated() {
    let alpha = 0.70 + CGFloat(index) * 0.12
    drawChevron(
        centerX: x,
        centerY: midY,
        size: chevronSize,
        color: arrowColor.withAlphaComponent(min(alpha, 1))
    )
}

let caption = "Drag ClipboardX to Applications"
let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 14, weight: .medium),
    .foregroundColor: NSColor(srgbRed: 0.28, green: 0.30, blue: 0.36, alpha: 0.72),
    .paragraphStyle: paragraph,
]
let captionRect = CGRect(x: 20, y: 28, width: canvas.width - 40, height: 22)
(caption as NSString).draw(in: captionRect, withAttributes: attrs)

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("cannot encode PNG")
}

let outputURL = URL(fileURLWithPath: arguments[1])
try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try png.write(to: outputURL)
print("Wrote \(outputURL.path) (\(windowWidth)×\(windowHeight))")
