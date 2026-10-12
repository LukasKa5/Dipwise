import SwiftData
import SwiftUI

struct RootView: View {
  @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
  @AppStorage("appearanceMode") private var appearance: AppearanceMode = .system
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.modelContext) private var modelContext
  @Environment(QuoteStore.self) private var quotes
  @Environment(Router.self) private var router
  @Environment(FlockService.self) private var flock
  @State private var showsSplash = true

  var body: some View {
    Group {
      if hasCompletedOnboarding {
        MainTabView()
      } else {
        OnboardingView {
          withAnimation(.smooth) { hasCompletedOnboarding = true }
        }
      }
    }
    .overlay { ToastOverlay(center: ToastCenter.shared) }
    .overlay {
      // Shown once per launch, over the app so it can load underneath.
      if showsSplash {
        SplashView {
          withAnimation(.easeInOut(duration: 0.5)) { showsSplash = false }
        }
        .transition(.opacity)
      }
    }
    .tint(Palette.green)
    .fontDesign(.rounded)
    .preferredColorScheme(appearance.colorScheme)
    .onOpenURL { router.handle(url: $0) }
    .task(id: scenePhase) {
      // Keep prices fresh while the app is open.
      guard scenePhase == .active else { return }
      while !Task.isCancelled {
        await MarketMonitor.refresh(context: modelContext, quotes: quotes, flock: flock)
        try? await Task.sleep(for: .seconds(60))
      }
    }
  }
}
