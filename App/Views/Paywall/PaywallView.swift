import StoreKit
import SwiftUI

/// Dipwise Pro subscription offer.
struct PaywallView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(SubscriptionManager.self) private var subscription

  var body: some View {
    SubscriptionStoreView(productIDs: SubscriptionManager.productIDs) {
      PaywallHeader()
    }
    .subscriptionStoreControlStyle(.prominentPicker)
    .subscriptionStoreButtonLabel(.multiline)
    .storeButton(.visible, for: .restorePurchases, .redeemCode)
    .storeButton(.hidden, for: .cancellation)
    .subscriptionStorePolicyDestination(url: AppLinks.privacyPolicy, for: .privacyPolicy)
    .subscriptionStorePolicyDestination(url: AppLinks.termsOfUse, for: .termsOfService)
    .subscriptionStoreControlBackground(.gradientMaterial)
    .background(Brand.nightGradient)
    .tint(Brand.mint)
    .environment(\.colorScheme, .dark)
    .onInAppPurchaseCompletion { _, result in
      if case .success(.success) = result {
        await subscription.refreshEntitlements()
        dismiss()
      }
    }
    .overlay(alignment: .topTrailing) {
      Button("Close", systemImage: "xmark") { dismiss() }
        .labelStyle(.iconOnly)
        .font(.headline)
        .foregroundStyle(.white.opacity(0.8))
        .frame(width: 36, height: 36)
        .background(.white.opacity(0.12), in: .circle)
        .padding()
    }
  }
}

private struct PaywallHeader: View {
  private let features: [(String, String, String)] = [
    ("bell.badge.fill", "Unlimited price alerts", "Watch every stock you care about, not just three."),
    ("chart.bar.fill", "Full flock statistics", "See exactly where other investors wait to buy and sell."),
    ("waveform.path.ecg", "Heads-up alerts", "A quiet nudge when a stock gets close to your target."),
    ("person.fill.checkmark", "Compare your targets", "Know if you're more patient than the crowd."),
  ]

  var body: some View {
    VStack(spacing: 22) {
      OwlMark()
        .frame(height: 96)
        .padding(.top, 36)
      VStack(spacing: 6) {
        Text("Dipwise Pro")
          .font(.largeTitle.bold())
        Text("Your calm, always-on investing assistant")
          .font(.headline)
          .foregroundStyle(.white.opacity(0.7))
          .multilineTextAlignment(.center)
      }
      VStack(alignment: .leading, spacing: 16) {
        ForEach(features, id: \.1) { feature in
          HStack(alignment: .top, spacing: 14) {
            Image(systemName: feature.0)
              .font(.headline)
              .foregroundStyle(Brand.mint)
              .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
              Text(feature.1)
                .font(.headline)
              Text(feature.2)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.65))
            }
          }
          .accessibilityElement(children: .combine)
        }
      }
      .padding(.horizontal, 28)
    }
    .foregroundStyle(.white)
    .padding(.bottom, 8)
  }
}
