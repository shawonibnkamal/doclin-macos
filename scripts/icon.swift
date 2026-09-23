import AppKit
let output = CommandLine.arguments[1]
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
let bg = NSBezierPath(roundedRect: NSRect(x: 60, y: 60, width: 904, height: 904), xRadius: 205, yRadius: 205)
NSColor(calibratedRed: 0.10, green: 0.14, blue: 0.18, alpha: 1).setFill(); bg.fill()
let heights: [CGFloat] = [130, 270, 430, 320, 170]
NSColor(calibratedRed: 0.78, green: 0.88, blue: 0.68, alpha: 1).setFill()
for (i, h) in heights.enumerated() {
 let bar = NSBezierPath(roundedRect: NSRect(x: 280 + CGFloat(i) * 100, y: (1024 - h) / 2, width: 64, height: h), xRadius: 32, yRadius: 32); bar.fill()
}
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
