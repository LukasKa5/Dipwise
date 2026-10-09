import CoreGraphics
import ImageIO
import Foundation
import UniformTypeIdentifiers

let size = 1024
let cs = CGColorSpace(name: CGColorSpace.displayP3)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
ctx.translateBy(x: 0, y: CGFloat(size)); ctx.scaleBy(x: 1, y: -1)

func c(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [CGFloat((hex >> 16) & 0xFF)/255, CGFloat((hex >> 8) & 0xFF)/255, CGFloat(hex & 0xFF)/255, a])!
}
func grad(_ colors: [CGColor], _ locs: [CGFloat]? = nil) -> CGGradient {
    CGGradient(colorsSpace: cs, colors: colors as CFArray, locations: locs)!
}
func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
func circle(_ p: CGPoint, _ r: CGFloat) -> CGRect { CGRect(x: p.x - r, y: p.y - r, width: 2*r, height: 2*r) }

let navy = c(0x1E0E5C)
let amber = c(0xFFAE1F)

// Background
ctx.drawLinearGradient(grad([c(0x7A4DFF), c(0x4B23CC), c(0x23106B)], [0, 0.55, 1]), start: P(256, 0), end: P(768, 1024), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

ctx.translateBy(x: 0, y: -44)
// Stock line: falls into a dip, then climbs higher
let line = CGMutablePath()
line.move(to: P(-40, 540))
line.addCurve(to: P(512, 772), control1: P(180, 520), control2: P(250, 772))
line.addCurve(to: P(1064, 220), control1: P(774, 772), control2: P(860, 220))
ctx.addPath(line)
ctx.setStrokeColor(amber); ctx.setLineWidth(40); ctx.setLineCap(.round)
ctx.strokePath()

// Owl perched in the dip
let owl = CGMutablePath()
owl.move(to: P(346, 296))
owl.addCurve(to: P(512, 352), control1: P(396, 324), control2: P(452, 352))
owl.addCurve(to: P(678, 296), control1: P(572, 352), control2: P(628, 324))
owl.addCurve(to: P(716, 556), control1: P(716, 380), control2: P(726, 466))
owl.addCurve(to: P(512, 752), control1: P(704, 680), control2: P(626, 752))
owl.addCurve(to: P(308, 556), control1: P(398, 752), control2: P(320, 680))
owl.addCurve(to: P(346, 296), control1: P(298, 466), control2: P(308, 380))
owl.closeSubpath()
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 20), blur: 44, color: c(0x0C0430, 0.45))
ctx.addPath(owl); ctx.setFillColor(c(0xFFFFFF)); ctx.fillPath()
ctx.restoreGState()

// Eyes
for x in [CGFloat(440), 584] {
    ctx.setFillColor(navy); ctx.fillEllipse(in: circle(P(x, 476), 60))
    ctx.setFillColor(amber); ctx.fillEllipse(in: circle(P(x, 476), 26))
}

// Beak
let beak = CGMutablePath()
beak.move(to: P(494, 548)); beak.addLine(to: P(530, 548)); beak.addLine(to: P(512, 584)); beak.closeSubpath()
ctx.addPath(beak); ctx.setLineJoin(.round); ctx.setLineWidth(16)
ctx.setStrokeColor(amber); ctx.setFillColor(amber); ctx.drawPath(using: .fillStroke)

// Wing lines
ctx.setStrokeColor(c(0xD9CCFF)); ctx.setLineWidth(18); ctx.setLineCap(.round)
let wings = CGMutablePath()
wings.move(to: P(372, 600)); wings.addQuadCurve(to: P(436, 700), control: P(380, 670))
wings.move(to: P(652, 600)); wings.addQuadCurve(to: P(588, 700), control: P(644, 670))
ctx.addPath(wings); ctx.strokePath()

// Feet gripping the line
ctx.setFillColor(amber)
for x in [CGFloat(470), 554] {
    ctx.fillEllipse(in: CGRect(x: x - 26, y: 744, width: 52, height: 30))
}

let img = ctx.makeImage()!
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, img, nil); CGImageDestinationFinalize(dest)
