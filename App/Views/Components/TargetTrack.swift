import SwiftUI

/// A track showing how close the price is to triggering, ending in a target marker.
struct TargetTrack: View {
  var progress: Double
  var isReached = false
  var tint: Color = Palette.buy

  var body: some View {
    GeometryReader { geometry in
      let width = max(0, geometry.size.width - 22)
      ZStack(alignment: .leading) {
        Capsule()
          .fill(.quaternary)
          .frame(height: 8)
        Capsule()
          .fill(LinearGradient(colors: [tint.opacity(0.35), tint], startPoint: .leading, endPoint: .trailing))
          .frame(width: max(8, width * (isReached ? 1 : progress) + 11), height: 8)
        if !isReached {
          Circle()
            .fill(Palette.card)
            .stroke(tint, lineWidth: 3)
            .frame(width: 16, height: 16)
            .offset(x: width * progress + 3)
        }
        Image(systemName: isReached ? "checkmark.circle.fill" : "scope")
          .font(.system(size: 16, weight: .bold))
          .foregroundStyle(tint)
          .frame(width: 22, height: 22)
          .offset(x: width)
      }
      .frame(maxHeight: .infinity)
    }
    .frame(height: 22)
    .animation(.smooth, value: progress)
    .accessibilityHidden(true)
  }
}
