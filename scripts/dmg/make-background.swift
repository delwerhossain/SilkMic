// Draws the DMG window background (660×420 pt, 1x and 2x; content sits in the top 310 pt so it still fits when Finder shows its tab and status bars): soft silk-violet light, an arrow from
// the app icon to Applications, and one line of instructions.
// Usage: swift scripts/dmg/make-background.swift scripts/dmg
import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "scripts/dmg"
let size = NSSize(width: 660, height: 420)
let violet = NSColor(srgbRed: 123 / 255, green: 97 / 255, blue: 1, alpha: 1)
let fuchsia = NSColor(srgbRed: 225 / 255, green: 92 / 255, blue: 1, alpha: 1)
let sky = NSColor(srgbRed: 76 / 255, green: 201 / 255, blue: 240 / 255, alpha: 1)

func render(scale: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    // Base: near-white lavender.
    NSColor(srgbRed: 0.975, green: 0.967, blue: 1, alpha: 1).setFill()
    NSRect(origin: .zero, size: size).fill()

    // Soft aurora glows.
    func glow(_ color: NSColor, _ center: NSPoint, _ radius: CGFloat, _ alpha: CGFloat) {
        let gradient = NSGradient(colors: [color.withAlphaComponent(alpha), color.withAlphaComponent(0)])!
        gradient.draw(fromCenter: center, radius: 0, toCenter: center, radius: radius, options: [])
    }
    glow(violet, NSPoint(x: 110, y: size.height - 70), 330, 0.30)
    glow(fuchsia, NSPoint(x: 600, y: size.height - 40), 260, 0.18)
    glow(sky, NSPoint(x: 520, y: 40), 300, 0.20)

    // Arrow between the icons (icons sit at x 170 and 490, y 175 in Finder's top-left coordinates).
    let y: CGFloat = size.height - 175
    let arrow = NSBezierPath()
    arrow.move(to: NSPoint(x: 262, y: y))
    arrow.line(to: NSPoint(x: 392, y: y))
    arrow.lineWidth = 3
    arrow.lineCapStyle = .round
    violet.withAlphaComponent(0.55).setStroke()
    let dash: [CGFloat] = [2, 9]
    arrow.setLineDash(dash, count: 2, phase: 0)
    arrow.stroke()
    let head = NSBezierPath()
    head.move(to: NSPoint(x: 384, y: y + 9))
    head.line(to: NSPoint(x: 398, y: y))
    head.line(to: NSPoint(x: 384, y: y - 9))
    head.lineWidth = 3
    head.lineCapStyle = .round
    head.lineJoinStyle = .round
    head.stroke()

    // Title and instruction.
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let title: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 22, weight: .semibold),
        .foregroundColor: NSColor(srgbRed: 0.16, green: 0.13, blue: 0.3, alpha: 1),
        .paragraphStyle: paragraph,
    ]
    let body: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 13, weight: .regular),
        .foregroundColor: NSColor(srgbRed: 0.33, green: 0.3, blue: 0.48, alpha: 1),
        .paragraphStyle: paragraph,
    ]
    NSAttributedString(string: "Install SilkMic", attributes: title)
        .draw(in: NSRect(x: 0, y: size.height - 58, width: size.width, height: 30))
    NSAttributedString(string: "Drag SilkMic onto the Applications folder", attributes: body)
        .draw(in: NSRect(x: 0, y: size.height - 84, width: size.width, height: 20))
    NSAttributedString(string: "Then open it from Applications. First launch: System Settings → Privacy & Security → Open Anyway.",
                       attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor(srgbRed: 0.4, green: 0.38, blue: 0.52, alpha: 1), .paragraphStyle: paragraph])
        .draw(in: NSRect(x: 30, y: size.height - 300, width: size.width - 60, height: 18))
    _ = ctx
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

for (scale, name) in [(CGFloat(1), "background.png"), (CGFloat(2), "background@2x.png")] {
    let data = render(scale: scale).representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
    print("wrote \(outDir)/\(name)")
}
