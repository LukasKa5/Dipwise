import SwiftUI

/// Dipwise's own wallpaper for the iPhones it shows: a bright morning sky fading through mint into a warm glow,
/// with a soft price wave like the icon's line. Bright enough that the navy widgets stand out, deep enough at the
/// top for white lock screen text.
struct DipwiseWallpaper: View {
  var body: some View {
    ZStack {
      LinearGradient(stops: [
        .init(color: Color(red: 0.20, green: 0.42, blue: 0.68), location: 0),
        .init(color: Color(red: 0.30, green: 0.62, blue: 0.78), location: 0.35),
        .init(color: Color(red: 0.42, green: 0.80, blue: 0.72), location: 0.68),
        .init(color: Color(red: 0.98, green: 0.78, blue: 0.58), location: 1),
      ], startPoint: .top, endPoint: .bottom)
      RadialGradient(colors: [Brand.mint.opacity(0.45), .clear], center: UnitPoint(x: 0.1, y: 0.55), startRadius: 10, endRadius: 380)
      RadialGradient(colors: [Color(red: 1, green: 0.62, blue: 0.48).opacity(0.5), .clear], center: UnitPoint(x: 0.95, y: 0.95), startRadius: 10, endRadius: 360)
      RadialGradient(colors: [.white.opacity(0.22), .clear], center: UnitPoint(x: 0.8, y: 0.12), startRadius: 10, endRadius: 300)
      // The icon's price line, wide and soft: a dip, then the climb.
      Canvas { context, size in
        let wave = Path { path in
          let w = size.width, h = size.height
          path.move(to: CGPoint(x: -20, y: h * 0.6))
          path.addCurve(to: CGPoint(x: w * 0.42, y: h * 0.74), control1: CGPoint(x: w * 0.14, y: h * 0.62), control2: CGPoint(x: w * 0.28, y: h * 0.76))
          path.addCurve(to: CGPoint(x: w + 20, y: h * 0.48), control1: CGPoint(x: w * 0.62, y: h * 0.71), control2: CGPoint(x: w * 0.8, y: h * 0.5))
        }
        var glow = context
        glow.addFilter(.blur(radius: 18))
        glow.stroke(wave, with: .color(.white.opacity(0.45)), lineWidth: 26)
        context.stroke(wave, with: .color(.white.opacity(0.55)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
      }
    }
    .ignoresSafeArea()
  }
}
