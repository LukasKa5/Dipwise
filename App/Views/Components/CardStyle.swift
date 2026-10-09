import SwiftUI

extension View {
  /// The standard Dipwise card: rounded surface with a soft shadow in light mode and a hairline in dark mode.
  func cardStyle(cornerRadius: CGFloat = 24) -> some View {
    modifier(CardStyle(cornerRadius: cornerRadius))
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
          .strokeBorder(.white.opacity(colorScheme == .dark ? 0.06 : 0))
      }
      .shadow(color: Color(red: 0.04, green: 0.11, blue: 0.18).opacity(colorScheme == .dark ? 0 : 0.06), radius: 14, y: 6)
  }
}
