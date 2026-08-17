import AppKit

/// Finder DMG backdrop: black GNFP field, cyan arrow, exact install copy.
/// Icons themselves are real Finder items; this only paints the window chrome.
let width = 1320
let height = 840
let scale: CGFloat = 2

let url = URL(fileURLWithPath: CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "pack/macos/dmg_background.png")

let image = NSImage(size: NSSize(width: CGFloat(width) / scale, height: CGFloat(height) / scale))
image.lockFocus()
let rect = NSRect(origin: .zero, size: image.size)

NSColor.black.setFill()
rect.fill()

let arrow = NSBezierPath()
let midY: CGFloat = 200
arrow.move(to: NSPoint(x: 250, y: midY))
arrow.line(to: NSPoint(x: 390, y: midY))
arrow.move(to: NSPoint(x: 360, y: midY + 22))
arrow.line(to: NSPoint(x: 400, y: midY))
arrow.line(to: NSPoint(x: 360, y: midY - 22))
arrow.lineWidth = 8
arrow.lineJoinStyle = .round
arrow.lineCapStyle = .round
NSColor(calibratedRed: 0, green: 0.90, blue: 1, alpha: 1).setStroke()
arrow.stroke()

let text = "Drag GNFP Wallet to Applications" as NSString
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
    .foregroundColor: NSColor.white,
]
let size = text.size(withAttributes: attrs)
let textRect = NSRect(
    x: (rect.width - size.width) / 2,
    y: 36,
    width: size.width,
    height: size.height
)
text.draw(in: textRect, withAttributes: attrs)
image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fputs("failed to encode PNG\n", stderr)
    exit(1)
}
try png.write(to: url)
print(url.path)
