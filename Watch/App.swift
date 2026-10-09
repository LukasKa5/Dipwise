import SwiftUI

@main
struct DipwiseWatchApp: App {
  @State private var store = WatchTargetStore()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(store)
        .task { store.activate() }
    }
  }
}
