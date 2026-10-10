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
    case .bought: "Bought"
    case .sold: "Sold"
    case .held: "Held"
    case .skipped: "Skipped"
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
