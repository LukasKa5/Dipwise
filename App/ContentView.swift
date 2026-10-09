import SwiftUI

struct ContentView: View {
  @State private var portfolio = Portfolio()

  var body: some View {
    DashboardView(portfolio: portfolio)
  }
}
