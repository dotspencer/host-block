#!/usr/bin/env swift
// Generates Resources/AppIcon.icns from the shield motif (green squircle + white
// shield.fill), matching the menu bar symbol. Regenerate with: scripts/make-icon.sh
import AppKit
import Foundation

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

let green = NSColor(srgbRed: 0.29, green: 0.83, blue: 0.50, alpha: 1)      // #4AD480 accent
let greenDark = NSColor(srgbRed: 0.14, green: 0.58, blue: 0.34, alpha: 1)  // darker for gradient

/// The white shield glyph rendered into its own transparent bitmap (all offscreen —
/// no window server needed), recolored white via a source-atop fill over the template.
func whiteShield(pointSize: CGFloat) -> NSImage? {
    let cfg = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .bold)
    guard let base = NSImage(systemSymbolName: "shield.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(cfg) else { return nil }
    let s = base.size
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(s.width.rounded()), pixelsHigh: Int(s.height.rounded()),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let r = NSRect(origin: .zero, size: s)
    base.draw(in: r)
    NSColor.white.set()
    r.fill(using: .sourceAtop)
    NSGraphicsContext.restoreGraphicsState()
    let out = NSImage(size: s)
    out.addRepresentation(rep)
    return out
}

func makePNG(px: Int, to url: URL) {
    let size = CGFloat(px)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Rounded-square "squircle" body on the macOS icon grid, filled with a top-down
    // green gradient.
    let inset = size * 0.092
    let body = NSRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
    let radius = body.width * 0.2237
    let bg = NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius)
    NSGraphicsContext.saveGraphicsState()
    bg.addClip()
    NSGradient(colors: [green, greenDark])!.draw(in: body, angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // White shield centered at ~52% of the icon height.
    if let glyph = whiteShield(pointSize: size) {
        let targetH = size * 0.52
        let scale = targetH / glyph.size.height
        let targetW = glyph.size.width * scale
        let rect = NSRect(x: (size - targetW) / 2, y: (size - targetH) / 2, width: targetW, height: targetH)
        glyph.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
    }

    NSGraphicsContext.restoreGraphicsState()
    if let data = rep.representation(using: .png, properties: [:]) {
        try? data.write(to: url)
    }
}

let targets: [(px: Int, name: String)] = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png"),
]
let dir = URL(fileURLWithPath: outDir, isDirectory: true)
try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
for t in targets {
    makePNG(px: t.px, to: dir.appendingPathComponent(t.name))
}
print("Wrote \(targets.count) PNGs to \(outDir)")
