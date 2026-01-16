import Cocoa
import CoreGraphics

let size = CGSize(width: 1024, height: 1024)
let img = NSImage(size: size)

img.lockFocus()

// Gradient Background
let context = NSGraphicsContext.current!.cgContext
let colors = [NSColor.systemBlue.cgColor, NSColor.systemPurple.cgColor] as CFArray
let colorSpace = CGColorSpaceCreateDeviceRGB()
let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1])!

context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 1024, y: 1024), options: [])

// Text "L"
let text = "L" as NSString
let font = NSFont.systemFont(ofSize: 600, weight: .bold)
let attrs: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor.white
]

let textSize = text.size(withAttributes: attrs)
let textRect = CGRect(
    x: (size.width - textSize.width) / 2,
    y: (size.height - textSize.height) / 2,
    width: textSize.width,
    height: textSize.height
)

text.draw(in: textRect, withAttributes: attrs)

img.unlockFocus()

if let tiff = img.tiffRepresentation,
   let bitmap = NSBitmapImageRep(data: tiff),
   let png = bitmap.representation(using: .png, properties: [:]) {
    try? png.write(to: URL(fileURLWithPath: "temp_icon.png"))
}
