// Captures the README screenshots of a running SilkMic: notch panel, menu-bar popup and Settings.
// Usage: swift scripts/capture-screenshots.swift <out-dir> <suffix>   (suffix: light | dark)
// Needs Screen Recording permission for the app that runs it. Run through scripts/screenshots.sh.
import AppKit
import CoreGraphics
import ImageIO

let args = CommandLine.arguments
let outDir = args.count > 1 ? args[1] : "docs/screenshots"
let suffix = args.count > 2 ? args[2] : "light"

func sh(_ command: String) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/zsh")
    p.arguments = ["-c", command]
    try? p.run()
    p.waitUntilExit()
}

func wait(_ seconds: Double) { usleep(useconds_t(seconds * 1_000_000)) }

/// SilkMic's on-screen windows (top-left origin, like CGEvent coordinates).
func silkWindows() -> [(id: CGWindowID, layer: Int, bounds: CGRect)] {
    let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    return list.compactMap { info in
        guard info[kCGWindowOwnerName as String] as? String == "SilkMic",
              let id = info[kCGWindowNumber as String] as? CGWindowID,
              let layer = info[kCGWindowLayer as String] as? Int,
              let b = info[kCGWindowBounds as String] as? [String: CGFloat] else { return nil }
        return (id, layer, CGRect(x: b["X"] ?? 0, y: b["Y"] ?? 0, width: b["Width"] ?? 0, height: b["Height"] ?? 0))
    }
}

func capture(window id: CGWindowID, name: String) {
    sh("screencapture -x -o -l \(id) '\(outDir)/\(name)-\(suffix).png'")
    print("saved \(name)-\(suffix).png")
}

func capture(rect: CGRect, name: String) {
    let r = rect.integral
    sh("screencapture -x -R \(Int(r.minX)),\(Int(r.minY)),\(Int(r.width)),\(Int(r.height)) '\(outDir)/\(name)-\(suffix).png'")
    print("saved \(name)-\(suffix).png")
}

sh("mkdir -p '\(outDir)'")

/// Crops a PNG to its non-transparent pixels (window captures carry empty margins).
func trimTransparent(_ path: String) {
    guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return }
    let w = image.width, h = image.height
    var pixels = [UInt8](repeating: 0, count: w * h * 4)
    guard let ctx = CGContext(data: &pixels, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    var minX = w, minY = h, maxX = -1, maxY = -1
    for y in 0..<h { for x in 0..<w where pixels[(y * w + x) * 4 + 3] > 8 {
        minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
    } }
    guard maxX >= minX, let cropped = image.cropping(to: CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)),
          let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, "public.png" as CFString, 1, nil) else { return }
    CGImageDestinationAddImage(dest, cropped, nil)
    CGImageDestinationFinalize(dest)
}

// 1. Notch panel: open it through the app and capture only the panel (no desktop behind it).
let beforeNotch = Set(silkWindows().map(\.id))
sh("open 'silkmic://open-notch'")
wait(1.6)
if let panel = silkWindows().first(where: { !beforeNotch.contains($0.id) && $0.layer > 100 }) {
    capture(window: panel.id, name: "notch")
    trimTransparent("\(outDir)/notch-\(suffix).png")
} else {
    print("notch panel not found")
}
wait(5)

// 2. Menu-bar popup.
sh("open 'silkmic://close-windows'")
wait(0.8)
let beforePopup = Set(silkWindows().map(\.id))
sh("open 'silkmic://open-popup'")
wait(2.5)
if let popup = silkWindows().filter({ !beforePopup.contains($0.id) && $0.bounds.height > 200 }).max(by: { $0.bounds.height < $1.bounds.height }) {
    capture(window: popup.id, name: "menu")
} else {
    print("popup not found")
}
sh("open 'silkmic://close-windows'")
wait(0.8)

// 3. Settings.
// macOS does not let a background app bring itself to the front, and an unfocused window draws
// grey switches. So wait (up to a minute) for one click on the Settings window.
sh("open 'silkmic://open-settings'")
print("Click the SilkMic Settings window once…")
for _ in 0..<120 where NSWorkspace.shared.frontmostApplication?.bundleIdentifier != "app.silkmic.SilkMic" { wait(0.5) }
wait(1)
if let settings = silkWindows().filter({ $0.layer == 0 && $0.bounds.width > 500 }).first {
    capture(window: settings.id, name: "settings")
    sh("open 'silkmic://close-windows'")
} else {
    print("settings window not found")
}
