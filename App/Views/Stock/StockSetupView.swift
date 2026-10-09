import SwiftData
import SwiftUI

/// Second step of adding a stock: optional position details and a first price target.
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
  @State private var addsAlert = true
  @State private var kind: TargetKind = .buyBelow
  @State private var target: Double?
  @State private var note = ""
  @State private var showsPaywall = false

  private var canAddAlert: Bool {
    AlertLimits.canAddAlert(in: modelContext, isPro: subscription.isPro)
  }

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
        Text("Leave this off to simply watch the stock.")
      }

      Section {
        if canAddAlert {
          Toggle("Set a price target", isOn: $addsAlert.animation(.smooth))
          if addsAlert {
            Picker("Alert type", selection: $kind) {
              ForEach(TargetKind.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .onChange(of: kind) { prefillTarget(force: true) }
            TargetPriceField(price: $target, kind: kind, quote: quote)
            TextField("Why this price? (shown in the alert)", text: $note, axis: .vertical)
          }
        } else {
          UpgradeRow(text: "The free plan includes \(FreeTier.maxActiveAlerts) active alerts. Upgrade to set unlimited targets.") {
            showsPaywall = true
          }
        }
      } header: {
        Text("Price target")
      }
    }
    .navigationTitle(match.symbol)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button("Start Watching", action: save)
          .disabled(quote == nil || (addsAlert && canAddAlert && (target ?? 0) <= 0))
      }
    }
    .sheet(isPresented: $showsPaywall) { PaywallView() }
    .task {
      quote = quotes[match.symbol]
      if let fresh = try? await QuoteService().quote(for: match.symbol) {
        quote = fresh
        quotes.store(fresh)
      }
      prefillTarget(force: false)
    }
  }

  /// Suggests a target 10% away so the user can save with one tap.
  private func prefillTarget(force: Bool) {
    guard let quote, force || target == nil else { return }
    let offset = kind == .buyBelow ? -0.10 : 0.10
    target = (quote.price * (1 + offset) * 100).rounded() / 100
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
    if addsAlert, canAddAlert, let target, target > 0 {
      let alert = PriceAlert(kind: kind, targetPrice: target, priceAtCreation: quote.price, note: note)
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
