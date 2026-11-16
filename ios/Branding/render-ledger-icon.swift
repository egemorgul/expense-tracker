import AppKit
// Run from ios/: swift Branding/render-ledger-icon.swift ExpenseTracker/Assets.xcassets/AppIcon.appiconset/AppIcon.png
// Draws Branding/ledger-app-icon.svg's shapes. SVG y runs down, Core Graphics y runs up.
let size: CGFloat = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
func color(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}
func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ c: CGColor) {
    let r = CGRect(x: x, y: size - y - h, width: w, height: h)
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: h / 2, cornerHeight: h / 2, transform: nil))
    ctx.setFillColor(c)
    ctx.fillPath()
}
ctx.setFillColor(color(0x141414)); ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
rect(232, 288, 403.2, 67.2, color(0xF7F7F4))
rect(232, 430, 280, 67.2, color(0xF7F7F4))
rect(232, 572, 560, 22.4, color(0xF7F7F4, 0.4))
rect(456, 669, 336, 67.2, color(0x4CC38A))
let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
