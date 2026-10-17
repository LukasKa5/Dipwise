import SwiftData
import SwiftUI

/// Every stock the user follows, with price, trend, and how close it is to their plan.
struct WatchlistView: View {
  private enum Sort: String, CaseIterable, Identifiable {
    case added = "Date added"
    case symbol = "Name"
    case change = "Today's move"
    case value = "Position value"
    case closest = "Closest to a plan"
    var id: Self { self }
  }

  @Query(sort: \Holding.addedAt) private var holdings: [Holding]
  @Environment(QuoteStore.self) private var quotes
  @Environment(FlockService.self) private var flock
  @Environment(\.modelContext) private var modelContext
  @AppStorage("watchlistSort") private var sortRaw = Sort.added.rawValue
  @State private var showsAddStock = false
  @State private var path: [String] = []
  @State private var search = ""

  private var sort: Sort { Sort(rawValue: sortRaw) ?? .added }

  private var sorted: [Holding] {
    let filtered = search.isEmpty ? holdings : holdings.filter {
      $0.symbol.localizedCaseInsensitiveContains(search) || $0.name.localizedCaseInsensitiveContains(search)
    }
    switch sort {
    case .added: return filtered
    case .symbol: return filtered.sorted { $0.symbol < $1.symbol }
    case .change: return filtered.sorted { (quotes[$0.symbol]?.change ?? 0) > (quotes[$1.symbol]?.change ?? 0) }
    case .value: return filtered.sorted { value(of: $0) > value(of: $1) }
    case .closest: return filtered.sorted { nearestDistance($0) < nearestDistance($1) }
    }
  }

  private func value(of holding: Holding) -> Double {
    quotes[holding.symbol].flatMap { quotes.toBase(holding.value(at: $0.price), from: $0.currency) } ?? 0
  }

  private func nearestDistance(_ holding: Holding) -> Double {
    guard let quote = quotes[holding.symbol] else { return .infinity }
    return holding.activeAlerts.compactMap { $0.distance(for: quote) }.min() ?? .infinity
  }

  var body: some View {
    NavigationStack(path: $path) {
      List {
        if !holdings.isEmpty {
          Section {
            summary
              .listRowBackground(Color.clear)
              .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
          }
        }
        Section {
          ForEach(sorted) { holding in
            NavigationLink(value: holding.symbol) {
              WatchlistRow(holding: holding, quote: quotes[holding.symbol])
            }
            .listRowBackground(Palette.card)
          }
          .onDelete { offsets in
            let items = offsets.map { sorted[$0] }
            for holding in items {
              for alert in holding.alerts ?? [] {
                Task { await flock.withdraw(alert) }
              }
              modelContext.delete(holding)
            }
            try? modelContext.save()
            SnapshotPublisher.publish(context: modelContext)
          }
        }
      }
      .listStyle(.insetGrouped)
      .scrollContentBackground(.hidden)
      .background(Palette.canvas)
      .navigationTitle("Watchlist")
      .searchable(text: $search, prompt: "Search your stocks")
      .refreshable { await quotes.refresh(symbols: holdings.map(\.symbol)) }
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Menu("Sort", systemImage: "arrow.up.arrow.down") {
            Picker("Sort by", selection: $sortRaw) {
              ForEach(Sort.allCases) { Text($0.rawValue).tag($0.rawValue) }
            }
          }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Button("Add Stock", systemImage: "plus") { showsAddStock = true }
        }
      }
      .overlay {
        if holdings.isEmpty {
          ContentUnavailableView {
            Label("Your watchlist is empty", systemImage: "binoculars")
          } description: {
            Text("Add the stocks you own or want to buy. Dippy keeps an eye on them.")
          } actions: {
            Button("Add Stock") { showsAddStock = true }
              .buttonStyle(.borderedProminent)
          }
        }
      }
      .navigationDestination(for: String.self) { StockDetailView(symbol: $0) }
      .sheet(isPresented: $showsAddStock) {
        AddStockView { symbol in path = [symbol] }
      }
    }
  }

  private var summary: some View {
    let changes = holdings.compactMap { quotes[$0.symbol]?.change }
    let up = changes.filter { $0 > 0 }.count
    return HStack(spacing: 12) {
      SummaryPill(value: "\(holdings.count)", label: holdings.count == 1 ? "stock" : "stocks", color: .primary)
      SummaryPill(value: "\(up)", label: "up today", color: Palette.gain)
      SummaryPill(value: "\(changes.count - up)", label: "down today", color: Palette.loss)
    }
  }
}

private struct SummaryPill: View {
  var value: String
  var label: LocalizedStringKey
  var color: Color

  var body: some View {
    VStack(spacing: 2) {
      Text(value)
        .font(.title3.bold().monospacedDigit())
        .foregroundStyle(color)
      Text(label)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
    }
    .lineLimit(1)
    .minimumScaleFactor(0.7)
    .frame(maxWidth: .infinity)
    .padding(.vertical, 12)
    .padding(.horizontal, 6)
    .background(Palette.card, in: .rect(cornerRadius: 18))
    .accessibilityElement(children: .combine)
  }
}

private struct WatchlistRow: View {
  var holding: Holding
  var quote: Quote?
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  private var nearest: PriceAlert? {
    guard let quote else { return nil }
    return holding.activeAlerts.min { ($0.distance(for: quote) ?? .infinity) < ($1.distance(for: quote) ?? .infinity) }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 12) {
        TickerBadge(symbol: holding.symbol, size: 44)
        VStack(alignment: .leading, spacing: 2) {
          Text(holding.symbol)
            .font(.headline)
            .lineLimit(1)
          Text(holding.isOwned ? "\(holding.shares.formatted()) shares" : holding.name)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        Spacer(minLength: 4)
        if let quote {
          // Long names truncate before anything else, so the price never wraps.
          if !dynamicTypeSize.isAccessibilitySize {
            Sparkline(values: Array(quote.closes.suffix(22)))
              .frame(width: 56, height: 30)
          }
          VStack(alignment: .trailing, spacing: 4) {
            Text(quote.formatted(quote.price))
              .font(.headline.monospacedDigit())
              .lineLimit(1)
            Text(quote.change, format: .percent.precision(.fractionLength(2)).sign(strategy: .always()))
              .font(.caption.weight(.bold).monospacedDigit())
              .lineLimit(1)
              .foregroundStyle(.white)
              .padding(.horizontal, 8)
              .padding(.vertical, 3)
              .background(quote.change >= 0 ? Palette.gain : Palette.loss, in: .capsule)
          }
          .fixedSize()
          .layoutPriority(2)
        } else {
          ProgressView()
        }
      }
      if let nearest, let quote {
        HStack(spacing: 8) {
          Image(systemName: nearest.kind.systemImage)
            .font(.caption.weight(.bold))
            .foregroundStyle(nearest.kind.side.color)
          Text(nearest.summary(for: quote))
            .font(.caption.weight(.semibold))
            .foregroundStyle(nearest.kind.side.color)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
          Spacer(minLength: 6)
          Text(nearest.distance(for: quote).map { $0 == 0 ? "Now" : "\($0.formatted(.percent.precision(.fractionLength(1)))) away" } ?? "")
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .fixedSize()
        }
      } else {
        Label("No alerts yet", systemImage: "bell.slash")
          .font(.caption)
          .foregroundStyle(.tertiary)
      }
    }
    .padding(.vertical, 6)
    .accessibilityElement(children: .combine)
  }
}
