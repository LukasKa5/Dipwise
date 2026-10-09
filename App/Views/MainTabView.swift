import SwiftUI

struct MainTabView: View {
  @Environment(Router.self) private var router

  var body: some View {
    @Bindable var router = router
    TabView(selection: $router.selectedTab) {
      Tab("Home", systemImage: "house", value: AppTab.home) {
        HomeView()
      }
      Tab("Alerts", systemImage: "bell", value: AppTab.alerts) {
        AlertsView()
      }
      Tab("Flock", systemImage: "person.3", value: AppTab.flock) {
        FlockView()
      }
      Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
        SettingsView()
      }
    }
  }
}
