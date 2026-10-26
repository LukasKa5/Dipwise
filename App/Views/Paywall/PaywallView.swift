import StoreKit
import SwiftUI

/// Dipwise Pro offer with yearly, monthly, and lifetime plans.
struct PaywallView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(SubscriptionManager.self) private var subscription
  @Environment(FlockService.self) private var flock
  @State private var products: [Product] = []
  @State private var selectedID = SubscriptionManager.yearlyID
  @State private var isLoading = true
  @State private var isPurchasing = false
  @State private var errorMessage: String?
  @State private var flaps = 0
  @State private var pulse = false
  @State private var didPurchase = false
  @State private var celebrationCount = 0

  private var selected: Product? { products.first { $0.id == selectedID } }

  @State private var showsPrivacy = false

  var body: some View {
    ScrollView {
      VStack(spacing: 26) {
        header
        comparison
        plans
        if let offer = selected?.subscription?.introductoryOffer, offer.paymentMode == .freeTrial {
          trialTimeline(offer)
        }
        HStack(spacing: 18) {
          Button("Restore Purchases") {
            Task {
              await subscription.restore()
              if subscription.isPro { dismiss() }
            }
          }
          Link("Terms", destination: AppLinks.termsOfUse)
          Button("Privacy") { showsPrivacy = true }
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.white.opacity(0.75))
        .sheet(isPresented: $showsPrivacy) {
          NavigationStack { PrivacyPolicyView() }
        }
      }
      .padding(.horizontal, 22)
      .padding(.bottom, 24)
      .frame(maxWidth: 560)
      .frame(maxWidth: .infinity)
    }
    .scrollIndicators(.hidden)
    .safeAreaInset(edge: .bottom, spacing: 0) { purchaseBar }
    .foregroundStyle(.white)
    .background(Brand.nightMiddle.ignoresSafeArea())
    .environment(\.colorScheme, .dark)
    .overlay(alignment: .topTrailing) {
      Button("Close", systemImage: "xmark") { dismiss() }
        .labelStyle(.iconOnly)
        .font(.headline)
        .foregroundStyle(.white.opacity(0.8))
        .frame(width: 36, height: 36)
        .background(.white.opacity(0.12), in: .circle)
        .padding()
    }
    .overlay {
      if didPurchase { celebration }
    }
    .task { await loadProducts() }
    .task { await flapForever() }
    .onAppear { pulse = true }
  }

  /// Always visible, so the next step is one tap away wherever the user has scrolled.
  private var purchaseBar: some View {
    VStack(spacing: 10) {
      Button(action: purchase) {
        Group {
          if isPurchasing {
            ProgressView().tint(Brand.owlInk)
          } else {
            Text(ctaTitle)
          }
        }
        .font(.headline)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
      }
      .buttonStyle(.borderedProminent)
      .tint(Brand.buy)
      .foregroundStyle(Brand.owlInk)
      .disabled(selected == nil || isPurchasing)
      .scaleEffect(pulse ? 1.02 : 1)
      .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)

      if let errorMessage {
        Text(errorMessage)
          .font(.footnote)
          .foregroundStyle(Brand.loss)
          .multilineTextAlignment(.center)
      }

      Text(finePrint)
        .font(.caption)
        .foregroundStyle(.white.opacity(0.6))
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.horizontal, 22)
    .padding(.top, 12)
    .padding(.bottom, 8)
    .frame(maxWidth: 560)
    .frame(maxWidth: .infinity)
    .background {
      LinearGradient(colors: [Brand.nightMiddle.opacity(0), Brand.nightMiddle], startPoint: .top, endPoint: .init(x: 0.5, y: 0.25))
        .ignoresSafeArea()
    }
  }

  // MARK: Sections

  private var header: some View {
    VStack(spacing: 12) {
      LivelyOwl(hopsOnTap: true, mood: .calm)
        .frame(width: 104, height: 120)
        .owlFlight(trigger: flaps, height: 12)
        .padding(.top, 40)
      Text("Let Dippy watch everything")
        .font(.largeTitle.bold())
        .multilineTextAlignment(.center)
      Text("Buy the dips and sell the highs with a plan, without watching charts all day.")
        .font(.headline)
        .foregroundStyle(.white.opacity(0.7))
        .multilineTextAlignment(.center)
    }
  }

  /// Only what changes with Pro, with the Pro column highlighted.
  private var comparison: some View {
    // Only sell what works today: crowd features appear once the Flock is live.
    let rows = ProFeature.all.filter { (flock.isAvailable || !$0.needsFlock) && (MarketData.offersRealTime || !$0.needsRealTime) }
    return VStack(spacing: 0) {
      HStack(spacing: 0) {
        Text("What you get")
          .font(.caption.weight(.bold))
          .foregroundStyle(.white.opacity(0.6))
          .frame(maxWidth: .infinity, alignment: .leading)
        Text("Free")
          .font(.caption.weight(.bold))
          .foregroundStyle(.white.opacity(0.6))
          .frame(width: ProFeature.freeWidth)
        Text("PRO")
          .font(.caption.weight(.heavy))
          .foregroundStyle(Brand.owlInk)
          .padding(.horizontal, 10)
          .padding(.vertical, 3)
          .background(Brand.amber, in: .capsule)
          .frame(width: ProFeature.proWidth)
          .padding(.vertical, 10)
          .background(Brand.buy.opacity(0.14), in: UnevenRoundedRectangle(topLeadingRadius: 14, topTrailingRadius: 14))
      }
      ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
        HStack(spacing: 0) {
          HStack(spacing: 10) {
            Image(systemName: row.systemImage)
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(Brand.amber)
              .frame(width: 22)
            Text(row.title)
              .font(.subheadline.weight(.medium))
              .fixedSize(horizontal: false, vertical: true)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.vertical, 12)
          ProFeature.cell(row.free, isPro: false)
            .frame(width: ProFeature.freeWidth)
          ProFeature.cell(row.pro, isPro: true)
            .frame(width: ProFeature.proWidth)
            .frame(maxHeight: .infinity)
            .background(Brand.buy.opacity(0.14), in: UnevenRoundedRectangle(
              bottomLeadingRadius: index == rows.count - 1 ? 14 : 0,
              bottomTrailingRadius: index == rows.count - 1 ? 14 : 0
            ))
        }
        .fixedSize(horizontal: false, vertical: true)
        .overlay(alignment: .top) {
          Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
            .padding(.trailing, ProFeature.proWidth)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.title)
        .accessibilityValue("Free: \(row.free.spoken). Pro: \(row.pro.spoken).")
      }
    }
    .padding(.horizontal, 16)
    .padding(.top, 6)
    .padding(.bottom, 12)
    .background(.white.opacity(0.06), in: .rect(cornerRadius: 22))
  }

  private func trialTimeline(_ offer: Product.SubscriptionOffer) -> some View {
    let days = offer.period.unit == .week ? offer.period.value * 7 : offer.period.value
    let steps: [(String, String, String)] = [
      ("lock.open.fill", "Today", "Everything unlocks. Dippy gets to work."),
      ("bell.fill", "Day \(max(days - 2, 1))", "We'll remind you before the trial ends."),
      ("star.fill", "Day \(days)", "Your subscription starts. Cancel any time before."),
    ]
    return VStack(alignment: .leading, spacing: 0) {
      ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
        HStack(alignment: .top, spacing: 14) {
          VStack(spacing: 0) {
            Image(systemName: step.0)
              .font(.subheadline.weight(.bold))
              .foregroundStyle(Brand.owlInk)
              .frame(width: 32, height: 32)
              .background(index == 0 ? Brand.buy : Brand.amber, in: .circle)
            if index < steps.count - 1 {
              Rectangle().fill(.white.opacity(0.2)).frame(width: 2, height: 28)
            }
          }
          VStack(alignment: .leading, spacing: 2) {
            Text(step.1).font(.headline)
            Text(step.2).font(.subheadline).foregroundStyle(.white.opacity(0.65))
          }
          Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
      }
    }
    .padding(16)
    .background(.white.opacity(0.06), in: .rect(cornerRadius: 20))
  }

  private var celebration: some View {
    ZStack {
      Brand.nightMiddle.opacity(0.92).ignoresSafeArea()
      VStack(spacing: 16) {
        LivelyOwl(mood: .celebrating, greeting: .flap, greetingDelay: 0.9)
          .frame(width: 140, height: 160)
          .owlFlight(trigger: flaps, height: 50)
        Text("Welcome to Pro!")
          .font(.largeTitle.bold())
        Text("Dippy is watching everything now.")
          .foregroundStyle(.white.opacity(0.7))
      }
      Confetti(trigger: celebrationCount)
    }
    .transition(.opacity)
  }

  private func flapForever() async {
    while !Task.isCancelled {
      try? await Task.sleep(for: .seconds(9))
      flaps += 1
    }
  }

  // MARK: Plans

  @ViewBuilder
  private var plans: some View {
    if isLoading {
      ProgressView().tint(.white).frame(height: 160)
    } else if products.isEmpty {
      Text("Plans couldn't be loaded. Check your connection and try again.")
        .font(.subheadline)
        .foregroundStyle(.white.opacity(0.7))
        .multilineTextAlignment(.center)
        .frame(height: 120)
    } else {
      VStack(spacing: 12) {
        ForEach(products) { product in
          PlanCard(product: product, isSelected: product.id == selectedID, badge: badge(for: product), detail: LocalizedStringKey(detail(for: product))) {
            withAnimation(.snappy) { selectedID = product.id }
          }
        }
      }
    }
  }

  private func badge(for product: Product) -> String? {
    guard product.id == SubscriptionManager.yearlyID,
          let monthly = products.first(where: { $0.id == SubscriptionManager.monthlyID }) else { return nil }
    let yearlyAsMonthly = product.price / 12
    let saving = 1 - NSDecimalNumber(decimal: yearlyAsMonthly / monthly.price).doubleValue
    return saving > 0.05 ? "Save \(saving.formatted(.percent.precision(.fractionLength(0))))" : "Best value"
  }

  private func detail(for product: Product) -> String {
    switch product.id {
    case SubscriptionManager.yearlyID:
      let monthly = (product.price / 12).formatted(product.priceFormatStyle)
      if let offer = product.subscription?.introductoryOffer, offer.paymentMode == .freeTrial {
        return "\(trialText(offer)) free, then \(product.displayPrice)/year (\(monthly)/mo)"
      }
      return "\(product.displayPrice)/year · \(monthly)/mo"
    case SubscriptionManager.monthlyID:
      return "\(product.displayPrice)/month"
    default:
      return "\(product.displayPrice) once · yours forever"
    }
  }

  private func trialText(_ offer: Product.SubscriptionOffer) -> String {
    let period = offer.period
    switch period.unit {
    case .day: return String(localized: "\(period.value)-day")
    case .week: return period.value == 1 ? String(localized: "7-day") : String(localized: "\(period.value)-week")
    case .month: return String(localized: "\(period.value)-month")
    default: return String(localized: "Free trial")
    }
  }

  private var ctaTitle: LocalizedStringKey {
    if let offer = selected?.subscription?.introductoryOffer, offer.paymentMode == .freeTrial {
      return "Start \(trialText(offer)) Free Trial"
    }
    return selected?.id == SubscriptionManager.lifetimeID ? "Unlock Forever" : "Continue"
  }

  private var finePrint: LocalizedStringKey {
    if selected?.id == SubscriptionManager.lifetimeID {
      return "One-time purchase. No subscription."
    }
    return "Renews automatically. Cancel anytime in Settings at least 24 hours before renewal."
  }

  // MARK: StoreKit

  private func loadProducts() async {
    defer { isLoading = false }
    do {
      let loaded = try await Product.products(for: SubscriptionManager.productIDs)
      products = SubscriptionManager.productIDs.compactMap { id in loaded.first { $0.id == id } }
      if selected == nil, let first = products.first { selectedID = first.id }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func purchase() {
    guard let selected else { return }
    isPurchasing = true
    errorMessage = nil
    Task {
      defer { isPurchasing = false }
      do {
        switch try await selected.purchase() {
        case .success(let verification):
          if case .verified(let transaction) = verification {
            await transaction.finish()
          }
          await subscription.refreshEntitlements()
          if let offer = selected.subscription?.introductoryOffer, offer.paymentMode == .freeTrial {
            await NotificationManager.scheduleTrialReminder(daysUntilEnd: offer.period.unit == .week ? offer.period.value * 7 : offer.period.value)
          }
          withAnimation(.smooth) { didPurchase = true }
          celebrationCount += 1
          flaps += 1
          try? await Task.sleep(for: .seconds(2.2))
          dismiss()
        case .pending:
          errorMessage = "Your purchase is pending approval."
        default:
          break
        }
      } catch {
        errorMessage = error.localizedDescription
      }
    }
  }
}

private struct PlanCard: View {
  var product: Product
  var isSelected: Bool
  var badge: String?
  var detail: LocalizedStringKey
  var action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 14) {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
          .font(.title2)
          .foregroundStyle(isSelected ? Brand.mint : .white.opacity(0.4))
        VStack(alignment: .leading, spacing: 3) {
          HStack(spacing: 8) {
            Text(product.displayName.isEmpty ? product.id : product.displayName)
              .font(.headline)
            if let badge {
              Text(badge)
                .font(.caption2.weight(.heavy))
                .foregroundStyle(Brand.owlInk)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Brand.amber, in: .capsule)
            }
          }
          Text(detail)
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.7))
        }
        Spacer()
      }
      .padding(16)
      .background(.white.opacity(isSelected ? 0.14 : 0.06), in: .rect(cornerRadius: 18))
      .overlay {
        RoundedRectangle(cornerRadius: 18)
          .strokeBorder(isSelected ? Brand.mint : .white.opacity(0.12), lineWidth: isSelected ? 2 : 1)
      }
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

