import SwiftUI

/// What the portfolio is compared with: any index, ETF, stock, or crypto, chosen by the user.
struct BenchmarkChoice: Hashable, Identifiable {
  var symbol: String
  var name: String
  var id: String { symbol }

  static let presets: [BenchmarkChoice] = [
    BenchmarkChoice(symbol: "^GSPC", name: "S&P 500"),
    BenchmarkChoice(symbol: "QQQ", name: "Nasdaq 100 (QQQ)"),
    BenchmarkChoice(symbol: "VTI", name: "Total US Market (VTI)"),
    BenchmarkChoice(symbol: "VT", name: "Total World (VT)"),
    BenchmarkChoice(symbol: "VWCE.DE", name: "FTSE All-World (VWCE)"),
    BenchmarkChoice(symbol: "SCHD", name: "US Dividend (SCHD)"),
    BenchmarkChoice(symbol: "VGK", name: "Europe (VGK)"),
    BenchmarkChoice(symbol: "BTC-USD", name: "Bitcoin"),
  ]

  static let symbolKey = "benchmark.symbol"
  static let nameKey = "benchmark.name"
}

/// A menu of popular benchmarks, plus a search for any stock or ETF.
struct BenchmarkMenu: View {
  @AppStorage(BenchmarkChoice.symbolKey) private var symbol = "^GSPC"
  @AppStorage(BenchmarkChoice.nameKey) private var name = "S&P 500"
  @State private var showsSearch = false

  var body: some View {
    Menu {
      Picker("Compare with", selection: Binding(get: { symbol }, set: { choose($0) })) {
        ForEach(BenchmarkChoice.presets) { Text($0.name).tag($0.symbol) }
        if !BenchmarkChoice.presets.contains(where: { $0.symbol == symbol }) {
          Text(name).tag(symbol)
        }
      }
      Button("Any Stock or ETF…", systemImage: "magnifyingglass") { showsSearch = true }
    } label: {
      HStack(spacing: 4) {
        Text("vs \(name)")
          .lineLimit(1)
          .minimumScaleFactor(0.7)
        Image(systemName: "chevron.up.chevron.down")
          .font(.caption2.weight(.bold))
      }
      .font(.subheadline.weight(.semibold))
    }
    .sheet(isPresented: $showsSearch) {
      BenchmarkSearch { match in
        symbol = match.symbol
        name = match.name
      }
    }
  }

  private func choose(_ newSymbol: String) {
    guard let choice = BenchmarkChoice.presets.first(where: { $0.symbol == newSymbol }) else { return }
    symbol = choice.symbol
    name = choice.name
  }
}

/// Search for any symbol to compare with.
private struct BenchmarkSearch: View {
  var choose: (SymbolMatch) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var query = ""
  @State private var results: [SymbolMatch] = []

  var body: some View {
    NavigationStack {
      List(results) { match in
        Button {
          choose(match)
          dismiss()
        } label: {
          HStack(spacing: 12) {
            TickerBadge(symbol: match.symbol, size: 34)
            VStack(alignment: .leading, spacing: 2) {
              Text(match.symbol).font(.headline)
              Text(match.name)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
          }
        }
        .buttonStyle(.plain)
      }
      .overlay {
        if results.isEmpty {
          ContentUnavailableView("Compare With Anything", systemImage: "chart.line.uptrend.xyaxis",
                                 description: Text("Search for an ETF, index, stock, or crypto."))
        }
      }
      .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "ETF, index, or stock")
      .task(id: query) {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { results = []; return }
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        results = (try? await QuoteService().search(text)) ?? []
      }
      .navigationTitle("Compare With")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
      }
    }
  }
}
