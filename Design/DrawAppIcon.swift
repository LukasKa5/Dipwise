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

let night = c(0x0A1B2E)
let mint = c(0x2FE6A0)
let amber = c(0xFFB224)

// Night-sky background
ctx.drawLinearGradient(grad([c(0x16405A), c(0x0C2438), c(0x060F1C)], [0, 0.5, 1]), start: P(300, 0), end: P(724, 1024), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

// Chart grid
ctx.setStrokeColor(c(0xFFFFFF, 0.06)); ctx.setLineWidth(4)
for y in stride(from: CGFloat(176), through: 900, by: 144) {
    ctx.move(to: P(0, y)); ctx.addLine(to: P(1024, y))
}
ctx.strokePath()

// Scale the scene up so the owl fills the icon
ctx.translateBy(x: 556, y: 548); ctx.scaleBy(x: 1.36, y: 1.36); ctx.translateBy(x: -512, y: -580)

// Price line: falls into a dip, then climbs past where it started
let end = P(752, 336)
let line = CGMutablePath()
line.move(to: P(-40, 520))
line.addCurve(to: P(442, 772), control1: P(150, 520), control2: P(220, 772))
line.addCurve(to: end, control1: P(610, 772), control2: P(670, 336))

// Area fill under the line
let area = line.mutableCopy()!
area.addLine(to: P(end.x, 1100)); area.addLine(to: P(-40, 1100)); area.closeSubpath()
ctx.beginTransparencyLayer(auxiliaryInfo: nil)
ctx.saveGState()
ctx.addPath(area); ctx.clip()
ctx.drawLinearGradient(grad([c(0x2FE6A0, 0.32), c(0x2FE6A0, 0)]), start: P(0, 300), end: P(0, 1000), options: [])
ctx.restoreGState()
// Fade the fill out toward its right edge
ctx.setBlendMode(.destinationOut)
ctx.drawLinearGradient(grad([c(0x000000, 0), c(0x000000, 1)]), start: P(640, 0), end: P(end.x, 0), options: [.drawsAfterEndLocation])
ctx.setBlendMode(.normal)
ctx.endTransparencyLayer()

ctx.saveGState()
ctx.setShadow(offset: .zero, blur: 30, color: c(0x2FE6A0, 0.6))
ctx.addPath(line); ctx.setStrokeColor(mint); ctx.setLineWidth(34); ctx.setLineCap(.round); ctx.setLineJoin(.round)
ctx.strokePath()
ctx.restoreGState()

// Live price dot
ctx.setFillColor(c(0x2FE6A0, 0.22)); ctx.fillEllipse(in: circle(end, 50))
ctx.setFillColor(mint); ctx.fillEllipse(in: circle(end, 27))
ctx.setFillColor(c(0xFFFFFF)); ctx.fillEllipse(in: circle(end, 11))

// Owl, perched at the bottom of the dip
ctx.saveGState()
ctx.translateBy(x: -70, y: 0)

// Owl body
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
ctx.setShadow(offset: CGSize(width: 0, height: 22), blur: 44, color: c(0x000000, 0.45))
ctx.addPath(owl); ctx.setFillColor(c(0xEEF3F8)); ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(owl); ctx.clip()
// Wings
ctx.setFillColor(c(0xC6D3E1))
ctx.fillEllipse(in: CGRect(x: 214, y: 470, width: 196, height: 330))
ctx.fillEllipse(in: CGRect(x: 614, y: 470, width: 196, height: 330))
// Facial disc
ctx.setFillColor(c(0xFFFFFF))
ctx.fillEllipse(in: circle(P(442, 472), 96))
ctx.fillEllipse(in: circle(P(582, 472), 96))
ctx.restoreGState()

// Breast feathers
ctx.setStrokeColor(c(0xAFC0D2)); ctx.setLineWidth(10); ctx.setLineCap(.round); ctx.setLineJoin(.round)
let rows: [(CGFloat, [CGFloat])] = [(624, [470, 554]), (668, [428, 512, 596]), (712, [470, 554])]
for (y, xs) in rows {
    for x in xs {
        ctx.move(to: P(x - 18, y)); ctx.addLine(to: P(x, y + 14)); ctx.addLine(to: P(x + 18, y))
    }
}
ctx.strokePath()

// Eyes
for x in [CGFloat(442), 582] {
    ctx.setFillColor(night); ctx.fillEllipse(in: circle(P(x, 472), 60))
    ctx.setFillColor(amber); ctx.fillEllipse(in: circle(P(x, 472), 40))
    ctx.setFillColor(night); ctx.fillEllipse(in: circle(P(x, 472), 20))
    ctx.setFillColor(c(0xFFFFFF)); ctx.fillEllipse(in: circle(P(x - 15, 456), 9))
}

// Beak
let beak = CGMutablePath()
beak.move(to: P(494, 540)); beak.addLine(to: P(530, 540)); beak.addLine(to: P(512, 578)); beak.closeSubpath()
ctx.addPath(beak); ctx.setLineJoin(.round); ctx.setLineWidth(14)
ctx.setStrokeColor(amber); ctx.setFillColor(amber); ctx.drawPath(using: .fillStroke)

// Talons gripping the line
ctx.setStrokeColor(amber); ctx.setLineWidth(12); ctx.setLineCap(.round)
for x in [CGFloat(468), 556] {
    for dx in [CGFloat(-14), 0, 14] {
        ctx.move(to: P(x + dx, 742)); ctx.addLine(to: P(x + dx * 1.3, 770))
    }
}
ctx.strokePath()
ctx.restoreGState()

let img = ctx.makeImage()!
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, img, nil); CGImageDestinationFinalize(dest)
