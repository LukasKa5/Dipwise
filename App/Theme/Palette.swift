import SwiftUI

/// Dipwise brand colors. Each adapts between light and dark appearance via the asset catalog.
enum Palette {
  /// Gains, the price line, and primary actions.
  static let green = Color.accentColor
  /// Alerts, targets, and the owl's accents.
  static let amber = Color("BrandAmber")
  static let navy = Color("BrandNavy")
  static let canvas = Color("CanvasBackground")
  static let card = Color("CardBackground")
}
