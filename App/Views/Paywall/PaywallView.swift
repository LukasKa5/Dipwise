import StoreKit
import SwiftData
import SwiftUI

/// Dipwise Pro offer with yearly, monthly, and lifetime plans.
struct PaywallView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(SubscriptionManager.self) private var subscription
  @State private var products: [Product] = []
  @State private var selectedID = SubscriptionManager.yearlyID
  @State private var isLoading = true
  @State private var isPurchasing = false
  @State private var errorMessage: String?
  @State private var flaps = 0
  @State private var pulse = false
  @State private var didPurchase = false
  @State private var celebrationCount = 0
  @Query private var holdings: [Holding]
  @Environment(QuoteStore.self) private var quotes


  private var selected: Product? { products.first { $0.id == selectedID } }

  var body: some View {
    ScrollView {
      VStack(spacing: 26) {
        header
        personalPreview
        comparison
        plans
        if let offer = selected?.subscription?.introductoryOffer, offer.paymentMode == .freeTrial {
          trialTimeline(offer)
        }
        VStack(spacing: 12) {
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
            .foregroundStyle(.white.opacity(0.55))
            .multilineTextAlignment(.center)

          HStack(spacing: 18) {
            Button("Restore") {
              Task {
                await subscription.restore()
                if subscription.isPro { dismiss() }
              }
            }
            Link("Terms", destination: AppLinks.termsOfUse)
            Link("Privacy", destination: AppLinks.privacyPolicy)
          }
          .font(.footnote.weight(.semibold))
          .foregroundStyle(.white.opacity(0.75))
        }
      }
      .padding(.horizontal, 22)
      .padding(.bottom, 32)
      .frame(maxWidth: 560)
      .frame(maxWidth: .infinity)
    }
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

  // MARK: Sections

  private var header: some View {
    VStack(spacing: 12) {
      LivelyOwl(hopsOnTap: true, mood: .celebrating)
        .frame(width: 104, height: 120)
        .owlFlight(trigger: flaps, height: 30)
        .padding(.top, 40)
      Text("Let Dippy watch everything")
        .font(.largeTitle.bold())
        .multilineTextAlignment(.center)
      Text("Unlimited alerts, 23 smart signals, odds for every plan, and the whole flock.")
        .font(.headline)
        .foregroundStyle(.white.opacity(0.7))
        .multilineTextAlignment(.center)
    }
  }

  /// A taste of Pro using the user's own data.
  @ViewBuilder
  private var personalPreview: some View {
    if let alert = holdings.flatMap(\.activeAlerts).first, let quote = quotes[alert.symbol],
       let odds = AlertOdds(rule: alert.rule, quote: quote) {
      HStack(spacing: 14) {
        Image(systemName: "dice.fill")
          .font(.title2)
          .foregroundStyle(Brand.amber)
        VStack(alignment: .leading, spacing: 4) {
          Text("Your \(alert.symbol) alert has a \(odds.monthChance.formatted(.percent.precision(.fractionLength(0)))) chance to fire within 30 days.")
            .font(.subheadline.weight(.semibold))
          Text("Pro shows odds, signals, and track records for every alert you set.")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.65))
        }
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.white.opacity(0.08), in: .rect(cornerRadius: 18))
    }
  }

  private var comparison: some View {
    let rows: [(String, String, String)] = [
      ("Price alerts", "3", "Unlimited"),
      ("Smart alerts (RSI, MACD, crosses…)", "–", "23 types"),
      ("Odds for each alert", "1", "All"),
      ("Live signals on your stocks", "2", "All"),
      ("Full crowd report & Dip Radar", "Preview", "✓"),
      ("Dividend calendar", "–", "✓"),
      ("Heads-up before a zone", "–", "✓"),
    ]
    return VStack(spacing: 0) {
      HStack {
        Text("")
          .frame(maxWidth: .infinity, alignment: .leading)
        Text("Free")
          .font(.caption.weight(.bold))
          .foregroundStyle(.white.opacity(0.6))
          .frame(width: 64)
        Text("Pro")
          .font(.caption.weight(.heavy))
          .foregroundStyle(Brand.owlInk)
          .padding(.horizontal, 10)
          .padding(.vertical, 3)
          .background(Brand.amber, in: .capsule)
          .frame(width: 84)
      }
      .padding(.bottom, 8)
      ForEach(rows, id: \.0) { row in
        HStack {
          Text(row.0)
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
          Text(row.1)
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.5))
            .frame(width: 64)
          Text(row.2)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(Brand.buy)
            .frame(width: 84)
        }
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
        if row.0 != rows.last?.0 {
          Divider().overlay(.white.opacity(0.1))
        }
      }
    }
    .padding(16)
    .background(.white.opacity(0.06), in: .rect(cornerRadius: 20))
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
        LivelyOwl(mood: .celebrating)
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
      try? await Task.sleep(for: .seconds(3.5))
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
          PlanCard(product: product, isSelected: product.id == selectedID, badge: badge(for: product), detail: detail(for: product)) {
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
    case .day: return "\(period.value)-day"
    case .week: return period.value == 1 ? "7-day" : "\(period.value)-week"
    case .month: return "\(period.value)-month"
    default: return "Free trial"
    }
  }

  private var ctaTitle: String {
    if let offer = selected?.subscription?.introductoryOffer, offer.paymentMode == .freeTrial {
      return "Start \(trialText(offer)) Free Trial"
    }
    return selected?.id == SubscriptionManager.lifetimeID ? "Unlock Forever" : "Continue"
  }

  private var finePrint: String {
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
  var detail: String
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
