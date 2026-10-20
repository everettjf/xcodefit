import AppKit
import Foundation

let output = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "XcodeSize/XcodeSize/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
func image(_ pixels: Int) -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    let shape = NSBezierPath(roundedRect: NSRect(x: 84, y: 84, width: 856, height: 856), xRadius: 191, yRadius: 191)
    NSGradient(starting: NSColor(red: 0.08, green: 0.22, blue: 0.63, alpha: 1), ending: NSColor(red: 0.25, green: 0.63, blue: 1, alpha: 1))!.draw(in: shape, angle: 75)
    NSColor.white.withAlphaComponent(0.18).setStroke(); shape.lineWidth = 3; shape.stroke()
    func slab(y: CGFloat, alpha: CGFloat, thickness: CGFloat) {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 274, y: y)); path.line(to: NSPoint(x: 497, y: y - 122)); path.curve(to: NSPoint(x: 527, y: y - 122), controlPoint1: NSPoint(x: 507, y: y - 128), controlPoint2: NSPoint(x: 517, y: y - 128)); path.line(to: NSPoint(x: 750, y: y)); path.line(to: NSPoint(x: 750, y: y - thickness)); path.line(to: NSPoint(x: 527, y: y - thickness - 122)); path.curve(to: NSPoint(x: 497, y: y - thickness - 122), controlPoint1: NSPoint(x: 517, y: y - thickness - 128), controlPoint2: NSPoint(x: 507, y: y - thickness - 128)); path.line(to: NSPoint(x: 274, y: y - thickness)); path.close()
        NSColor.white.withAlphaComponent(alpha).setFill(); path.fill()
    }
    slab(y: 421, alpha: 0.55, thickness: 40)
    slab(y: 512, alpha: 0.8, thickness: 40)
    let top = NSBezierPath()
    top.move(to: NSPoint(x: 274, y: 602)); top.line(to: NSPoint(x: 497, y: 731)); top.curve(to: NSPoint(x: 527, y: 731), controlPoint1: NSPoint(x: 507, y: 737), controlPoint2: NSPoint(x: 517, y: 737)); top.line(to: NSPoint(x: 750, y: 602)); top.line(to: NSPoint(x: 527, y: 473)); top.curve(to: NSPoint(x: 497, y: 473), controlPoint1: NSPoint(x: 517, y: 467), controlPoint2: NSPoint(x: 507, y: 467)); top.close()
    NSGradient(starting: .white, ending: NSColor(red: 0.77, green: 0.9, blue: 1, alpha: 1))!.draw(in: top, angle: -90)
    slab(y: 602, alpha: 0.85, thickness: 29)
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}
var images: [[String: String]] = []
for size in [16,32,128,256,512] {
    for scale in [1,2] {
        let filename = "icon-\(size)@\(scale)x.png"
        try image(size * scale).write(to: output.appendingPathComponent(filename))
        images.append(["idiom":"mac", "size":"\(size)x\(size)", "scale":"\(scale)x", "filename":filename])
    }
}
let json: [String: Any] = ["images":images,"info":["author":"xcode","version":1]]
try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted,.sortedKeys]).write(to: output.appendingPathComponent("Contents.json"))
