import SwiftUI

/// Dipwise colors that adapt between light and dark appearance (from the asset catalog).
/// Fixed brand colors live in `Brand`.
enum Palette {
  /// Buy zones, gains, and primary actions.
  static let buy = Color.accentColor
  /// Sell zones and losses.
  static let sell = Color("SellColor")
  static let gain = buy
  static let loss = sell
  static let green = buy
  /// The owl's accent: highlights, streaks, and "almost there".
  static let amber = Color("BrandAmber")
  static let canvas = Color("CanvasBackground")
  static let card = Color("CardBackground")
}

extension TradeSide {
  var color: Color {
    switch self {
    case .buy: Palette.buy
    case .sell: Palette.sell
    case .watch: Palette.amber
    }
  }
}
