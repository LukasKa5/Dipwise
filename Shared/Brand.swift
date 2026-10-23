import SwiftUI

/// Fixed "night watch" brand colors shared by the app, widgets, and watch.
enum Brand {
  static let nightTop = Color(red: 0.086, green: 0.251, blue: 0.353)
  static let nightMiddle = Color(red: 0.047, green: 0.141, blue: 0.220)
  static let nightBottom = Color(red: 0.024, green: 0.059, blue: 0.110)
  static let mint = Color(red: 0.184, green: 0.902, blue: 0.627)
  static let amber = Color(red: 1.0, green: 0.698, blue: 0.141)
  static let loss = Color(red: 1.0, green: 0.388, blue: 0.388)
  /// Buy and sell colors for widgets and Apple Watch, readable on light and dark backgrounds.
  static let buy = Color(red: 0.07, green: 0.72, blue: 0.45)
  static let sell = Color(red: 0.93, green: 0.27, blue: 0.30)
  static let owlWhite = Color(red: 0.933, green: 0.953, blue: 0.973)
  static let owlWing = Color(red: 0.776, green: 0.827, blue: 0.882)
  static let owlFeather = Color(red: 0.686, green: 0.753, blue: 0.824)
  static let owlInk = Color(red: 0.039, green: 0.106, blue: 0.180)
  /// Dippy's rosy cheeks when he blushes.
  static let owlBlush = Color(red: 1, green: 0.55, blue: 0.62)

}

extension TradeSide {
  /// Fixed buy/sell color for surfaces without the app's asset catalog.
  var brandColor: Color {
    switch self {
    case .buy: Brand.buy
    case .sell: Brand.sell
    case .watch: Brand.amber
    }
  }
}
