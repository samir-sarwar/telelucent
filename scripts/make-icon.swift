// Draws the app icon and writes Resources/AppIcon.icns.
// Run with: swift scripts/make-icon.swift
import AppKit

let size: CGFloat = 1024

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.scaleBy(x: CGFloat(px) / size, y: CGFloat(px) / size)

    // Body, on Apple's 824pt grid with a soft drop shadow.
    let body = NSRect(x: 100, y: 100, width: 824, height: 824)
    let shape = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = 24
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.set()
    NSColor.black.setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    NSGradient(colors: [NSColor(srgbRed: 0.33, green: 0.30, blue: 0.85, alpha: 1),
                        NSColor(srgbRed: 0.10, green: 0.10, blue: 0.26, alpha: 1)])!
        .draw(in: body, angle: -70)

    // Camera dot near the top, where the prompter lives.
    NSColor(white: 0.02, alpha: 0.9).setFill()
    NSBezierPath(ovalIn: NSRect(x: 492, y: 826, width: 40, height: 40)).fill()
    NSColor(srgbRed: 0.35, green: 0.55, blue: 1, alpha: 0.6).setFill()
    NSBezierPath(ovalIn: NSRect(x: 504, y: 838, width: 16, height: 16)).fill()

    // The frosted pane.
    let pane = NSRect(x: 190, y: 330, width: 644, height: 440)
    let paneShape = NSBezierPath(roundedRect: pane, xRadius: 64, yRadius: 64)
    NSColor.white.withAlphaComponent(0.16).setFill()
    paneShape.fill()
    paneShape.lineWidth = 5
    NSColor.white.withAlphaComponent(0.35).setStroke()
    paneShape.stroke()

    // Lines of text, the reading line brightest, fading toward the edges.
    let lines: [(y: CGFloat, width: CGFloat, alpha: CGFloat)] = [
        (672, 440, 0.30), (592, 520, 1.0), (512, 470, 0.55), (432, 380, 0.30),
    ]
    for line in lines {
        NSColor.white.withAlphaComponent(line.alpha).setFill()
        NSBezierPath(roundedRect: NSRect(x: 290, y: line.y - 18, width: line.width, height: 36),
                     xRadius: 18, yRadius: 18).fill()
    }
    NSColor.white.withAlphaComponent(0.12).setFill()
    NSBezierPath(rect: NSRect(x: 190, y: 552, width: 644, height: 80)).fill()
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 222, y: 622))
    arrow.line(to: NSPoint(x: 258, y: 592))
    arrow.line(to: NSPoint(x: 222, y: 562))
    arrow.close()
    NSColor.white.setFill()
    arrow.fill()

    // Scroll hint under the pane.
    NSColor.white.withAlphaComponent(0.35).setFill()
    NSBezierPath(roundedRect: NSRect(x: 452, y: 236, width: 120, height: 14), xRadius: 7, yRadius: 7).fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for (name, px) in [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128),
                   ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512)] {
    try! render(px).write(to: iconset.appendingPathComponent("icon_\(name).png"))
}
try! render(512).write(to: root.appendingPathComponent("docs/icon.png"))

let out = root.appendingPathComponent("Resources/AppIcon.icns").path
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", out]
try! task.run()
task.waitUntilExit()
print("wrote \(out)")
