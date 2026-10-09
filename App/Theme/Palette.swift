import SwiftUI

/// Dipwise brand colors. Adaptive colors come from the asset catalog.
enum Palette {
  /// Gains, the price line, and primary actions.
  static let green = Color.accentColor
  /// Alerts, targets, and the owl's accents.
  static let amber = Color("BrandAmber")
  static let canvas = Color("CanvasBackground")
  static let card = Color("CardBackground")

  // Fixed "night watch" colors used by the hero card and owl in every appearance.
  static let nightTop = Color(red: 0.086, green: 0.251, blue: 0.353)
  static let nightMiddle = Color(red: 0.047, green: 0.141, blue: 0.220)
  static let nightBottom = Color(red: 0.024, green: 0.059, blue: 0.110)
  static let mint = Color(red: 0.184, green: 0.902, blue: 0.627)
  static let glowAmber = Color(red: 1.0, green: 0.698, blue: 0.141)
  static let owlWhite = Color(red: 0.933, green: 0.953, blue: 0.973)
  static let owlWing = Color(red: 0.776, green: 0.827, blue: 0.882)
  static let owlFeather = Color(red: 0.686, green: 0.753, blue: 0.824)
  static let owlInk = Color(red: 0.039, green: 0.106, blue: 0.180)

  static let nightGradient = LinearGradient(
    colors: [nightTop, nightMiddle, nightBottom],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
  )
}
