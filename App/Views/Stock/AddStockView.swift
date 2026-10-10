import SwiftData
import SwiftUI

/// Search for a stock, ETF, or crypto and start watching it.
struct AddStockView: View {
  var onAdded: (String) -> Void
  @Environment(\.dismiss) private var dismiss
  @Query private var holdings: [Holding]
  @State private var query = ""
  @State private var results: [SymbolMatch] = []
  @State private var isSearching = false
  @State private var searchFailed = false

  private static let popular: [SymbolMatch] = [
    SymbolMatch(symbol: "AAPL", name: "Apple Inc.", exchange: "NASDAQ", type: "Equity"),
    SymbolMatch(symbol: "NVDA", name: "NVIDIA Corporation", exchange: "NASDAQ", type: "Equity"),
    SymbolMatch(symbol: "MSFT", name: "Microsoft Corporation", exchange: "NASDAQ", type: "Equity"),
    SymbolMatch(symbol: "TSLA", name: "Tesla, Inc.", exchange: "NASDAQ", type: "Equity"),
    SymbolMatch(symbol: "AMZN", name: "Amazon.com, Inc.", exchange: "NASDAQ", type: "Equity"),
    SymbolMatch(symbol: "GOOGL", name: "Alphabet Inc.", exchange: "NASDAQ", type: "Equity"),
    SymbolMatch(symbol: "VOO", name: "Vanguard S&P 500 ETF", exchange: "NYSE Arca", type: "ETF"),
    SymbolMatch(symbol: "BTC-USD", name: "Bitcoin USD", exchange: "CCC", type: "Cryptocurrency"),
  ]

  var body: some View {
    NavigationStack {
      List {
        Group {
        if query.isEmpty {
          Section("Popular") {
            ForEach(Self.popular) { row(for: $0) }
          }
        } else if searchFailed {
          ContentUnavailableView("Search Unavailable", systemImage: "wifi.exclamationmark", description: Text("Check your connection and try again."))
        } else if results.isEmpty && !isSearching {
          ContentUnavailableView.search(text: query)
        } else {
          ForEach(results) { row(for: $0) }
        }
        }
        .dipwiseRows()
      }
      .dipwiseListStyle()
      .overlay {
        if isSearching && results.isEmpty { ProgressView() }
      }
      .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Company or ticker")
      .navigationTitle("Add Stock")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
      .navigationDestination(for: SymbolMatch.self) { match in
        StockSetupView(match: match) { symbol in
          dismiss()
          onAdded(symbol)
        }
      }
      .task(id: query) { await search() }
    }
  }

  @ViewBuilder
  private func row(for match: SymbolMatch) -> some View {
    let isAdded = holdings.contains { $0.symbol == match.symbol }
    if isAdded {
      Button {
        dismiss()
        onAdded(match.symbol)
      } label: {
        SymbolRow(match: match, isAdded: true)
      }
      .buttonStyle(.plain)
    } else {
      NavigationLink(value: match) {
        SymbolRow(match: match, isAdded: false)
      }
    }
  }

  private func search() async {
    let text = query.trimmingCharacters(in: .whitespaces)
    guard !text.isEmpty else {
      results = []
      return
    }
    try? await Task.sleep(for: .milliseconds(300))
    guard !Task.isCancelled else { return }
    isSearching = true
    defer { isSearching = false }
    do {
      results = try await QuoteService().search(text)
      searchFailed = false
    } catch {
      if !Task.isCancelled { searchFailed = true }
    }
  }
}

private struct SymbolRow: View {
  var match: SymbolMatch
  var isAdded: Bool

  var body: some View {
    HStack(spacing: 12) {
      TickerBadge(symbol: match.symbol, size: 38)
      VStack(alignment: .leading, spacing: 2) {
        Text(match.symbol)
          .font(.headline)
        Text(match.name)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      Spacer()
      if isAdded {
        Text("Added")
          .font(.caption.bold())
          .foregroundStyle(.secondary)
      } else {
        Text([match.type, match.exchange].filter { !$0.isEmpty }.joined(separator: " · "))
          .font(.caption)
          .foregroundStyle(.tertiary)
      }
    }
    .contentShape(.rect)
  }
}
