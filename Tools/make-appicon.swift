// Turns the source artwork into an App Store-ready icon.
//
//     swift Tools/make-appicon.swift Design/app-icon-source.png \
//         Sunfold/Assets.xcassets/AppIcon.appiconset/AppIcon.png
//
// The source is a rounded square with black corners. App Store icons must be
// full-bleed squares with no alpha and no rounded corners of their own — iOS
// applies its own mask, and a baked-in radius that does not match it leaves
// dark slivers around the edge.
//
// The corners are removed by cropping inwards until the frame sits inside the
// rounded rect. Extending the background outwards instead was tried first and
// looked worse: the artwork carries a soft inner shadow along its rounded edge,
// so smearing that edge outwards left a visible ghost of the original outline
// plus radial streaking in the corners. Cropping costs a little margin around
// the artwork and nothing else.

import AppKit
import Foundation

let outputSize = 1024

/// Crops `crop` pixels from every side, scales the result to `size`, and writes
/// a PNG with no alpha channel.
func render(_ image: NSBitmapImageRep, cropping crop: Int, to size: Int, writingTo path: String) -> Bool {
    guard let cgImage = image.cgImage else { return false }

    let side = image.pixelsWide - crop * 2
    guard side > 0 else { return false }

    let colourSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colourSpace,
        // noneSkipLast: no alpha channel at all. App Store Connect rejects
        // icons that carry one, even a fully opaque one.
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else { return false }

    guard let cropped = cgImage.cropping(to: CGRect(x: crop, y: crop, width: side, height: side))
    else { return false }

    context.interpolationQuality = .high
    context.draw(cropped, in: CGRect(x: 0, y: 0, width: size, height: size))

    guard
        let output = context.makeImage(),
        let png = NSBitmapImageRep(cgImage: output).representation(using: .png, properties: [:])
    else { return false }

    do {
        try png.write(to: URL(fileURLWithPath: path))
        print("wrote \(path) — \(size)×\(size), no alpha, \(png.count) bytes")
        return true
    } catch {
        FileHandle.standardError.write(Data("write failed: \(error)\n".utf8))
        return false
    }
}

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    FileHandle.standardError.write(Data("usage: make-appicon.swift <source.png> <out.png>\n".utf8))
    exit(2)
}

guard
    let sourceData = NSData(contentsOfFile: arguments[1]),
    let source = NSBitmapImageRep(data: sourceData as Data)
else { fatalError("cannot read \(arguments[1])") }

let width = source.pixelsWide
guard width == source.pixelsHigh else {
    fatalError("source must be square, got \(width)x\(source.pixelsHigh)")
}

/// Luminance at a pixel, used only to tell "dark corner" from "artwork".
func luminance(_ x: Int, _ y: Int) -> Double {
    guard let colour = source.colorAt(x: x, y: y) else { return 0 }
    return 0.2126 * Double(colour.redComponent)
        + 0.7152 * Double(colour.greenComponent)
        + 0.0722 * Double(colour.blueComponent)
}

// Walk the diagonal in from the top-left corner and count the dark pixels. For
// a rounded rect of radius r that run is r·(1 − 1/√2).
var diagonalRun = 0
while diagonalRun < width / 2, luminance(diagonalRun, diagonalRun) <= 0.20 {
    diagonalRun += 1
}

guard diagonalRun > 0 else {
    print("no dark corners detected; resizing only")
    exit(render(source, cropping: 0, to: outputSize, writingTo: arguments[2]) ? 0 : 1)
}

let radius = Double(diagonalRun) / (1 - 1 / 2.0.squareRoot())

// The dark run is the minimum. A little more comes off to clear the antialiased
// edge and the inner shadow that sits just inside it.
let bleed = 18
let crop = diagonalRun + bleed
let percent = String(format: "%.1f", Double(crop) / Double(width) * 100)
print("corner radius ≈ \(Int(radius))px · cropping \(crop)px per side (\(percent)%)")

exit(render(source, cropping: crop, to: outputSize, writingTo: arguments[2]) ? 0 : 1)
