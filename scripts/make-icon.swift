// Generates AppIcon.iconset (all sizes) into the directory given as arg 1.
// Design: document -> app tile on a blue gradient squircle.
// Usage: swift scripts/make-icon.swift assets && iconutil -c icns assets/AppIcon.iconset -o assets/AppIcon.icns
import AppKit

func draw(size: CGFloat) -> NSBitmapImageRep {
    guard
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
        let context = NSGraphicsContext(bitmapImageRep: rep)
    else { fatalError("bitmap setup failed") }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let s = size / 1024.0

    // squircle background, Big Sur metrics (824pt canvas, ~185pt corners)
    let background = NSBezierPath(
        roundedRect: NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s),
        xRadius: 185 * s, yRadius: 185 * s)
    NSGradient(
        starting: NSColor(calibratedRed: 0.10, green: 0.32, blue: 0.76, alpha: 1),
        ending: NSColor(calibratedRed: 0.31, green: 0.63, blue: 0.96, alpha: 1)
    )?.draw(in: background, angle: 90)

    NSColor.white.setStroke()
    NSColor.white.setFill()

    // document (left) with three text lines
    let document = NSBezierPath(
        roundedRect: NSRect(x: 190 * s, y: 360 * s, width: 240 * s, height: 310 * s),
        xRadius: 36 * s, yRadius: 36 * s)
    document.lineWidth = 30 * s
    document.stroke()
    for (index, width) in [130.0, 130.0, 84.0].enumerated() {
        let line = NSBezierPath()
        line.move(to: NSPoint(x: 245 * s, y: (600 - Double(index) * 72) * s))
        line.line(to: NSPoint(x: (245 + width) * s, y: (600 - Double(index) * 72) * s))
        line.lineWidth = 26 * s
        line.lineCapStyle = .round
        line.stroke()
    }

    // arrow (center)
    let shaft = NSBezierPath()
    shaft.move(to: NSPoint(x: 462 * s, y: 512 * s))
    shaft.line(to: NSPoint(x: 556 * s, y: 512 * s))
    shaft.lineWidth = 34 * s
    shaft.lineCapStyle = .round
    shaft.stroke()
    let head = NSBezierPath()
    head.move(to: NSPoint(x: 518 * s, y: 562 * s))
    head.line(to: NSPoint(x: 570 * s, y: 512 * s))
    head.line(to: NSPoint(x: 518 * s, y: 462 * s))
    head.lineWidth = 34 * s
    head.lineCapStyle = .round
    head.lineJoinStyle = .round
    head.stroke()

    // app tile (right) with 2x2 dot grid
    let tile = NSBezierPath(
        roundedRect: NSRect(x: 610 * s, y: 382 * s, width: 260 * s, height: 260 * s),
        xRadius: 56 * s, yRadius: 56 * s)
    tile.lineWidth = 30 * s
    tile.stroke()
    for dx in [0.0, 1.0] {
        for dy in [0.0, 1.0] {
            let dot = NSRect(
                x: (688 + dx * 104 - 26) * s, y: (460 + dy * 104 - 26) * s,
                width: 52 * s, height: 52 * s)
            NSBezierPath(ovalIn: dot).fill()
        }
    }

    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "assets"
let iconset = "\(outDir)/AppIcon.iconset"
try FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)

let entries: [(String, CGFloat)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, size) in entries {
    guard let png = draw(size: size).representation(using: .png, properties: [:]) else {
        fatalError("png encode failed for \(name)")
    }
    try png.write(to: URL(filePath: "\(iconset)/\(name).png"))
}
print("wrote \(iconset)")
