import SwiftData
import SwiftUI

/// Pick one of the watched stocks and enter how many shares you own.
struct AddPositionSheet: View {
  /// Called when the user wants a stock that isn't on their watchlist yet.
  var searchOther: () -> Void

  @Query(sort: \Holding.addedAt) private var holdings: [Holding]
  @Environment(QuoteStore.self) private var quotes
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      List {
        Group {
          Section {
            ForEach(holdings) { holding in
              NavigationLink(value: holding) {
                HStack(spacing: 12) {
                  TickerBadge(symbol: holding.symbol, size: 40)
                  VStack(alignment: .leading, spacing: 2) {
                    Text(holding.symbol)
                      .font(.headline)
                    Text(holding.name)
                      .font(.subheadline)
                      .foregroundStyle(.secondary)
                      .lineLimit(1)
                  }
                  .layoutPriority(1)
                  Spacer(minLength: 8)
                  if let quote = quotes[holding.symbol] {
                    Text(quote.formatted(quote.price))
                      .font(.subheadline.weight(.semibold).monospacedDigit())
                      .lineLimit(1)
                      .fixedSize()
                  }
                }
              }
            }
          } header: {
            Text("Stocks you watch")
          } footer: {
            Text("Choose a stock you own. Dippy will track its value, returns, and dividends.")
          }

          Section {
            Button("Search for Another Stock", systemImage: "magnifyingglass") {
              dismiss()
              searchOther()
            }
          }
        }
        .dipwiseRows()
      }
      .dipwiseListStyle()
      .navigationTitle("Add to Portfolio")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
      .navigationDestination(for: Holding.self) { holding in
        PositionForm(holding: holding) { dismiss() }
      }
    }
  }
}
