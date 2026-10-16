import Foundation
import Observation

enum AppTab: Hashable {
  case home
  case watchlist
  case alerts
  case flock
  case settings
}

/// App-wide navigation state, so notifications and widgets can open a specific stock.
@MainActor
@Observable
final class Router {
  static let shared = Router()

  var selectedTab: AppTab = Router.startTab

  /// Development only: `-startTab flock` opens the app on that tab, for checking screens.
  private static var startTab: AppTab {
    #if DEBUG
    let arguments = ProcessInfo.processInfo.arguments
    if let index = arguments.firstIndex(of: "-startTab"), arguments.indices.contains(index + 1) {
      switch arguments[index + 1] {
      case "watchlist": return .watchlist
      case "alerts": return .alerts
      case "flock": return .flock
      case "settings": return .settings
      default: break
      }
    }
    #endif
    return .home
  }
  var homePath: [String] = []
  var showsBrief = false

  func open(symbol: String) {
    selectedTab = .home
    homePath = [symbol]
  }

  func handle(url: URL) {
    guard url.scheme == "dipwise" else { return }
    if url.host() == "stock", let symbol = url.pathComponents.dropFirst().first {
      open(symbol: symbol)
    } else if url.host() == "alerts" {
      selectedTab = .alerts
    } else if url.host() == "flock" {
      selectedTab = .flock
    } else if url.host() == "portfolio" {
      selectedTab = .home
      homePath = []
    } else if url.host() == "brief" {
      selectedTab = .home
      showsBrief = true
    }
  }
}
