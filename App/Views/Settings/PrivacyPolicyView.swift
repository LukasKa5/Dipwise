import SwiftUI

/// Dipwise's privacy policy, readable inside the app. The same text is in Marketing/AppStore/PrivacyPolicy.md for hosting.
struct PrivacyPolicyView: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        Text("Dipwise is built so your money stays your business. There are no ads, no trackers, and no data sales.")
          .font(.headline)
        section("What stays on your device", "Your stocks, shares, average costs, cash, alerts, notes, journal, streaks, and settings are stored on your iPhone and shared only with your own Apple Watch and widgets. Dipwise has no accounts, so it never asks for your name or email.")
        section("What the Flock shares, if you allow it", "With \"Share my alerts anonymously\" on, Dipwise shares each alert's ticker, type, and price levels. With \"Share my portfolio mix anonymously\" on, it shares the percentage each stock makes up of your portfolio, and when you add to or trim a position. Both are stored in Apple's CloudKit public database under a random identifier created on your device. They never include your name, email, amounts, share counts, prices you paid, or notes. Turn either off in Settings to remove that data.")
        section("Market data", "To show prices, Dipwise requests quotes for the tickers you follow from a market data provider. Those requests contain ticker symbols only.")
        section("Purchases", "Subscriptions are handled by Apple. Dipwise never sees your payment details.")
        section("No tracking", "Dipwise does not track you across apps or websites, does not use advertising identifiers, and does not include third-party analytics.")
        section("Your choices", "You can stop sharing with the Flock at any time in Settings, which removes your shared data. Deleting the app deletes everything stored on your device.")
        section("Not advice", "Dipwise is not a broker and does not give investment advice. Odds, crowd statistics, and signals are information, not recommendations.")
        Text("Questions? Contact us from Settings → Contact Support.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
      .padding(20)
      .frame(maxWidth: 700, alignment: .leading)
      .frame(maxWidth: .infinity)
    }
    .navigationTitle("Privacy Policy")
    .navigationBarTitleDisplayMode(.inline)
  }

  private func section(_ title: LocalizedStringKey, _ body: LocalizedStringKey) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.title3.bold())
      Text(body)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}
