import SwiftUI

extension View {
  /// Keeps a number on one line and shrinks it to fit, so prices and percentages are never cut off with "…" on a
  /// small screen or at a large text size.
  func fitsNumber(_ minimumScale: CGFloat = 0.45) -> some View {
    lineLimit(1)
      .minimumScaleFactor(minimumScale)
      .allowsTightening(true)
  }
}
