import SwiftData
import SwiftUI

/// Second step of adding a stock: optional position details and a first buy zone.
struct StockSetupView: View {
  var match: SymbolMatch
  var onAdded: (String) -> Void

  @Environment(\.modelContext) private var modelContext
  @Environment(QuoteStore.self) private var quotes
  @Environment(SubscriptionManager.self) private var subscription
  @Environment(FlockService.self) private var flock
  @State private var quote: Quote?
  @State private var ownsIt = false
  @State private var shares: Double?
  @State private var averageCost: Double?
  @State private var addsZone = true
  @State private var lower: Double = 0
  @State private var upper: Double = 0
  @State private var showsPaywall = false

  private var canAddAlert: Bool {
    AlertLimits.canAddAlert(in: modelContext, isPro: subscription.isPro)
  }

  private func format(_ value: Double) -> String { quote?.formatted(value) ?? value.formatted() }

  var body: some View {
    Form {
      Section {
        HStack(spacing: 14) {
          TickerBadge(symbol: match.symbol, size: 50)
          VStack(alignment: .leading, spacing: 2) {
            Text(match.name)
              .font(.headline)
            if let quote {
              HStack(spacing: 8) {
                Text(quote.formatted(quote.price))
                  .monospacedDigit()
                ChangeBadge(change: quote.change)
              }
              .font(.subheadline)
            } else {
              Text("Loading price…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
          }
        }
      }

      Section {
        Toggle("I own this", isOn: $ownsIt.animation(.smooth))
        if ownsIt {
          LabeledContent("Shares") {
            TextField("0", value: $shares, format: .number)
              .keyboardType(.decimalPad)
              .multilineTextAlignment(.trailing)
          }
          LabeledContent("Average cost") {
            TextField("Optional", value: $averageCost, format: .number.precision(.fractionLength(2)))
              .keyboardType(.decimalPad)
              .multilineTextAlignment(.trailing)
          }
        }
      } footer: {
        Text("Leave this off to simply watch the stock. Dipwise never connects to your broker.")
      }

      Section {
        if canAddAlert {
          Toggle("Set a buy zone", isOn: $addsZone.animation(.smooth))
          if addsZone, let quote {
            ZoneEditorChart(values: quote.recent(64).values, side: .buy, lower: $lower, upper: $upper,
                            crowdZone: flock.reports[match.symbol]?.buyZone, format: format)
              .frame(height: 220)
            LabeledContent("Zone", value: "\(format(lower))–\(format(upper))")
          }
        } else {
          UpgradeRow(text: "The free plan includes \(FreeTier.maxActiveAlerts) active alerts. Upgrade to plan every stock.") {
            showsPaywall = true
          }
        }
      } header: {
        Text("Your plan")
      } footer: {
        Text("Drag the handles to the range where you'd happily buy more. You can add a sell zone and smart alerts later.")
      }
    }
    .navigationTitle(match.symbol)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button("Start Watching", action: save)
          .disabled(quote == nil)
      }
    }
    .sheet(isPresented: $showsPaywall) { PaywallView() }
    .task {
      quote = quotes[match.symbol]
      if let fresh = try? await QuoteService().quote(for: match.symbol) {
        quote = fresh
        quotes.store(fresh)
      }
      if let quote, lower == 0 {
        lower = (quote.price * 0.90 * 100).rounded() / 100
        upper = (quote.price * 0.95 * 100).rounded() / 100
        await flock.load(symbol: match.symbol, currentPrice: quote.price)
      }
    }
  }

  private func save() {
    guard let quote else { return }
    let holding = Holding(
      symbol: match.symbol,
      name: quote.name.isEmpty ? match.name : quote.name,
      shares: ownsIt ? (shares ?? 0) : 0,
      averageCost: ownsIt ? (averageCost ?? 0) : 0
    )
    modelContext.insert(holding)
    if addsZone, canAddAlert, upper > lower, lower > 0 {
      let alert = PriceAlert(rule: AlertRule(kind: .buyZone, lower: lower, upper: upper), priceAtCreation: quote.price)
      alert.holding = holding
      modelContext.insert(alert)
      Task {
        await NotificationManager.requestAuthorization()
        await flock.share(alert)
        try? modelContext.save()
      }
    }
    try? modelContext.save()
    SnapshotPublisher.publish(context: modelContext)
    onAdded(holding.symbol)
  }
}

struct UpgradeRow: View {
  var text: String
  var action: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        ProBadge()
        Text("Unlimited alerts")
          .font(.headline)
      }
      Text(text)
        .font(.subheadline)
        .foregroundStyle(.secondary)
      Button("See Dipwise Pro", action: action)
        .buttonStyle(.borderedProminent)
    }
    .padding(.vertical, 4)
  }
}
