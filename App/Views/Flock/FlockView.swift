import SwiftData
import SwiftUI

/// Explore what the Dipwise flock is watching.
struct FlockView: View {
  @Query(sort: \Holding.addedAt) private var holdings: [Holding]
  @Environment(FlockService.self) private var flock
  @Environment(QuoteStore.self) private var quotes
  @State private var query = ""
  @State private var results: [SymbolMatch] = []

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 28) {
          if !query.isEmpty {
            searchResults
          } else if !flock.isAvailable {
            ContentUnavailableView("The Flock Is Gathering", systemImage: "person.3", description: Text("Anonymous statistics from other Dipwise investors will appear here soon."))
          } else {
            intro
            trending
            yourStocks
          }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
        .frame(maxWidth: 700)
        .frame(maxWidth: .infinity)
      }
      .background(Palette.canvas)
      .navigationTitle("Flock")
      .searchable(text: $query, prompt: "Look up any stock")
      .task(id: query) { await search() }
      .task { await flock.loadTrending() }
      .refreshable { await flock.loadTrending() }
      .navigationDestination(for: String.self) { symbol in
        FlockDetailView(symbol: symbol)
      }
    }
  }

  private var intro: some View {
    HStack(spacing: 16) {
      OwlMark()
        .frame(width: 54)
      VStack(alignment: .leading, spacing: 4) {
        Text("Invest with the flock")
          .font(.headline)
          .foregroundStyle(.white)
        Text("See where thousands of investors are waiting to buy and sell. Every alert is shared anonymously.")
          .font(.subheadline)
          .foregroundStyle(.white.opacity(0.7))
      }
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Brand.nightGradient, in: .rect(cornerRadius: 28))
    .padding(.top, 8)
  }

  @ViewBuilder
  private var trending: some View {
    if !flock.trending.isEmpty {
      VStack(alignment: .leading, spacing: 14) {
        SectionHeader(title: "Trending This Week", subtitle: "Most new alerts")
        VStack(spacing: 0) {
          ForEach(Array(flock.trending.enumerated()), id: \.element.id) { index, item in
            NavigationLink(value: item.symbol) {
              TrendingRow(rank: index + 1, item: item)
            }
            .buttonStyle(.plain)
            if index < flock.trending.count - 1 {
              Divider().padding(.leading, 56)
            }
          }
        }
        .cardStyle()
      }
    }
  }

  @ViewBuilder
  private var yourStocks: some View {
    if !holdings.isEmpty {
      VStack(alignment: .leading, spacing: 14) {
        SectionHeader(title: "Your Stocks")
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
          ForEach(holdings) { holding in
            NavigationLink(value: holding.symbol) {
              FlockSnapshotCard(symbol: holding.symbol, stats: flock.stats[holding.symbol])
            }
            .buttonStyle(.plain)
            .task {
              if let quote = quotes[holding.symbol] { await flock.load(symbol: holding.symbol, currentPrice: quote.price) }
            }
          }
        }
      }
    }
  }

  private var searchResults: some View {
    VStack(spacing: 0) {
      ForEach(results) { match in
        NavigationLink(value: match.symbol) {
          HStack(spacing: 12) {
            TickerBadge(symbol: match.symbol, size: 38)
            VStack(alignment: .leading, spacing: 2) {
              Text(match.symbol).font(.headline)
              Text(match.name).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.forward")
              .font(.footnote.weight(.semibold))
              .foregroundStyle(.tertiary)
          }
          .padding(14)
          .contentShape(.rect)
        }
        .buttonStyle(.plain)
        Divider().padding(.leading, 64)
      }
    }
    .cardStyle()
    .padding(.top, 8)
  }

  private func search() async {
    let text = query.trimmingCharacters(in: .whitespaces)
    guard !text.isEmpty else { results = []; return }
    try? await Task.sleep(for: .milliseconds(300))
    guard !Task.isCancelled else { return }
    results = (try? await QuoteService().search(text)) ?? []
  }
}

private struct TrendingRow: View {
  var rank: Int
  var item: TrendingSymbol

  var body: some View {
    HStack(spacing: 14) {
      Text("\(rank)")
        .font(.headline.monospacedDigit())
        .foregroundStyle(.secondary)
        .frame(width: 26)
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text(item.symbol).font(.headline)
          Spacer()
          Text("\(item.newAlerts) alerts")
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        HStack(spacing: 8) {
          BuySellBar(buyShare: item.buyShare)
          Text("\(item.buyShare, format: .percent.precision(.fractionLength(0))) buy")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Palette.amber)
            .frame(width: 64, alignment: .trailing)
        }
      }
      Image(systemName: "chevron.forward")
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.tertiary)
    }
    .padding(16)
    .contentShape(.rect)
    .accessibilityElement(children: .combine)
  }
}

private struct FlockSnapshotCard: View {
  var symbol: String
  var stats: FlockStats?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        TickerBadge(symbol: symbol, size: 34)
        Spacer()
        if let stats {
          Text("\(stats.watcherCount)")
            .font(.headline.monospacedDigit())
          Image(systemName: "person.3.fill")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      Text(symbol)
        .font(.headline)
      if let stats, stats.hasEnoughData {
        BuySellBar(buyShare: stats.buyShare)
        Text("\(stats.buyShare, format: .percent.precision(.fractionLength(0))) waiting to buy")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else {
        Text(stats == nil ? "Loading…" : "Not enough data yet")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .cardStyle(cornerRadius: 20)
    .accessibilityElement(children: .combine)
  }
}
