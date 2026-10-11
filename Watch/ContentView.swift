import Charts
import SwiftUI

struct ContentView: View {
  @Environment(WatchTargetStore.self) private var store

  var body: some View {
    NavigationStack {
      TabView {
        PlansPage()
        StreakPage()
      }
      .tabViewStyle(.verticalPage)
    }
    .tint(Brand.buy)
  }
}

/// Every stock with alerts, closest to triggering first.
private struct PlansPage: View {
  @Environment(WatchTargetStore.self) private var store

  var body: some View {
    List {
      if store.targets.isEmpty {
        VStack(spacing: 10) {
          OwlMark()
            .frame(height: 64)
          Text("Set a buy zone in Dipwise on your iPhone.")
            .font(.footnote)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .listRowBackground(Color.clear)
      } else {
        ForEach(store.stocks, id: \.symbol) { stock in
          NavigationLink {
            StockDetail(symbol: stock.symbol, name: stock.name)
          } label: {
            StockRow(symbol: stock.symbol, quote: store.quotes[stock.symbol], nearest: stock.statuses.first)
          }
        }
      }
    }
    .navigationTitle("Plans")
    .refreshable { await store.refresh() }
  }
}

private struct StockRow: View {
  var symbol: String
  var quote: Quote?
  var nearest: TargetStatus?

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(symbol).font(.headline)
        Spacer()
        if let quote {
          Text(quote.change, format: .percent.precision(.fractionLength(1)).sign(strategy: .always()))
            .font(.footnote.weight(.semibold))
            .foregroundStyle(quote.change >= 0 ? Brand.buy : Brand.sell)
        }
      }
      if let nearest {
        let color = nearest.target.rule.kind.side.brandColor
        Gauge(value: nearest.progress) { EmptyView() }
          .gaugeStyle(.accessoryLinearCapacity)
          .tint(color)
        HStack {
          Text(nearest.target.rule.kind.title)
            .foregroundStyle(color)
          Spacer()
          Text(nearest.distance.map { $0 == 0 ? "Now" : $0.formatted(.percent.precision(.fractionLength(1))) } ?? "—")
            .monospacedDigit()
        }
        .font(.caption2.weight(.semibold))
      }
    }
    .padding(.vertical, 4)
    .accessibilityElement(children: .combine)
  }
}

/// One stock: price, trend, zones, and every alert.
private struct StockDetail: View {
  var symbol: String
  var name: String
  @Environment(WatchTargetStore.self) private var store

  var body: some View {
    let quote = store.quotes[symbol]
    let statuses = store.statuses.filter { $0.target.symbol == symbol }
    ScrollView {
      VStack(alignment: .leading, spacing: 10) {
        if let quote {
          Text(quote.formatted(quote.price))
            .font(.title2.bold().monospacedDigit())
          Text(quote.change, format: .percent.precision(.fractionLength(1)).sign(strategy: .always()))
            .font(.headline)
            .foregroundStyle(quote.change >= 0 ? Brand.buy : Brand.sell)
          let values = Array(quote.closes.suffix(22))
          Chart(Array(values.enumerated()), id: \.offset) { index, value in
            LineMark(x: .value("Day", index), y: .value("Price", value))
              .foregroundStyle((values.last ?? 0) >= (values.first ?? 0) ? Brand.buy : Brand.sell)
              .interpolationMethod(.monotone)
            ForEach(statuses.map(\.target.rule).filter(\.kind.isZone), id: \.self) { rule in
              RectangleMark(yStart: .value("Low", rule.lower), yEnd: .value("High", rule.upper))
                .foregroundStyle(rule.kind.side.brandColor.opacity(0.25))
            }
          }
          .chartXAxis(.hidden)
          .chartYAxis(.hidden)
          .chartYScale(domain: .automatic(includesZero: false))
          .frame(height: 70)
        }
        ForEach(statuses) { status in
          let color = status.target.rule.kind.side.brandColor
          VStack(alignment: .leading, spacing: 4) {
            Text(status.summary)
              .font(.footnote.weight(.semibold))
              .foregroundStyle(color)
            Gauge(value: status.progress) { EmptyView() }
              .gaugeStyle(.accessoryLinearCapacity)
              .tint(color)
            Text(status.distance.map { $0 == 0 ? "Active now" : "\($0.formatted(.percent.precision(.fractionLength(1)))) away" } ?? "")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
          .padding(8)
          .background(color.opacity(0.15), in: .rect(cornerRadius: 10))
        }
      }
      .padding(.horizontal, 4)
    }
    .navigationTitle(symbol)
  }
}

/// Dipp, the streak, and today's brief status.
private struct StreakPage: View {
  @Environment(WatchTargetStore.self) private var store

  var body: some View {
    let progress = store.progress
    VStack(spacing: 8) {
      OwlMark()
        .frame(height: 70)
      HStack(spacing: 4) {
        Image(systemName: "flame.fill")
          .foregroundStyle(progress.streak > 0 ? Brand.amber : .secondary)
        Text("\(progress.streak)")
          .font(.title.bold())
      }
      Text(progress.briefDoneToday ? "Brief done today" : "Brief ready on iPhone")
        .font(.footnote)
        .foregroundStyle(progress.briefDoneToday ? Brand.buy : Brand.amber)
      Text("Level \(progress.level) · \(progress.levelTitle)")
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .accessibilityElement(children: .combine)
  }
}
