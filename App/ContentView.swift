import SwiftUI

struct ContentView: View {
  @State private var portfolio = Portfolio()
  @AppStorage("appearanceMode") private var appearance: AppearanceMode = .system

  var body: some View {
    DashboardView(portfolio: portfolio, appearance: $appearance)
      .preferredColorScheme(appearance.colorScheme)
  }
}
