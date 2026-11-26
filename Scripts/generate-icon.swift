import AppKit
import CoreGraphics
import Foundation

let outputDirectory: URL
if CommandLine.arguments.count > 1 {
    outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
} else {
    outputDirectory = URL(fileURLWithPath: "Resources", isDirectory: true)
}
let iconset = outputDirectory.appendingPathComponent("AppIcon.iconset", isDirectory: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func sparkle(center: CGPoint, radius: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let inner = radius * 0.18
    let points = [
        CGPoint(x: center.x, y: center.y + radius),
        CGPoint(x: center.x + inner, y: center.y + inner),
        CGPoint(x: center.x + radius, y: center.y),
        CGPoint(x: center.x + inner, y: center.y - inner),
        CGPoint(x: center.x, y: center.y - radius),
        CGPoint(x: center.x - inner, y: center.y - inner),
        CGPoint(x: center.x - radius, y: center.y),
        CGPoint(x: center.x - inner, y: center.y + inner),
    ]
    path.addLines(between: points)
    path.closeSubpath()
    return path
}

func drawIcon(in context: CGContext, size: Int) {
    context.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    context.setAllowsAntialiasing(true)
    context.interpolationQuality = .high

    let iconRect = CGRect(x: 82, y: 82, width: 860, height: 860)
    let shape = CGPath(roundedRect: iconRect, cornerWidth: 202, cornerHeight: 202, transform: nil)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -14), blur: 22, color: color(0, 73, 75, 0.22))
    context.addPath(shape)
    context.setFillColor(color(12, 169, 164))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(shape)
    context.clip()
    context.drawLinearGradient(
        CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
            color(55, 211, 195), color(11, 167, 164), color(4, 121, 137),
        ] as CFArray, locations: [0, 0.55, 1])!,
        start: CGPoint(x: 280, y: 920),
        end: CGPoint(x: 760, y: 110),
        options: []
    )

    let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
        color(255, 255, 255, 0.20), color(255, 255, 255, 0),
    ] as CFArray, locations: [0, 1])!
    context.drawRadialGradient(
        glow,
        startCenter: CGPoint(x: 340, y: 720), startRadius: 0,
        endCenter: CGPoint(x: 340, y: 720), endRadius: 500,
        options: []
    )

    context.setStrokeColor(color(255, 255, 255, 0.22))
    context.setLineWidth(3)
    context.addPath(shape)
    context.strokePath()

    let driveRect = CGRect(x: 220, y: 270, width: 584, height: 360)
    let drive = CGPath(roundedRect: driveRect, cornerWidth: 72, cornerHeight: 72, transform: nil)
    context.setShadow(offset: CGSize(width: 0, height: -10), blur: 20, color: color(0, 65, 75, 0.22))
    context.addPath(drive)
    context.setFillColor(color(255, 255, 255, 0.13))
    context.fillPath()
    context.setShadow(offset: .zero, blur: 0)
    context.setStrokeColor(color(255, 255, 255, 0.98))
    context.setLineWidth(34)
    context.addPath(drive)
    context.strokePath()

    context.setStrokeColor(color(255, 255, 255, 0.94))
    context.setLineWidth(30)
    context.setLineCap(.round)
    context.move(to: CGPoint(x: 264, y: 414))
    context.addLine(to: CGPoint(x: 760, y: 414))
    context.strokePath()

    context.setFillColor(color(255, 255, 255, 0.96))
    context.fillEllipse(in: CGRect(x: 654, y: 326, width: 32, height: 32))
    context.fillEllipse(in: CGRect(x: 710, y: 326, width: 32, height: 32))

    context.setShadow(offset: CGSize(width: 0, height: -5), blur: 12, color: color(0, 83, 88, 0.20))
    context.setFillColor(color(255, 255, 255))
    context.addPath(sparkle(center: CGPoint(x: 720, y: 720), radius: 104))
    context.fillPath()
    context.setShadow(offset: .zero, blur: 0)
    context.addPath(sparkle(center: CGPoint(x: 806, y: 820), radius: 38))
    context.fillPath()
    context.restoreGState()
}

let outputs = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (name, size) in outputs {
    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fatalError("Unable to create icon canvas")
    }
    drawIcon(in: context, size: size)
    guard let image = context.makeImage() else {
        fatalError("Unable to render icon")
    }
    let representation = NSBitmapImageRep(cgImage: image)
    guard let data = representation.representation(using: .png, properties: [:]) else {
        fatalError("Unable to encode icon")
    }
    try data.write(to: iconset.appendingPathComponent(name))
    if name == "icon_512x512@2x.png" {
        try data.write(to: outputDirectory.appendingPathComponent("AppIcon.png"))
    }
}

print(iconset.path)
