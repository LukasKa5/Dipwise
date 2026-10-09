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

// Background: deep violet with a soft top-left light
ctx.drawLinearGradient(grad([c(0x7B4DFF), c(0x4A22C9), c(0x1A0B52)], [0, 0.55, 1]), start: P(200, 0), end: P(824, 1024), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
ctx.drawRadialGradient(grad([c(0xB79CFF, 0.45), c(0xB79CFF, 0)]), startCenter: P(300, 180), startRadius: 0, endCenter: P(300, 180), endRadius: 620, options: [])

// Owl head: the top edge is a price chart — peak, dip, higher peak
let head = CGMutablePath()
head.move(to: P(236, 268))
head.addCurve(to: P(500, 420), control1: P(300, 300), control2: P(420, 420))
head.addCurve(to: P(796, 196), control1: P(600, 420), control2: P(730, 220))
head.addCurve(to: P(842, 560), control1: P(836, 290), control2: P(850, 430))
head.addCurve(to: P(512, 872), control1: P(832, 770), control2: P(690, 872))
head.addCurve(to: P(182, 580), control1: P(334, 872), control2: P(190, 770))
head.addCurve(to: P(236, 268), control1: P(176, 440), control2: P(196, 330))
head.closeSubpath()

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 28), blur: 60, color: c(0x0C0430, 0.55))
ctx.addPath(head); ctx.setFillColor(c(0xFFFFFF)); ctx.fillPath()
ctx.restoreGState()
ctx.saveGState()
ctx.addPath(head); ctx.clip()
ctx.drawLinearGradient(grad([c(0xFFFFFF), c(0xEDE6FF), c(0xC9B8FF)], [0, 0.55, 1]), start: P(300, 200), end: P(700, 880), options: [])
// Facial discs around the eyes
ctx.setShadow(offset: CGSize(width: 0, height: 10), blur: 24, color: c(0x5A3AC8, 0.28))
ctx.setFillColor(c(0xFFFFFF))
ctx.fillEllipse(in: circle(P(380, 588), 158))
ctx.fillEllipse(in: circle(P(644, 588), 158))
ctx.restoreGState()

// Eyes
func eye(_ p: CGPoint, look: CGPoint) {
    ctx.setFillColor(c(0x1C0C5C)); ctx.fillEllipse(in: circle(p, 112))
    let iris = P(p.x + look.x, p.y + look.y)
    ctx.saveGState()
    ctx.addEllipse(in: circle(iris, 66)); ctx.clip()
    ctx.drawRadialGradient(grad([c(0xFFE08A), c(0xFFA41B), c(0xF26B00)], [0, 0.6, 1]), startCenter: P(iris.x - 18, iris.y - 22), startRadius: 0, endCenter: iris, endRadius: 70, options: [])
    ctx.restoreGState()
    ctx.setFillColor(c(0x12073D)); ctx.fillEllipse(in: circle(iris, 30))
    ctx.setFillColor(c(0xFFFFFF, 0.95)); ctx.fillEllipse(in: circle(P(iris.x - 22, iris.y - 26), 15))
}
eye(P(380, 588), look: P(10, -6))
eye(P(644, 588), look: P(10, -6))

// Beak
let beak = CGMutablePath()
beak.move(to: P(490, 690)); beak.addLine(to: P(534, 690)); beak.addLine(to: P(512, 742)); beak.closeSubpath()
ctx.saveGState()
ctx.addPath(beak); ctx.setLineJoin(.round); ctx.setLineWidth(22); ctx.setStrokeColor(c(0xFF9A1F)); ctx.setFillColor(c(0xFF9A1F))
ctx.drawPath(using: .fillStroke)
ctx.restoreGState()

let img = ctx.makeImage()!
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, img, nil); CGImageDestinationFinalize(dest)
