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
    case .morning: "Good morning"
    case .afternoon: "Good afternoon"
    case .evening: "Good evening"
    }
  }
}
