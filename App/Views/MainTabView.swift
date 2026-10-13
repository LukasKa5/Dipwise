import SwiftUI

struct MainTabView: View {
  @Environment(Router.self) private var router
  @Environment(FlockService.self) private var flock

  var body: some View {
    @Bindable var router = router
    TabView(selection: $router.selectedTab) {
      Tab("Home", systemImage: "house", value: AppTab.home) {
        HomeView()
      }
      Tab("Watchlist", systemImage: "list.bullet", value: AppTab.watchlist) {
        WatchlistView()
      }
      Tab("Alerts", systemImage: "bell", value: AppTab.alerts) {
        AlertsView()
      }
      // The Flock appears once its iCloud backend is connected, so nobody sees an empty tab.
      if flock.isAvailable {
        Tab("Flock", systemImage: "person.3", value: AppTab.flock) {
          FlockView()
        }
      }
      Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
        SettingsView()
      }
    }
  }
}
