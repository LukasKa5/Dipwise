import StoreKit
import SwiftData
import SwiftUI
import UserNotifications

struct SettingsView: View {
  @AppStorage("appearanceMode") private var appearance: AppearanceMode = .system
  @AppStorage(AlertSettings.headsUpEnabledKey) private var headsUpEnabled = true
  @AppStorage(AlertSettings.headsUpThresholdKey) private var headsUpThreshold = 0.03
  @AppStorage(AlertSettings.shareWithFlockKey) private var shareWithFlock = true
  @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
  @Environment(SubscriptionManager.self) private var subscription
  @Environment(FlockService.self) private var flock
  @Environment(\.modelContext) private var modelContext
  @Environment(\.openURL) private var openURL
  @Environment(\.requestReview) private var requestReview
  @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
  @State private var showsPaywall = false
  @State private var showsManageSubscription = false
  @State private var showsRedeemCode = false
  @State private var isRestoring = false

  private var appVersion: String {
    let info = Bundle.main.infoDictionary
    return "\(info?["CFBundleShortVersionString"] as? String ?? "1.0") (\(info?["CFBundleVersion"] as? String ?? "1"))"
  }

  var body: some View {
    NavigationStack {
      Form {
        subscriptionSection
        notificationsSection
        flockSection
        appearanceSection
        supportSection
        aboutSection
        #if DEBUG
        developerSection
        #endif
      }
      .navigationTitle("Settings")
      .sheet(isPresented: $showsPaywall) { PaywallView() }
      .manageSubscriptionsSheet(isPresented: $showsManageSubscription)
      .offerCodeRedemption(isPresented: $showsRedeemCode)
      .task { notificationStatus = await NotificationManager.authorizationStatus() }
    }
  }

  // MARK: Sections

  private var subscriptionSection: some View {
    Section {
      if subscription.isPro {
        HStack(spacing: 14) {
          OwlMark().frame(width: 40)
          VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
              Text("Dipwise Pro")
                .font(.headline)
              ProBadge()
            }
            Text("Thanks for supporting Dipwise.")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        }
        Button("Manage Subscription") { showsManageSubscription = true }
      } else {
        Button {
          showsPaywall = true
        } label: {
          HStack(spacing: 14) {
            OwlMark().frame(width: 40)
            VStack(alignment: .leading, spacing: 2) {
              Text("Upgrade to Dipwise Pro")
                .font(.headline)
                .foregroundStyle(.primary)
              Text("Unlimited alerts, heads-ups, and full flock statistics.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.forward")
              .font(.footnote.weight(.semibold))
              .foregroundStyle(.tertiary)
          }
        }
      }
      Button(isRestoring ? "Restoring…" : "Restore Purchases") {
        isRestoring = true
        Task {
          await subscription.restore()
          isRestoring = false
        }
      }
      .disabled(isRestoring)
      Button("Redeem Code") { showsRedeemCode = true }
    }
  }

  private var notificationsSection: some View {
    Section {
      HStack {
        Label("Notifications", systemImage: "bell.badge")
        Spacer()
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral:
          Text("On").foregroundStyle(.secondary)
        case .denied:
          Button("Turn On in Settings") {
            if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
          }
        default:
          Button("Allow") {
            Task {
              await NotificationManager.requestAuthorization()
              notificationStatus = await NotificationManager.authorizationStatus()
            }
          }
        }
      }
      Toggle(isOn: $headsUpEnabled) {
        HStack(spacing: 6) {
          Label("Heads-up when close", systemImage: "waveform.path.ecg")
          if !subscription.isPro { ProBadge() }
        }
      }
      .disabled(!subscription.isPro)
      if subscription.isPro && headsUpEnabled {
        Picker("Heads-up distance", selection: $headsUpThreshold) {
          Text("2%").tag(0.02)
          Text("3%").tag(0.03)
          Text("5%").tag(0.05)
        }
      }
    } header: {
      Text("Alerts")
    } footer: {
      Text(notificationStatus == .denied
           ? "Notifications are off, so Dipwise can't tell you when a target is reached."
           : "Dipwise checks prices in the background several times an hour. iOS decides the exact timing.")
    }
  }

  private var flockSection: some View {
    Section {
      Toggle(isOn: $shareWithFlock) {
        Label("Share my alerts anonymously", systemImage: "person.3")
      }
      .onChange(of: shareWithFlock) { _, isOn in
        if !isOn { withdrawAllFromFlock() }
      }
    } header: {
      Text("The Flock")
    } footer: {
      Text("Only the ticker, alert type, and target price are shared. Never your name, holdings, or notes. Turning this off removes your alerts from the flock.")
    }
  }

  private var appearanceSection: some View {
    Section("Appearance") {
      Picker("Theme", selection: $appearance) {
        ForEach(AppearanceMode.allCases) { mode in
          Label(mode.title, systemImage: mode.systemImage).tag(mode)
        }
      }
      .pickerStyle(.inline)
      .labelsHidden()
    }
  }

  private var supportSection: some View {
    Section("Support") {
      Button("Rate Dipwise", systemImage: "star") { requestReview() }
      if let mail = URL(string: "mailto:\(AppLinks.supportEmail)?subject=Dipwise%20\(appVersion)") {
        Link(destination: mail) {
          Label("Contact Support", systemImage: "envelope")
        }
      }
      ShareLink(item: "Dipwise watches your stocks and tells you when they hit your price. Check it out on the App Store.") {
        Label("Tell a Friend", systemImage: "square.and.arrow.up")
      }
    }
  }

  private var aboutSection: some View {
    Section {
      Link(destination: AppLinks.privacyPolicy) {
        Label("Privacy Policy", systemImage: "hand.raised")
      }
      Link(destination: AppLinks.termsOfUse) {
        Label("Terms of Use", systemImage: "doc.text")
      }
      LabeledContent("Version", value: appVersion)
    } header: {
      Text("About")
    } footer: {
      Text("Dipwise is not a broker, does not execute trades, and does not provide investment advice. Market data may be delayed and is provided for information only.")
    }
  }

  #if DEBUG
  private var developerSection: some View {
    @Bindable var subscription = subscription
    return Section("Developer") {
      Toggle("Preview Pro Features", isOn: $subscription.previewPro)
      Button("Send Test Notification") {
        Task {
          await NotificationManager.requestAuthorization()
          await NotificationManager.sendTest()
        }
      }
      Button("Show Onboarding Again") { hasCompletedOnboarding = false }
    }
  }
  #endif

  private func withdrawAllFromFlock() {
    let alerts = (try? modelContext.fetch(FetchDescriptor<PriceAlert>())) ?? []
    Task {
      for alert in alerts { await flock.withdraw(alert) }
      try? modelContext.save()
    }
  }
}
