import StoreKit
import SwiftData
import SwiftUI
import UserNotifications

struct SettingsView: View {
  @AppStorage("appearanceMode") private var appearance: AppearanceMode = .system
  @AppStorage(AlertSettings.headsUpEnabledKey) private var headsUpEnabled = true
  @AppStorage(AlertSettings.headsUpThresholdKey) private var headsUpThreshold = 0.03
  @AppStorage(AlertSettings.shareWithFlockKey) private var shareWithFlock = true
  @AppStorage(AlertSettings.sharePortfolioKey) private var sharePortfolio = false
  @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
  @AppStorage(AlertSettings.baseCurrencyKey) private var baseCurrency = AlertSettings.defaultBaseCurrency
  @AppStorage(AlertSettings.cashBalanceKey) private var cash = 0.0
  @AppStorage(AlertSettings.quietHoursKey) private var quietAlerts = false
  @Environment(QuoteStore.self) private var quotes
  @Environment(ProgressStore.self) private var progress
  @AppStorage(AlertSettings.briefReminderKey) private var briefReminder = true
  @AppStorage(AlertSettings.showsBriefKey) private var showsBrief = true
  @AppStorage(AlertSettings.briefReminderMinutesKey) private var briefMinutes = AlertSettings.defaultBriefMinutes
  @Environment(SubscriptionManager.self) private var subscription
  @Environment(FlockService.self) private var flock
  @Environment(\.modelContext) private var modelContext
  @Environment(\.openURL) private var openURL
  @Environment(\.requestReview) private var requestReview
  @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
  @State private var showsPaywall = false
  @State private var showsImport = false
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
        Group {
          subscriptionSection
        notificationsSection
        briefSection
        portfolioSection
        flockSection
        appearanceSection
        supportSection
        aboutSection
        #if DEBUG
        developerSection
        #endif
        }
        .dipwiseRows()
      }
      .dipwiseListStyle()
      .navigationTitle("Settings")
      .sheet(isPresented: $showsPaywall) { PaywallView() }
      .sheet(isPresented: $showsImport) { ImportPortfolioView() }
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
          LivelyOwl().frame(width: 40, height: 46)
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
            LivelyOwl().frame(width: 40, height: 46)
            VStack(alignment: .leading, spacing: 2) {
              Text("Upgrade to Dipwise Pro")
                .font(.headline)
                .foregroundStyle(.primary)
              Text("Unlimited zones, smart alerts, and the full crowd report.")
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
      Toggle(isOn: $quietAlerts) {
        Label("Deliver quietly", systemImage: "moon")
      }
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
           : "Dipwise checks prices in the background several times an hour. iOS decides the exact timing. Quiet delivery won't break through Focus.")
    }
  }

  private var briefTime: Binding<Date> {
    Binding {
      Calendar.current.date(bySettingHour: briefMinutes / 60, minute: briefMinutes % 60, second: 0, of: .now) ?? .now
    } set: { date in
      let components = Calendar.current.dateComponents([.hour, .minute], from: date)
      briefMinutes = (components.hour ?? 8) * 60 + (components.minute ?? 30)
    }
  }

  private var briefSection: some View {
    Section {
      Toggle(isOn: $showsBrief) {
        Label("Show Daily Brief", systemImage: "flame")
      }
      if showsBrief {
        Toggle(isOn: $briefReminder) {
          Label("Reminder", systemImage: "bell")
        }
        if briefReminder {
          DatePicker("Time", selection: briefTime, displayedComponents: .hourAndMinute)
        }
      }
    } header: {
      Text("Daily Brief")
    } footer: {
      Text(showsBrief ? "A one-minute check-in that keeps your streak alive. You're on a \(progress.streak)-day streak." : "The brief and streak are hidden. Turn them back on any time.")
    }
    .onChange(of: briefReminder) { reschedule() }
    .onChange(of: showsBrief) { reschedule() }
    .onChange(of: briefMinutes) { reschedule() }
  }

  private func reschedule() {
    Task { await NotificationManager.scheduleBriefReminders(streak: progress.streak, skipToday: progress.isBriefDoneToday) }
  }

  private var portfolioSection: some View {
    Section {
      Picker("Currency", selection: $baseCurrency) {
        ForEach(AlertSettings.supportedCurrencies, id: \.self) { code in
          Text("\(code) · \(Locale.current.localizedString(forCurrencyCode: code) ?? code)").tag(code)
        }
      }
      .onChange(of: baseCurrency) { _, code in
        Task { await quotes.setBaseCurrency(code) }
      }
      LabeledContent("Cash for buying dips") {
        TextField("0", value: $cash, format: .currency(code: baseCurrency))
          .keyboardType(.decimalPad)
          .multilineTextAlignment(.trailing)
      }
      Button("Import from Broker or CSV", systemImage: "tray.and.arrow.down") { showsImport = true }
    } header: {
      Text("Portfolio")
    } footer: {
      Text("Totals and dividends are converted into this currency using live exchange rates.")
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
      Toggle(isOn: $sharePortfolio) {
        Label("Share my portfolio mix anonymously", systemImage: "chart.pie")
      }
      .onChange(of: sharePortfolio) { _, isOn in
        if !isOn { Task { await flock.withdrawPortfolio() } }
      }
    } header: {
      Text("The Flock")
    } footer: {
      Text("Alerts share only the ticker, alert type, and target price. Your portfolio mix shares only what percentage each stock is, plus when you add or trim. Never amounts, prices paid, your name, or notes. Turning either off removes that data from the flock.")
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
      NavigationLink {
        PrivacyPolicyView()
      } label: {
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
