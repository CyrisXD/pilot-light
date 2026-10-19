// Renders the 1200×630 social share card to site/assets/share.png. Run after changing copy or numbers:
//   swift assets/render-share.swift
// The card leads with the measured power drop (see the site's footnote 1 for the method).
import AppKit

let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let out = dir.deletingLastPathComponent().appendingPathComponent("site/assets/share.png")
guard let icon = NSImage(contentsOf: dir.appendingPathComponent("AppIcon.svg")) else { fatalError("can't load AppIcon.svg") }

let W: CGFloat = 1200, H: CGFloat = 630
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H), bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor { NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: 1) }
let ink = rgb(5, 7, 12), night = rgb(10, 16, 32), flame = rgb(255, 138, 61), text = rgb(242, 244, 248)
let muted = rgb(163, 172, 187), dim = rgb(122, 131, 146), slate = rgb(92, 111, 146), track = rgb(17, 24, 39)

NSGradient(starting: ink, ending: night)!.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -90)
NSGradient(colors: [flame.withAlphaComponent(0.22), flame.withAlphaComponent(0)])!
    .draw(fromCenter: NSPoint(x: 900, y: 360), radius: 0, toCenter: NSPoint(x: 900, y: 360), radius: 420, options: [])

func draw(_ s: String, _ font: NSFont, _ color: NSColor, at p: NSPoint, kern: CGFloat = 0) {
    NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: color, .kern: kern]).draw(at: p)
}
func width(_ s: String, _ font: NSFont, kern: CGFloat = 0) -> CGFloat {
    NSAttributedString(string: s, attributes: [.font: font, .kern: kern]).size().width
}
let bold = { (size: CGFloat) in NSFont.systemFont(ofSize: size, weight: .bold) }
let medium = { (size: CGFloat) in NSFont.systemFont(ofSize: size, weight: .medium) }
let X: CGFloat = 80

// Brand line.
icon.draw(in: NSRect(x: X - 10, y: 518, width: 76, height: 76))
draw("Pilot Light for Mac", bold(30), text, at: NSPoint(x: X + 74, y: 538))

// The numbers carry the card: 16.7 W → 4.8 W.
let big = bold(150)
let a = "16.7", b = "4.8"
var x = X - 6
draw(a, big, muted, at: NSPoint(x: x, y: 300), kern: -5); x += width(a, big, kern: -5) + 4
draw("W", bold(56), muted, at: NSPoint(x: x, y: 318)); x += width("W", bold(56)) + 28
draw("→", bold(80), dim, at: NSPoint(x: x, y: 330)); x += width("→", bold(80)) + 28
draw(b, big, flame, at: NSPoint(x: x, y: 300), kern: -5); x += width(b, big, kern: -5) + 4
draw("W", bold(56), flame, at: NSPoint(x: x, y: 318))
draw("Same MacBook. Lid closed. Agents still running.", medium(32), text, at: NSPoint(x: X, y: 250))

// Battery bars on a 24-hour scale.
func bar(_ y: CGFloat, _ label: String, _ hours: CGFloat, _ color: NSColor, _ tag: String) {
    draw(label, medium(22), muted, at: NSPoint(x: X, y: y + 2))
    let bx = X + 190, bw = W - bx - 80
    NSColor.clear.set()
    track.setFill(); NSBezierPath(roundedRect: NSRect(x: bx, y: y, width: bw, height: 22), xRadius: 11, yRadius: 11).fill()
    color.setFill(); NSBezierPath(roundedRect: NSRect(x: bx, y: y, width: bw * hours / 24, height: 22), xRadius: 11, yRadius: 11).fill()
    draw(tag, bold(22), color == flame ? flame : text, at: NSPoint(x: bx + bw * hours / 24 + 14, y: y))
}
bar(160, "Lid open", 6, slate, "~6 h")
bar(112, "Lid closed", 20.6, flame, "20+ h")

draw("Battery estimates from measured draw on a MacBook Pro M5 Max. Free and open source.", medium(19), dim, at: NSPoint(x: X, y: 50))
NSGraphicsContext.restoreGraphicsState()

try rep.representation(using: .png, properties: [:])!.write(to: out)
print("wrote", out.path)