/// One row of the Free vs Pro comparison.
private struct ProFeature {
  enum Value {
    case text(String)
    case included
    case missing

    var spoken: String {
      switch self {
      case .text(let text): text
      case .included: "included"
      case .missing: "not included"
      }
    }
  }

  var title: LocalizedStringKey
  var systemImage: String
  var free: Value
  var pro: Value
  var needsFlock = false
  var needsRealTime = false

  static let freeWidth: CGFloat = 62
  static let proWidth: CGFloat = 86

  static let all: [ProFeature] = [
    ProFeature(title: "Real-time prices and alerts", systemImage: "bolt.fill", free: .text("15 min"), pro: .text("Live"), needsRealTime: true),
    ProFeature(title: "Price alerts", systemImage: "bell.fill", free: .text("3"), pro: .text("Unlimited")),
    ProFeature(title: "Smart alerts like RSI, MACD, and trend crosses", systemImage: "sparkles", free: .missing, pro: .text("28 types")),
    ProFeature(title: "Odds for buy and sell zones, wait time, and price range", systemImage: "dice.fill", free: .text("30 days"), pro: .text("All")),
    ProFeature(title: "Your Profile: investor DNA and blind spots", systemImage: "person.text.rectangle.fill", free: .text("Preview"), pro: .included),
    ProFeature(title: "Passive income planner", systemImage: "leaf.circle.fill", free: .missing, pro: .included),
    ProFeature(title: "Live signals on your stocks", systemImage: "dot.radiowaves.left.and.right", free: .text("2"), pro: .text("All")),
    ProFeature(title: "Top investors' portfolios and moves", systemImage: "trophy.fill", free: .text("Preview"), pro: .included, needsFlock: true),
    ProFeature(title: "Follow investors and get their moves", systemImage: "bell.and.waves.left.and.right.fill", free: .missing, pro: .included, needsFlock: true),
    ProFeature(title: "What the flock is buying and selling", systemImage: "arrow.left.arrow.right", free: .text("1"), pro: .text("All"), needsFlock: true),
    ProFeature(title: "Full crowd report and Dip Radar", systemImage: "person.3.fill", free: .text("Preview"), pro: .included, needsFlock: true),
    ProFeature(title: "Your portfolio vs any ETF or index", systemImage: "flag.checkered", free: .missing, pro: .included),
    ProFeature(title: "Heads-up before a stock reaches your zone", systemImage: "bell.badge.fill", free: .missing, pro: .included),
    ProFeature(title: "Dividend calendar", systemImage: "leaf.fill", free: .missing, pro: .included),
    ProFeature(title: "Dippy's top hat and monocle", systemImage: "crown.fill", free: .missing, pro: .included),
  ]

  @ViewBuilder
  static func cell(_ value: Value, isPro: Bool) -> some View {
    switch value {
    case .text(let text):
      Text(LocalizedStringKey(text))
        .font(.subheadline.weight(isPro ? .bold : .regular))
        .foregroundStyle(isPro ? AnyShapeStyle(Brand.buy) : AnyShapeStyle(.white.opacity(0.5)))
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    case .included:
      Image(systemName: "checkmark.circle.fill")
        .font(.title3)
        .foregroundStyle(Brand.buy)
    case .missing:
      Image(systemName: "minus")
        .font(.subheadline.weight(.bold))
        .foregroundStyle(.white.opacity(0.3))
    }
  }
}
