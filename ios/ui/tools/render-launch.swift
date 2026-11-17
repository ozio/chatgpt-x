// Renders the ChatGPT X launch images from the RCLaunchView layout (keep in sync
// with ios/ui/RCLaunchView.m and RCWelcomeViewController +logoImage):
//   swift ios/ui/tools/render-launch.swift "$PWD" ios/chat/Resources
// Writes Default.png (320×480), Default@2x.png (640×960) and Default-568h@2x.png
// (640×1136). The system draws its status bar over the top 20 pt; the app's root
// view starts below it, so the layout is in view coordinates shifted by 20 pt and
// the linen pattern starts at the view origin, as UIKit draws it. Only the mark is
// drawn: no title or status text (user decision, 10 November 2026).
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count == 3 else { fatalError("usage: render-launch.swift <repo> <output-dir>") }
let repo = URL(fileURLWithPath: args[1]), outDir = URL(fileURLWithPath: args[2])

func load(_ path: String) -> CGImage {
    let url = repo.appendingPathComponent(path)
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil), let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { fatalError("cannot read \(path)") }
    return img
}
func rgba(_ v: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: a)
}
let linen = load("ios/ui/Resources/rc-linen-dark.png")       // 128 px, loaded at scale 1 => 128 pt tile
let markArt = load("ios/ui/Resources/rc-mark-embossed-white@2x.png") // 288 px => 144 pt, drawn at 104 pt

// Draws an image upright into a rect of a top-left (UIKit-like) context.
func put(_ c: CGContext, _ img: CGImage, _ r: CGRect) {
    c.saveGState(); c.translateBy(x: r.minX, y: r.maxY); c.scaleBy(x: 1, y: -1)
    c.draw(img, in: CGRect(origin: .zero, size: r.size)); c.restoreGState()
}

func render(width: CGFloat, height: CGFloat, scale: CGFloat, name: String) {
    let pw = Int(width * scale), ph = Int(height * scale)
    let space = CGColorSpaceCreateDeviceRGB()
    guard let c = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { fatalError() }
    c.translateBy(x: 0, y: CGFloat(ph)); c.scaleBy(x: scale, y: -scale) // points, origin top-left
    c.interpolationQuality = .medium
    let statusBar: CGFloat = 20, h = height - statusBar, w = width
    c.translateBy(x: 0, y: statusBar)                                   // root view coordinates

    // dark linen (UIColor colorWithPatternImage:), phase at the view origin
    c.setFillColor(rgba(0x1e4838)); c.fill(CGRect(x: 0, y: -statusBar, width: w, height: height))
    let t = CGFloat(linen.width)
    var y = -t
    while y < h { var x: CGFloat = 0; while x < w { put(c, linen, CGRect(x: x, y: y, width: t, height: t)); x += t }; y += t }

    // light: vignette, then the jade spotlight around the mark; RCLaunchView
    // +logoTopForHeight: puts the mark centre (canvas 54, 52) on the middle of the view
    let top = (h / 2).rounded() - 52
    let mid = CGPoint(x: w / 2, y: h / 2)
    let vignette = CGGradient(colorSpace: space, colorComponents: [0, 0, 0, 0, 0, 0, 0, 0.45], locations: [0.55, 1], count: 2)!
    c.drawRadialGradient(vignette, startCenter: mid, startRadius: 0, endCenter: mid, endRadius: 0.65 * h, options: [.drawsAfterEndLocation])
    let r = CGFloat(0x3f) / 255, g = CGFloat(0xd0) / 255, b = CGFloat(0x8a) / 255
    let spot = CGGradient(colorSpace: space, colorComponents: [r, g, b, 0.28, r, g, b, 0], locations: [0, 1], count: 2)!
    let centre = CGPoint(x: w / 2, y: top + 52)
    c.drawRadialGradient(spot, startCenter: centre, startRadius: 0, endCenter: centre, endRadius: 170, options: [])

    // logo: RCWelcomeViewController +logoImage (108×110 canvas): the bare white embossed
    // mark, 104 pt at (2, 0), no tile, clip, stroke or drop shadow (the artwork has its own)
    let canvas = CGPoint(x: ((w - 108) / 2).rounded(), y: top)
    put(c, markArt, CGRect(x: canvas.x + 2, y: canvas.y, width: 104, height: 104))

    let url = outDir.appendingPathComponent(name)
    guard let img = c.makeImage(), let dst = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { fatalError() }
    CGImageDestinationAddImage(dst, img, nil)
    guard CGImageDestinationFinalize(dst) else { fatalError("cannot write \(url.path)") }
    print("\(name) \(pw)x\(ph)")
}

render(width: 320, height: 480, scale: 1, name: "Default.png")
render(width: 320, height: 480, scale: 2, name: "Default@2x.png")
render(width: 320, height: 568, scale: 2, name: "Default-568h@2x.png")
