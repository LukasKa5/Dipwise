import SwiftUI

/// Dipwise's own wallpaper for the iPhones it shows: a calm indigo to violet glow, with no pictures or lines to compete
/// with what's on top. iOS's light notification platters and the navy widgets both stand out clearly against it.
struct DipwiseWallpaper: View {
  var body: some View {
    ZStack {
      LinearGradient(stops: [
        .init(color: Color(red: 0.16, green: 0.22, blue: 0.58), location: 0),
        .init(color: Color(red: 0.26, green: 0.30, blue: 0.70), location: 0.5),
        .init(color: Color(red: 0.44, green: 0.30, blue: 0.70), location: 1),
      ], startPoint: .top, endPoint: .bottom)
      RadialGradient(colors: [Color(red: 0.35, green: 0.75, blue: 0.95).opacity(0.45), .clear], center: UnitPoint(x: 0.15, y: 0.2), startRadius: 10, endRadius: 360)
      RadialGradient(colors: [Color(red: 0.95, green: 0.55, blue: 0.85).opacity(0.35), .clear], center: UnitPoint(x: 0.9, y: 0.85), startRadius: 10, endRadius: 380)
    }
    .ignoresSafeArea()
  }
}
