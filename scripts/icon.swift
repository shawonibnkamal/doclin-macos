import AppKit
let output = CommandLine.arguments[1]
guard let logo = NSImage(contentsOfFile: "docs/assets/doclin-logo.png") else {
    fatalError("Original Doclin logo is missing")
}
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
logo.draw(in: NSRect(x: 0, y: 0, width: 1024, height: 1024))
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
