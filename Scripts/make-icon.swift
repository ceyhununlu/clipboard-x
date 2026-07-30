#!/usr/bin/env swift

// Renders ClipboardX's app icon into an .iconset directory.
// Usage: swift Scripts/make-icon.swift <output.iconset>

import AppKit
import Foundation

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: make-icon.swift <output.iconset>\n".utf8))
    exit(2)
}

let outputURL = URL(fileURLWithPath: arguments[1])
try? FileManager.default.removeItem(at: outputURL)
try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

/// Apple's macOS icon grid: the artwork occupies the middle ~80% of the canvas.
let artworkInset: CGFloat = 0.104

func squirclePath(in rect: CGRect) -> NSBezierPath {
    let radius = rect.width * 0.2237
    return NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func drawIcon(size: CGFloat) -> NSBitmapImageRep {
    let pixels = Int(size)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { fatalError("cannot allocate \(pixels)px bitmap") }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    defer { NSGraphicsContext.restoreGraphicsState() }

    let canvas = CGRect(x: 0, y: 0, width: size, height: size)
    let inset = size * artworkInset
    let plate = canvas.insetBy(dx: inset, dy: inset)

    NSColor.clear.setFill()
    canvas.fill()

    let background = squirclePath(in: plate)
    NSGradient(
        colors: [
            NSColor(srgbRed: 0.42, green: 0.36, blue: 0.95, alpha: 1),
            NSColor(srgbRed: 0.24, green: 0.20, blue: 0.72, alpha: 1),
        ]
    )?.draw(in: background, angle: -90)

    // Stacked cards behind the clipboard imply a history of copies.
    let unit = plate.width
    let cardWidth = unit * 0.46
    let cardHeight = unit * 0.60
    let cardX = plate.minX + unit * 0.20
    let cardY = plate.minY + unit * 0.18

    for (offset, alpha) in [(unit * 0.10, 0.22), (unit * 0.05, 0.38)] {
        let rect = CGRect(
            x: cardX + offset,
            y: cardY - offset,
            width: cardWidth,
            height: cardHeight
        )
        NSColor(white: 1, alpha: alpha).setFill()
        NSBezierPath(roundedRect: rect, xRadius: unit * 0.06, yRadius: unit * 0.06).fill()
    }

    let board = CGRect(x: cardX, y: cardY, width: cardWidth, height: cardHeight)
    NSColor(white: 1, alpha: 0.97).setFill()
    NSBezierPath(roundedRect: board, xRadius: unit * 0.06, yRadius: unit * 0.06).fill()

    // The clip at the top of the board.
    let clipWidth = board.width * 0.42
    let clipHeight = unit * 0.075
    let clip = CGRect(
        x: board.midX - clipWidth / 2,
        y: board.maxY - clipHeight * 0.55,
        width: clipWidth,
        height: clipHeight
    )
    NSColor(srgbRed: 0.20, green: 0.17, blue: 0.62, alpha: 1).setFill()
    NSBezierPath(roundedRect: clip, xRadius: clipHeight * 0.4, yRadius: clipHeight * 0.4).fill()

    // Content lines. Skipping small sizes keeps them from turning into mush.
    if size >= 64 {
        let lineHeight = max(1, unit * 0.035)
        let lineSpacing = unit * 0.085
        let lineX = board.minX + board.width * 0.16
        let widths: [CGFloat] = [0.68, 0.52, 0.68, 0.40]
        NSColor(srgbRed: 0.30, green: 0.27, blue: 0.45, alpha: 0.75).setFill()
        for (row, ratio) in widths.enumerated() {
            let rect = CGRect(
                x: lineX,
                y: board.maxY - clipHeight - lineSpacing * CGFloat(row + 1),
                width: board.width * ratio,
                height: lineHeight
            )
            NSBezierPath(roundedRect: rect, xRadius: lineHeight / 2, yRadius: lineHeight / 2).fill()
        }
    }

    return rep
}

let variants: [(name: String, pixels: CGFloat)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024),
]

for variant in variants {
    let rep = drawIcon(size: variant.pixels)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write(Data("failed to encode \(variant.name)\n".utf8))
        exit(1)
    }
    try data.write(to: outputURL.appendingPathComponent("\(variant.name).png"))
}

print("wrote \(variants.count) images to \(outputURL.path)")
