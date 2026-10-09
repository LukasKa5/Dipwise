import SwiftUI

/// Dipwise colors that adapt between light and dark appearance (from the asset catalog).
/// Fixed brand colors live in `Brand`.
enum Palette {
  /// Gains, the price line, and primary actions.
  static let green = Color.accentColor
  /// Alerts, targets, and the owl's accents.
  static let amber = Color("BrandAmber")
  static let canvas = Color("CanvasBackground")
  static let card = Color("CardBackground")
  static let loss = Color.red
}
