import CoreGraphics
import ImageIO
import Foundation
import UniformTypeIdentifiers

let size = 1024
let cs = CGColorSpace(name: CGColorSpace.displayP3)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
// Use top-left origin
ctx.translateBy(x: 0, y: CGFloat(size)); ctx.scaleBy(x: 1, y: -1)

func c(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [CGFloat((hex >> 16) & 0xFF)/255, CGFloat((hex >> 8) & 0xFF)/255, CGFloat(hex & 0xFF)/255, a])!
}

// Background gradient
let bg = CGGradient(colorsSpace: cs, colors: [c(0x8A63FF), c(0x5532D6), c(0x22105E)] as CFArray, locations: [0, 0.5, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 120, y: 0), end: CGPoint(x: 900, y: 1024), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

ctx.translateBy(x: 6, y: 56)
let dip = CGPoint(x: 452, y: 652)

// Amber glow beneath the dip
let glow = CGGradient(colorsSpace: cs, colors: [c(0xFFB547, 0.55), c(0xFFB547, 0)] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(glow, startCenter: dip, startRadius: 0, endCenter: dip, endRadius: 260, options: [])

// Dashed price-target line
ctx.setStrokeColor(c(0xFFFFFF, 0.32))
ctx.setLineWidth(14)
ctx.setLineCap(.round)
ctx.setLineDash(phase: 0, lengths: [2, 34])
ctx.move(to: CGPoint(x: 150, y: dip.y)); ctx.addLine(to: CGPoint(x: 874, y: dip.y))
ctx.strokePath()
ctx.setLineDash(phase: 0, lengths: [])

// Dip curve
let path = CGMutablePath()
path.move(to: CGPoint(x: 168, y: 360))
path.addCurve(to: dip, control1: CGPoint(x: 300, y: 360), control2: CGPoint(x: 340, y: dip.y))
path.addCurve(to: CGPoint(x: 862, y: 236), control1: CGPoint(x: 600, y: dip.y), control2: CGPoint(x: 700, y: 236))
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 30, color: c(0x12062F, 0.45))
ctx.addPath(path)
ctx.setStrokeColor(c(0xFFFFFF))
ctx.setLineWidth(66)
ctx.setLineJoin(.round)
ctx.strokePath()
ctx.restoreGState()

// Target dot: purple ring cut-out, then amber core
ctx.setFillColor(c(0x3A1FA0))
ctx.fillEllipse(in: CGRect(x: dip.x - 78, y: dip.y - 78, width: 156, height: 156))
let core = CGGradient(colorsSpace: cs, colors: [c(0xFFD27A), c(0xFF9F1C)] as CFArray, locations: [0, 1])!
ctx.saveGState()
ctx.addEllipse(in: CGRect(x: dip.x - 56, y: dip.y - 56, width: 112, height: 112))
ctx.clip()
ctx.drawLinearGradient(core, start: CGPoint(x: dip.x - 40, y: dip.y - 56), end: CGPoint(x: dip.x + 40, y: dip.y + 56), options: [])
ctx.restoreGState()

let img = ctx.makeImage()!
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, img, nil)
CGImageDestinationFinalize(dest)
