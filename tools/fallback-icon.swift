import AppKit
let output = CommandLine.arguments[1]
let fm = FileManager.default
try fm.createDirectory(atPath: output, withIntermediateDirectories: true)
for size in [16, 32, 64, 128, 256, 512, 1024] {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let scale = CGFloat(size) / 1024
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: scale, y: scale)
    let background = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: 1024, height: 1024), xRadius: 224, yRadius: 224)
    NSColor(srgbRed: 0.10, green: 0.48, blue: 0.41, alpha: 1).setFill()
    background.fill()
    NSColor.white.setFill()
    let outer = NSBezierPath()
    outer.move(to: NSPoint(x: 284, y: 252)); outer.line(to: NSPoint(x: 740, y: 252))
    outer.curve(to: NSPoint(x: 748, y: 280), controlPoint1: NSPoint(x: 760, y: 252), controlPoint2: NSPoint(x: 760, y: 264))
    outer.line(to: NSPoint(x: 578, y: 484)); outer.curve(to: NSPoint(x: 578, y: 540), controlPoint1: NSPoint(x: 556, y: 512), controlPoint2: NSPoint(x: 556, y: 512))
    outer.line(to: NSPoint(x: 748, y: 744)); outer.curve(to: NSPoint(x: 740, y: 772), controlPoint1: NSPoint(x: 760, y: 760), controlPoint2: NSPoint(x: 760, y: 772))
    outer.line(to: NSPoint(x: 284, y: 772)); outer.curve(to: NSPoint(x: 276, y: 744), controlPoint1: NSPoint(x: 264, y: 772), controlPoint2: NSPoint(x: 264, y: 760))
    outer.line(to: NSPoint(x: 446, y: 540)); outer.curve(to: NSPoint(x: 446, y: 484), controlPoint1: NSPoint(x: 468, y: 512), controlPoint2: NSPoint(x: 468, y: 512))
    outer.line(to: NSPoint(x: 276, y: 280)); outer.close()
    for points in [[NSPoint(x: 364, y: 316), NSPoint(x: 512, y: 494), NSPoint(x: 660, y: 316)], [NSPoint(x: 364, y: 708), NSPoint(x: 660, y: 708), NSPoint(x: 512, y: 530)]] {
        outer.move(to: points[0]); outer.line(to: points[1]); outer.line(to: points[2]); outer.close()
    }
    outer.windingRule = .evenOdd
    outer.fill()
    NSColor.white.withAlphaComponent(0.6).setFill()
    let sand = NSBezierPath()
    sand.move(to: NSPoint(x: 392, y: 352)); sand.line(to: NSPoint(x: 512, y: 476)); sand.line(to: NSPoint(x: 632, y: 352)); sand.close(); sand.fill()
    NSGraphicsContext.restoreGraphicsState()
    let data = rep.representation(using: .png, properties: [:])!
    let names: [String]
    switch size {
    case 16: names = ["icon_16x16.png"]
    case 32: names = ["icon_16x16@2x.png", "icon_32x32.png"]
    case 64: names = ["icon_32x32@2x.png"]
    case 128: names = ["icon_128x128.png"]
    case 256: names = ["icon_128x128@2x.png", "icon_256x256.png"]
    case 512: names = ["icon_256x256@2x.png", "icon_512x512.png"]
    default: names = ["icon_512x512@2x.png"]
    }
    for name in names { try data.write(to: URL(fileURLWithPath: output).appendingPathComponent(name)) }
}
