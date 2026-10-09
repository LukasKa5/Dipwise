import SwiftUI

/// Full flock statistics for one symbol. Detailed parts are Dipwise Pro.
struct FlockStatsView: View {
  var stats: FlockStats
  var quote: Quote?
  var userAlerts: [PriceAlert]
  var isPro: Bool

  private func price(_ value: Double) -> String {
    quote?.formatted(value) ?? value.formatted(.number.precision(.fractionLength(2)))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
        StatTile(title: "Investors watching", value: stats.watcherCount.formatted(), systemImage: "person.3.fill", tint: Palette.green)
        StatTile(title: "Waiting to buy", value: stats.buyShare.formatted(.percent.precision(.fractionLength(0))), systemImage: "arrow.down.to.line", tint: Palette.amber)
        StatTile(title: "Median buy target", value: stats.medianBuy.map(price) ?? "—", systemImage: "cart.fill", tint: Palette.amber)
        StatTile(title: "Median sell target", value: stats.medianSell.map(price) ?? "—", systemImage: "flag.fill", tint: Palette.green)
      }

      VStack(alignment: .leading, spacing: 18) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Where the flock is waiting")
            .font(.headline)
          Text("Alert levels relative to today's price")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        FlockHistogram(stats: stats, userTargets: userAlerts.map(\.targetPrice))
          .frame(height: 210)

        Divider()

        VStack(alignment: .leading, spacing: 14) {
          if let crowded = stats.crowdedLevel {
            InsightRow(systemImage: "scope", tint: Palette.amber,
                       title: "Most crowded level: \(price(crowded))",
                       detail: "More alerts cluster here than anywhere else. Prices often react around levels many investors watch.")
          }
          let near = stats.alertsNearPrice()
          InsightRow(systemImage: "bell.and.waves.left.and.right.fill", tint: Palette.green,
                     title: "\(near) alerts within 5% of today's price",
                     detail: near > stats.watcherCount / 4 ? "A lot of the flock is close to acting." : "Most of the flock is waiting for a bigger move.")
          ForEach(userAlerts) { alert in
            if let patience = stats.patience(of: alert.targetPrice, kind: alert.kind) {
              InsightRow(systemImage: "person.fill", tint: Palette.green,
                         title: "Your \(alert.kind.shortTitle.lowercased()) target \(price(alert.targetPrice))",
                         detail: "More patient than \(patience.formatted(.percent.precision(.fractionLength(0)))) of investors with a \(alert.kind.shortTitle.lowercased()) target.")
            }
          }
        }
      }
      .padding(18)
      .cardStyle()
      .proLocked(!isPro, message: "See exactly where other investors set their alerts")

      if stats.isSample {
        Label("Sample data shown until Flock sync is connected.", systemImage: "info.circle")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }
}

struct StatTile: View {
  var title: String
  var value: String
  var systemImage: String
  var tint: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Image(systemName: systemImage)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(tint)
      Text(value)
        .font(.title3.bold())
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      Text(title)
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .cardStyle(cornerRadius: 20)
    .accessibilityElement(children: .combine)
  }
}

private struct InsightRow: View {
  var systemImage: String
  var tint: Color
  var title: String
  var detail: String

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: systemImage)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(tint)
        .frame(width: 32, height: 32)
        .background(tint.opacity(0.14), in: .circle)
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.subheadline.weight(.semibold))
        Text(detail)
          .font(.footnote)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .accessibilityElement(children: .combine)
  }
}

/// Loads and shows flock statistics inside a stock's detail screen.
struct FlockStatsSection: View {
  var symbol: String
  var quote: Quote?
  var userAlerts: [PriceAlert]

  @Environment(FlockService.self) private var flock
  @Environment(SubscriptionManager.self) private var subscription

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      SectionHeader(title: "The Flock", subtitle: "Anonymous alerts from other Dipwise investors") {
        if !subscription.isPro { ProBadge() }
      }
      if !flock.isAvailable {
        EmptyHint(systemImage: "person.3", text: "Flock statistics are coming soon.")
      } else if let stats = flock.stats[symbol] {
        if stats.hasEnoughData {
          FlockStatsView(stats: stats, quote: quote, userAlerts: userAlerts, isPro: subscription.isPro)
        } else {
          EmptyHint(systemImage: "person.3", text: "Not enough investors are watching \(symbol) yet. Your alerts help build the flock.")
        }
      } else {
        ProgressView()
          .frame(maxWidth: .infinity, minHeight: 120)
      }
    }
    .task(id: quote?.price) {
      if let quote { await flock.load(symbol: symbol, currentPrice: quote.price) }
    }
  }
}
