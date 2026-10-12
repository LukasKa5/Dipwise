import SwiftData
import SwiftUI

/// Second step of adding a stock: optional position details, then straight on to its alerts.
struct StockSetupView: View {
  var match: SymbolMatch
  var onAdded: (String) -> Void

  @Environment(\.modelContext) private var modelContext
  @Environment(QuoteStore.self) private var quotes
  @Environment(FlockService.self) private var flock
  @State private var quote: Quote?
  @State private var ownsIt = false
  @State private var shares: Double?
  @State private var averageCost: Double?
  @State private var added: Holding?

  var body: some View {
    Form {
      Group {
        Section {
          HStack(spacing: 14) {
            TickerBadge(symbol: match.symbol, size: 50)
            VStack(alignment: .leading, spacing: 2) {
              Text(match.name)
                .font(.headline)
                .lineLimit(2)
              if let quote {
                HStack(spacing: 8) {
                  Text(quote.formatted(quote.price))
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
                  ChangeBadge(change: quote.change)
                    .lineLimit(1)
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
      }
      .dipwiseRows()
    }
    .dipwiseListStyle()
    .navigationTitle(match.symbol)
    .navigationBarTitleDisplayMode(.inline)
    .safeAreaInset(edge: .bottom) {
      VStack(spacing: 8) {
        Button(action: save) {
          Label("Next: Set Alerts", systemImage: "bell.badge.fill")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .disabled(quote == nil)
        Text("Choose a buy zone, a sell zone, or smart alerts. You can skip this.")
          .font(.caption)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
      .padding(.horizontal, 20)
      .padding(.top, 10)
      .padding(.bottom, 6)
      .frame(maxWidth: 560)
      .frame(maxWidth: .infinity)
      .background(Palette.canvas)
    }
    .navigationDestination(item: $added) { holding in
      PlanBuilderForm(holding: holding, isNewStock: true) {
        onAdded(holding.symbol)
      }
    }
    .task {
      quote = quotes[match.symbol]
      if let fresh = try? await QuoteService().quote(for: match.symbol) {
        quote = fresh
        quotes.store(fresh)
      }
      if let quote {
        await flock.load(symbol: match.symbol, currentPrice: quote.price)
      }
    }
  }

  private func save() {
    guard let quote, added == nil else { return }
    let holding = Holding(
      symbol: match.symbol,
      name: quote.name.isEmpty ? match.name : quote.name,
      shares: ownsIt ? (shares ?? 0) : 0,
      averageCost: ownsIt ? (averageCost ?? 0) : 0
    )
    modelContext.insert(holding)
    try? modelContext.save()
    SnapshotPublisher.publish(context: modelContext)
    added = holding
  }
}
