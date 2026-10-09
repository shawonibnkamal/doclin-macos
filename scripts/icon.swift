import AppKit
let output = CommandLine.arguments[1]
guard let logo = NSImage(contentsOfFile: "docs/assets/doclin-logo.png") else {
    fatalError("Original Doclin logo is missing")
}
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
NSGraphicsContext.current?.imageInterpolation = .high
// Match macOS app icons: the tile occupies about 80% of the canvas,
// leaving transparent margins for the Dock's consistent optical sizing.
let tile = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824),
                        xRadius: 184, yRadius: 184)
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
shadow.shadowBlurRadius = 16
shadow.shadowOffset = NSSize(width: 0, height: -8)
shadow.set()
NSColor.white.setFill()
tile.fill()
NSGraphicsContext.restoreGraphicsState()
NSGradient(starting: NSColor(calibratedWhite: 1, alpha: 1),
           ending: NSColor(calibratedRed: 0.91, green: 0.95, blue: 1, alpha: 1))!
    .draw(in: tile, angle: -90)
NSColor(calibratedRed: 0.78, green: 0.85, blue: 0.93, alpha: 0.6).setStroke()
tile.lineWidth = 2
tile.stroke()
logo.draw(in: NSRect(x: 202, y: 202, width: 620, height: 620))
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
