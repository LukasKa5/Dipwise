import SwiftData
import SwiftUI

/// Flock statistics for any symbol, including ones the user doesn't follow.
struct FlockDetailView: View {
  var symbol: String

  @Query private var matches: [Holding]
  @Environment(QuoteStore.self) private var quotes
  @State private var quote: Quote?
  @State private var showsAddStock = false

  init(symbol: String) {
    self.symbol = symbol
    _matches = Query(filter: #Predicate<Holding> { $0.symbol == symbol })
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        if let quote {
          HStack(spacing: 14) {
            TickerBadge(symbol: symbol, size: 50)
            VStack(alignment: .leading, spacing: 2) {
              Text(quote.name)
                .font(.headline)
              HStack(spacing: 8) {
                Text(quote.formatted(quote.price)).monospacedDigit()
                ChangeBadge(change: quote.change)
              }
              .font(.subheadline)
            }
          }
          .padding(.top, 8)
        }
        FlockStatsSection(symbol: symbol, quote: quote, userAlerts: matches.first?.activeAlerts ?? [])
        if matches.isEmpty {
          Button {
            showsAddStock = true
          } label: {
            Label("Watch \(symbol)", systemImage: "binoculars.fill")
              .font(.headline)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 6)
          }
          .buttonStyle(.borderedProminent)
        }
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 32)
      .frame(maxWidth: 700)
      .frame(maxWidth: .infinity)
    }
    .background(Palette.canvas)
    .navigationTitle(symbol)
    .navigationBarTitleDisplayMode(.inline)
    .sheet(isPresented: $showsAddStock) {
      NavigationStack {
        StockSetupView(match: SymbolMatch(symbol: symbol, name: quote?.name ?? symbol, exchange: "", type: "")) { _ in
          showsAddStock = false
        }
      }
    }
    .task {
      quote = quotes[symbol]
      if quote == nil, let fresh = try? await QuoteService().quote(for: symbol) {
        quote = fresh
      }
    }
  }
}
