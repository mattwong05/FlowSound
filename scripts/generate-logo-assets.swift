#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation

enum AssetGeneratorError: Error {
    case missingSource
    case cannotLoadImage
    case cannotCreateBitmap
    case cannotWrite(URL)
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sourceURL = root.appendingPathComponent("FlowSound-iCon.png")
let outputDirectory = root.appendingPathComponent("Assets")

guard FileManager.default.fileExists(atPath: sourceURL.path) else {
    throw AssetGeneratorError.missingSource
}

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

guard let sourceImage = NSImage(contentsOf: sourceURL),
      let sourceCGImage = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    throw AssetGeneratorError.cannotLoadImage
}

let width = sourceCGImage.width
let height = sourceCGImage.height
let halfHeight = height / 2

func crop(_ rect: CGRect, from image: CGImage) throws -> CGImage {
    guard let cropped = image.cropping(to: rect) else {
        throw AssetGeneratorError.cannotCreateBitmap
    }
    return cropped
}

func write(_ image: CGImage, to name: String) throws {
    let bitmap = NSBitmapImageRep(cgImage: image)
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw AssetGeneratorError.cannotCreateBitmap
    }
    let url = outputDirectory.appendingPathComponent(name)
    do {
        try data.write(to: url)
    } catch {
        throw AssetGeneratorError.cannotWrite(url)
    }
}

let darkBackgroundLogo = try crop(
    CGRect(x: 0, y: 0, width: width, height: halfHeight),
    from: sourceCGImage
)
try write(darkBackgroundLogo, to: "FlowSoundLogoDarkBackground.png")

let lightBackgroundLogo = try crop(
    CGRect(x: 0, y: halfHeight, width: width, height: halfHeight),
    from: sourceCGImage
)
try write(lightBackgroundLogo, to: "FlowSoundLogoLightBackground.png")

// Top-left visual coordinates from the source artwork. This crop keeps only the
// wave-and-note glyph from the lower logo and excludes the wordmark.
let glyphCrop = try crop(
    CGRect(x: 335, y: 985, width: 355, height: 150),
    from: sourceCGImage
)

func makeTemplateMask(from image: CGImage) throws -> CGImage {
    let inputWidth = image.width
    let inputHeight = image.height
    let bytesPerPixel = 4
    let bytesPerRow = inputWidth * bytesPerPixel
    var pixels = [UInt8](repeating: 0, count: inputHeight * bytesPerRow)

    guard let context = CGContext(
        data: &pixels,
        width: inputWidth,
        height: inputHeight,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw AssetGeneratorError.cannotCreateBitmap
    }

    context.draw(image, in: CGRect(x: 0, y: 0, width: inputWidth, height: inputHeight))

    for index in stride(from: 0, to: pixels.count, by: bytesPerPixel) {
        let red = Double(pixels[index])
        let green = Double(pixels[index + 1])
        let blue = Double(pixels[index + 2])
        let luminance = (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
        let sourceAlpha = Double(pixels[index + 3]) / 255.0
        let alpha = max(0.0, min(255.0, (150.0 - luminance) * 3.0)) * sourceAlpha
        pixels[index] = 0
        pixels[index + 1] = 0
        pixels[index + 2] = 0
        pixels[index + 3] = UInt8(alpha.rounded())
    }

    guard let output = context.makeImage() else {
        throw AssetGeneratorError.cannotCreateBitmap
    }
    return output
}

let templateMask = try makeTemplateMask(from: glyphCrop)
try write(templateMask, to: "FlowSoundMenuBarTemplate.png")

func makeAppIcon(from image: CGImage, size: Int) throws -> CGImage {
    guard let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: size * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw AssetGeneratorError.cannotCreateBitmap
    }

    let bounds = CGRect(x: 0, y: 0, width: size, height: size)
    context.setFillColor(NSColor(calibratedRed: 0.88, green: 0.90, blue: 0.90, alpha: 1).cgColor)
    context.fill(bounds)

    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            NSColor(calibratedWhite: 0.98, alpha: 1).cgColor,
            NSColor(calibratedWhite: 0.72, alpha: 1).cgColor
        ] as CFArray,
        locations: [0, 1]
    )
    if let gradient {
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: size),
            end: CGPoint(x: size, y: 0),
            options: []
        )
    }

    let scale = min(Double(size) * 0.74 / Double(image.width), Double(size) * 0.46 / Double(image.height))
    let drawWidth = Double(image.width) * scale
    let drawHeight = Double(image.height) * scale
    let drawRect = CGRect(
        x: (Double(size) - drawWidth) / 2,
        y: (Double(size) - drawHeight) / 2,
        width: drawWidth,
        height: drawHeight
    )
    context.draw(image, in: drawRect)

    guard let output = context.makeImage() else {
        throw AssetGeneratorError.cannotCreateBitmap
    }
    return output
}

let iconsetDirectory = outputDirectory.appendingPathComponent("FlowSound.iconset", isDirectory: true)
try? FileManager.default.removeItem(at: iconsetDirectory)
try FileManager.default.createDirectory(at: iconsetDirectory, withIntermediateDirectories: true)

let iconSizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, size) in iconSizes {
    let icon = try makeAppIcon(from: glyphCrop, size: size)
    let bitmap = NSBitmapImageRep(cgImage: icon)
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw AssetGeneratorError.cannotCreateBitmap
    }
    try data.write(to: iconsetDirectory.appendingPathComponent(name))
}

print("Generated logo assets in \(outputDirectory.path)")
