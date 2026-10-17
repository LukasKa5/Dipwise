import Foundation

/// What the user did when an alert fired, logged in the Dip Journal.
enum JournalAction: String, CaseIterable, Identifiable {
  case bought
  case sold
  case held
  case skipped

  var id: Self { self }

  var title: String {
    switch self {
    case .bought: String(localized: "Bought")
    case .sold: String(localized: "Sold")
    case .held: String(localized: "Held")
    case .skipped: String(localized: "Skipped")
    }
  }

  var systemImage: String {
    switch self {
    case .bought: "cart.fill"
    case .sold: "banknote.fill"
    case .held: "hand.raised.fill"
    case .skipped: "forward.fill"
    }
  }

  var needsPrice: Bool { self == .bought || self == .sold }
}
