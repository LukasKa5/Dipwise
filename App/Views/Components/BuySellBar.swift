import SwiftUI

/// A split bar showing the share of buy versus sell alerts.
struct BuySellBar: View {
  var buyShare: Double

  var body: some View {
    GeometryReader { geometry in
      HStack(spacing: 2) {
        Capsule().fill(Palette.buy)
          .frame(width: max(4, (geometry.size.width - 2) * buyShare))
        Capsule().fill(Palette.sell)
      }
    }
    .frame(height: 6)
    .accessibilityElement()
    .accessibilityLabel("\(buyShare.formatted(.percent.precision(.fractionLength(0)))) buy targets")
  }
}
