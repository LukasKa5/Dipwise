import SwiftUI

extension View {
  /// The standard Dipwise card: a raised surface with a soft shadow in light mode and a hairline in dark mode.
  func cardStyle(cornerRadius: CGFloat = 24) -> some View {
    modifier(CardStyle(cornerRadius: cornerRadius))
  }

  /// The signature navy card, the same color as the app icon, used for each screen's main chart.
  func heroCardStyle(cornerRadius: CGFloat = 28) -> some View {
    modifier(HeroCardStyle(cornerRadius: cornerRadius))
  }

  /// Gives forms and lists the same canvas and card colors as the rest of the app.
  func dipwiseListStyle() -> some View {
    scrollContentBackground(.hidden)
      .background(Palette.canvas)
  }

  /// Use on list sections so rows match the app's cards.
  func dipwiseRows() -> some View {
    listRowBackground(Palette.card)
  }
}

private struct CardStyle: ViewModifier {
  var cornerRadius: CGFloat
  @Environment(\.colorScheme) private var colorScheme

  func body(content: Content) -> some View {
    content
      .background(Palette.card, in: .rect(cornerRadius: cornerRadius))
      .overlay {
        RoundedRectangle(cornerRadius: cornerRadius)
          .strokeBorder(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04))
      }
      .shadow(color: Brand.nightBottom.opacity(colorScheme == .dark ? 0 : 0.08), radius: 16, y: 6)
  }
}

private struct HeroCardStyle: ViewModifier {
  var cornerRadius: CGFloat

  func body(content: Content) -> some View {
    content
      .foregroundStyle(.white)
      .background(Brand.nightMiddle, in: .rect(cornerRadius: cornerRadius))
      .overlay {
        RoundedRectangle(cornerRadius: cornerRadius)
          .strokeBorder(.white.opacity(0.08))
      }
      .shadow(color: Brand.nightBottom.opacity(0.25), radius: 18, y: 8)
      .environment(\.colorScheme, .dark)
  }
}
