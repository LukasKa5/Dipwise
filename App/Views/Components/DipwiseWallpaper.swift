import SwiftUI

/// Dipwise's own wallpaper for the iPhones it shows: deep indigo through teal into violet, with a soft mint price wave
/// like the icon's line. Dark enough that white notification text reads clearly, colorful enough that the navy
/// widgets stand apart from it.
struct DipwiseWallpaper: View {
  var body: some View {
    ZStack {
      LinearGradient(stops: [
        .init(color: Color(red: 0.12, green: 0.15, blue: 0.40), location: 0),
        .init(color: Color(red: 0.10, green: 0.34, blue: 0.48), location: 0.45),
        .init(color: Color(red: 0.22, green: 0.20, blue: 0.48), location: 1),
      ], startPoint: .top, endPoint: .bottom)
      RadialGradient(colors: [Brand.mint.opacity(0.35), .clear], center: UnitPoint(x: 0.1, y: 0.6), startRadius: 10, endRadius: 380)
      RadialGradient(colors: [Color(red: 0.62, green: 0.42, blue: 0.95).opacity(0.45), .clear], center: UnitPoint(x: 0.95, y: 0.92), startRadius: 10, endRadius: 360)
      RadialGradient(colors: [Color(red: 0.4, green: 0.7, blue: 1).opacity(0.25), .clear], center: UnitPoint(x: 0.85, y: 0.08), startRadius: 10, endRadius: 300)
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
        glow.stroke(wave, with: .color(Brand.mint.opacity(0.4)), lineWidth: 26)
        context.stroke(wave, with: .color(Brand.mint.opacity(0.6)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
      }
    }
    .ignoresSafeArea()
  }
}
