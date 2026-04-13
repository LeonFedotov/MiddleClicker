#!/usr/bin/env swift
import Cocoa

// Draw a mouse icon with filled middle button at a given size
func drawMouseIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let padding = size * 0.15
    let mouseW = size - padding * 2
    let mouseH = size - padding * 2
    let ox = padding
    let oy = padding * 0.7

    // Background circle
    let bgRect = NSRect(x: size * 0.05, y: size * 0.05, width: size * 0.9, height: size * 0.9)
    let bg = NSBezierPath(ovalIn: bgRect)
    NSColor(calibratedRed: 0.2, green: 0.2, blue: 0.25, alpha: 1).setFill()
    bg.fill()

    // Mouse body
    let bodyRect = NSRect(x: ox + mouseW * 0.15, y: oy + mouseH * 0.02, width: mouseW * 0.7, height: mouseH * 0.85)
    let cornerR = mouseW * 0.25
    let body = NSBezierPath(roundedRect: bodyRect, xRadius: cornerR, yRadius: cornerR)
    NSColor(calibratedWhite: 0.85, alpha: 1).setFill()
    body.fill()
    NSColor(calibratedWhite: 0.95, alpha: 1).setStroke()
    body.lineWidth = size * 0.02
    body.stroke()

    // Divider line
    let dividerY = oy + mouseH * 0.52
    let divider = NSBezierPath()
    divider.move(to: NSPoint(x: ox + mouseW * 0.15, y: dividerY))
    divider.line(to: NSPoint(x: ox + mouseW * 0.85, y: dividerY))
    NSColor(calibratedWhite: 0.6, alpha: 1).setStroke()
    divider.lineWidth = size * 0.015
    divider.stroke()

    // Middle button - filled
    let btnW = mouseW * 0.18
    let btnH = mouseH * 0.2
    let btnRect = NSRect(x: ox + (mouseW - btnW) / 2, y: dividerY, width: btnW, height: btnH)
    let btn = NSBezierPath(roundedRect: btnRect, xRadius: size * 0.02, yRadius: size * 0.02)
    NSColor(calibratedRed: 0.4, green: 0.7, blue: 1.0, alpha: 1).setFill()
    btn.fill()

    image.unlockFocus()
    return image
}

// Create iconset directory
let iconsetPath = "MiddleClicker.iconset"
let fm = FileManager.default
try? fm.removeItem(atPath: iconsetPath)
try! fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

// Required icon sizes: (filename, pixel size)
let sizes: [(String, CGFloat)] = [
    ("icon_16x16", 16),
    ("icon_16x16@2x", 32),
    ("icon_32x32", 32),
    ("icon_32x32@2x", 64),
    ("icon_128x128", 128),
    ("icon_128x128@2x", 256),
    ("icon_256x256", 256),
    ("icon_256x256@2x", 512),
    ("icon_512x512", 512),
    ("icon_512x512@2x", 1024),
]

for (name, px) in sizes {
    let img = drawMouseIcon(size: px)
    guard let tiff = img.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        print("Failed to generate \(name)")
        continue
    }
    let path = "\(iconsetPath)/\(name).png"
    try! png.write(to: URL(fileURLWithPath: path))
    print("Generated \(name) (\(Int(px))px)")
}

print("Converting to .icns...")
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetPath]
try! process.run()
process.waitUntilExit()

if process.terminationStatus == 0 {
    try? fm.removeItem(atPath: iconsetPath)
    print("Created MiddleClicker.icns")
} else {
    print("iconutil failed with status \(process.terminationStatus)")
}
