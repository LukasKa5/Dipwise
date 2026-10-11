import AppIntents
import WidgetKit

/// Shared state for interactive widgets.
enum WidgetState {
  static var planIndex: Int {
    get { AppGroup.defaults.integer(forKey: "widget.planIndex") }
    set { AppGroup.defaults.set(newValue, forKey: "widget.planIndex") }
  }

  static var showsZones: Bool {
    get { AppGroup.defaults.bool(forKey: "widget.showsZones") }
    set { AppGroup.defaults.set(newValue, forKey: "widget.showsZones") }
  }
}

/// Shows the next plan in the Plans widget.
struct NextPlanIntent: AppIntent {
  static let title: LocalizedStringResource = "Next Plan"
  static let isDiscoverable = false

  func perform() async throws -> some IntentResult {
    WidgetState.planIndex += 1
    return .result()
  }
}

/// Flips the Stock Plan widget between its chart and its zones.
struct ToggleZonesIntent: AppIntent {
  static let title: LocalizedStringResource = "Show Zones"
  static let isDiscoverable = false

  func perform() async throws -> some IntentResult {
    WidgetState.showsZones.toggle()
    return .result()
  }
}

/// Fetches fresh prices for every widget.
struct RefreshWidgetsIntent: AppIntent {
  static let title: LocalizedStringResource = "Refresh Prices"
  static let isDiscoverable = false

  func perform() async throws -> some IntentResult {
    let symbols = TargetSnapshotStore.loadTargets().map(\.symbol) + TargetSnapshotStore.loadStocks().map(\.symbol)
    _ = await WidgetData.quotes(for: symbols)
    return .result()
  }
}
