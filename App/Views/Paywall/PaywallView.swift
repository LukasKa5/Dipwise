import StoreKit
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

  private let features: [(String, String, String)] = [
    ("scope", "Unlimited buy & sell zones", "Plan every stock you care about, not just three."),
    ("sparkles", "Smart alerts", "Dips from the 52-week high, trailing stops, big daily moves, and moving averages."),
    ("person.3.fill", "The full crowd report", "Where investors buy and sell, momentum, live activity, and track records."),
    ("dot.radiowaves.left.and.right", "Dip Radar", "Every popular stock trading inside the crowd's buy zone right now."),
    ("leaf.fill", "Dividend calendar", "Your monthly income and upcoming payments."),
    ("waveform.path.ecg", "Heads-up alerts", "A quiet nudge before a stock reaches your zone."),
  ]

  private var selected: Product? { products.first { $0.id == selectedID } }

  var body: some View {
    ScrollView {
      VStack(spacing: 26) {
        VStack(spacing: 14) {
          LivelyOwl()
            .frame(width: 96, height: 110)
          Text("Dipwise Pro")
            .font(.largeTitle.bold())
          Text("Invest calmly. Let the owl and the flock do the watching.")
            .font(.headline)
            .foregroundStyle(.white.opacity(0.7))
            .multilineTextAlignment(.center)
        }
        .padding(.top, 40)

        VStack(alignment: .leading, spacing: 16) {
          ForEach(features, id: \.1) { feature in
            HStack(alignment: .top, spacing: 14) {
              Image(systemName: feature.0)
                .font(.headline)
                .foregroundStyle(Brand.mint)
                .frame(width: 30)
              VStack(alignment: .leading, spacing: 2) {
                Text(feature.1).font(.headline)
                Text(feature.2)
                  .font(.subheadline)
                  .foregroundStyle(.white.opacity(0.65))
              }
            }
            .accessibilityElement(children: .combine)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        plans

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
            .padding(.vertical, 8)
          }
          .buttonStyle(.borderedProminent)
          .tint(Brand.mint)
          .foregroundStyle(Brand.owlInk)
          .disabled(selected == nil || isPurchasing)

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
      .padding(.horizontal, 24)
      .padding(.bottom, 32)
      .frame(maxWidth: 560)
      .frame(maxWidth: .infinity)
    }
    .foregroundStyle(.white)
    .background(Brand.nightGradient.ignoresSafeArea())
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
    .task { await loadProducts() }
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
