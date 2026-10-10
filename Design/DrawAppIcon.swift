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
ctx.translateBy(x: 520, y: 548); ctx.scaleBy(x: 1.26, y: 1.26); ctx.translateBy(x: -512, y: -580)

// Price line: falls into a dip, then climbs past where it started
let end = P(800, 300)
let line = CGMutablePath()
line.move(to: P(-80, 470))
line.addCurve(to: P(330, 774), control1: P(110, 470), control2: P(200, 774))
line.addLine(to: P(560, 774))
line.addCurve(to: end, control1: P(690, 774), control2: P(700, 300))

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
ctx.drawLinearGradient(grad([c(0x000000, 0), c(0x000000, 1)]), start: P(680, 0), end: P(end.x, 0), options: [.drawsAfterEndLocation])
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
ctx.translateBy(x: -67, y: 0)

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

// Feet first, so the toes emerge from under the body and grip the line
ctx.setStrokeColor(amber); ctx.setLineWidth(14); ctx.setLineCap(.round)
for x in [CGFloat(476), 548] {
    for dx in [CGFloat(-13), 0, 13] {
        ctx.move(to: P(x + dx * 0.6, 724)); ctx.addLine(to: P(x + dx * 1.35, 778))
    }
}
ctx.strokePath()

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 22), blur: 44, color: c(0x000000, 0.45))
ctx.addPath(owl); ctx.setFillColor(c(0xEEF3F8)); ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(owl); ctx.clip()
// Wings hug the sides, starting below the face
let leftWing = CGMutablePath()
leftWing.move(to: P(306, 520))
leftWing.addCurve(to: P(440, 756), control1: P(392, 548), control2: P(444, 670))
leftWing.addLine(to: P(240, 780)); leftWing.addLine(to: P(240, 520)); leftWing.closeSubpath()
let rightWing = CGMutablePath()
rightWing.move(to: P(718, 520))
rightWing.addCurve(to: P(584, 756), control1: P(632, 548), control2: P(580, 670))
rightWing.addLine(to: P(784, 780)); rightWing.addLine(to: P(784, 520)); rightWing.closeSubpath()
ctx.addPath(leftWing); ctx.addPath(rightWing)
ctx.setFillColor(c(0xC6D3E1)); ctx.fillPath()
// Wing feather lines
ctx.setStrokeColor(c(0xA9BACB)); ctx.setLineWidth(9); ctx.setLineCap(.round)
for (a, b, cc) in [(P(330, 600), P(372, 640), P(392, 700)), (P(694, 600), P(652, 640), P(632, 700))] {
    ctx.move(to: a); ctx.addQuadCurve(to: cc, control: b)
}
ctx.strokePath()
// Facial disc
ctx.setFillColor(c(0xFFFFFF))
ctx.fillEllipse(in: circle(P(446, 468), 84))
ctx.fillEllipse(in: circle(P(578, 468), 84))
ctx.restoreGState()

// Breast feathers
ctx.setStrokeColor(c(0xAFC0D2)); ctx.setLineWidth(9); ctx.setLineCap(.round); ctx.setLineJoin(.round)
let rows: [(CGFloat, [CGFloat])] = [(624, [486, 538]), (666, [460, 512, 564]), (708, [486, 538])]
for (y, xs) in rows {
    for x in xs {
        ctx.move(to: P(x - 15, y)); ctx.addLine(to: P(x, y + 12)); ctx.addLine(to: P(x + 15, y))
    }
}
ctx.strokePath()

// Eyes
for x in [CGFloat(446), 578] {
    ctx.setFillColor(night); ctx.fillEllipse(in: circle(P(x, 468), 56))
    ctx.setFillColor(amber); ctx.fillEllipse(in: circle(P(x, 468), 38))
    ctx.setFillColor(night); ctx.fillEllipse(in: circle(P(x, 468), 19))
    ctx.setFillColor(c(0xFFFFFF)); ctx.fillEllipse(in: circle(P(x - 14, 453), 9))
}

// Beak
let beak = CGMutablePath()
beak.move(to: P(495, 540)); beak.addLine(to: P(529, 540)); beak.addLine(to: P(512, 576)); beak.closeSubpath()
ctx.addPath(beak); ctx.setLineJoin(.round); ctx.setLineWidth(14)
ctx.setStrokeColor(amber); ctx.setFillColor(amber); ctx.drawPath(using: .fillStroke)
ctx.restoreGState()

let img = ctx.makeImage()!
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, img, nil); CGImageDestinationFinalize(dest)
