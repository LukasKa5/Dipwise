import SwiftData
import SwiftUI
import UserNotifications

@main
struct DipwiseApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @Environment(\.scenePhase) private var scenePhase
  @State private var quotes = QuoteStore()
  @State private var subscription = SubscriptionManager()
  @State private var flock = FlockService()
  @State private var progress = ProgressStore()

  static let container: ModelContainer = {
    do {
      return try ModelContainer(for: Holding.self, PriceAlert.self)
    } catch {
      fatalError("Could not open the Dipwise database: \(error)")
    }
  }()

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(quotes)
        .environment(subscription)
        .environment(flock)
        .environment(progress)
        .environment(Router.shared)
        .task { subscription.start() }
        #if DEBUG
        .task { DemoPortfolio.install(in: Self.container.mainContext) }
        #endif
    }
    .modelContainer(Self.container)
    .onChange(of: scenePhase) { _, phase in
      switch phase {
      case .background:
        BackgroundRefresh.schedule()
        OwlWake.shared.appDidEnterBackground()
      case .active:
        OwlWake.shared.appDidBecomeActive()
      default:
        break
      }
    }
    .backgroundTask(.appRefresh(BackgroundRefresh.identifier)) {
      await BackgroundRefresh.run(container: DipwiseApp.container)
    }
  }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    WatchSync.shared.activate()
    PushAlerts.register()
    return true
  }

  func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    PushAlerts.didRegister(token: deviceToken)
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
    [.banner, .list, .sound]
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
    let info = response.notification.request.content.userInfo
    if let symbol = info["symbol"] as? String {
      await MainActor.run { Router.shared.open(symbol: symbol) }
    } else if info["brief"] != nil {
      await MainActor.run {
        Router.shared.selectedTab = .home
        Router.shared.showsBrief = true
      }
    }
  }
}
