import AppKit
import Foundation

// Rasterize the original ImageGen artwork into the complete macOS icon size set.
let sourceURL = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Brand/xcodefit-icon-master.png")
let output = URL(fileURLWithPath: CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "XcodeFit/XcodeFit/Assets.xcassets/AppIcon.appiconset")
guard let source = NSImage(contentsOf: sourceURL) else { fatalError("Cannot load icon artwork") }
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
func image(_ pixels: Int) -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current!.imageInterpolation = .high
    source.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels), from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}
var images: [[String: String]] = []
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let filename = "icon-\(size)@\(scale)x.png"
        try image(size * scale).write(to: output.appendingPathComponent(filename))
        images.append(["idiom": "mac", "size": "\(size)x\(size)", "scale": "\(scale)x", "filename": filename])
    }
}
try JSONSerialization.data(withJSONObject: ["images": images, "info": ["author": "xcode", "version": 1]], options: [.prettyPrinted, .sortedKeys]).write(to: output.appendingPathComponent("Contents.json"))
