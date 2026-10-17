import Foundation

enum DayPeriod {
  case morning
  case afternoon
  case evening

  init(date: Date, calendar: Calendar = .current) {
    switch calendar.component(.hour, from: date) {
    case 5..<12: self = .morning
    case 12..<18: self = .afternoon
    default: self = .evening
    }
  }

  var greeting: String {
    switch self {
    case .morning: String(localized: "Good morning")
    case .afternoon: String(localized: "Good afternoon")
    case .evening: String(localized: "Good evening")
    }
  }
}
