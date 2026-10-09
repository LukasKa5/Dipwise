import SwiftUI

struct TickerBadge: View {
  var symbol: String
  var size: CGFloat = 44

  var body: some View {
    Text(symbol.prefix(symbol.count > 4 ? 1 : 2))
      .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
      .foregroundStyle(Brand.mint)
      .minimumScaleFactor(0.5)
      .frame(width: size, height: size)
      .background(Brand.nightGradient, in: .rect(cornerRadius: size * 0.3))
      .accessibilityHidden(true)
  }
}
