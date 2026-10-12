import Charts
import SwiftUI

struct ContentView: View {
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

/// Dippy's greeting and every stock with alerts, closest to triggering first.
private struct PlansPage: View {
  @Environment(WatchTargetStore.self) private var store

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 10) {
        DippHeader(statuses: store.statuses)
        if store.targets.isEmpty {
          Text("Set a buy zone in Dipwise on your iPhone.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        ForEach(store.stocks, id: \.symbol) { stock in
          NavigationLink {
            StockDetail(symbol: stock.symbol)
          } label: {
            StockCard(symbol: stock.symbol, quote: store.quotes[stock.symbol], nearest: stock.statuses.first)
          }
          .buttonStyle(.plain)
        }
      }
    }
    .navigationTitle("Dipwise")
    .refreshable { await store.refresh() }
  }
}

/// Dippy with a one-line take on what matters most.
private struct DippHeader: View {
  var statuses: [TargetStatus]
  @State private var hops = 0

  private var message: String {
    guard let first = statuses.first else { return "Hoo! Nothing to watch yet." }
    if first.distance == 0 { return "\(first.target.symbol) is in your plan!" }
    if !MarketClock.isOpen() { return "Markets closed. Resting." }
    return "\(first.target.symbol) is \(first.distance.map { $0.formatted(.percent.precision(.fractionLength(1))) } ?? "—") away"
  }

  var body: some View {
    HStack(spacing: 8) {
      OwlMark(blink: MarketClock.isOpen() ? 0 : 1)
        .frame(width: 34, height: 40)
        .phaseAnimator([0.0, -6.0, 0.0], trigger: hops) { view, lift in
          view.offset(y: lift)
        }
        .onTapGesture { hops += 1 }
      Text(message)
        .font(.footnote.weight(.semibold))
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Brand.nightMiddle, in: .rect(cornerRadius: 16))
    .accessibilityElement(children: .combine)
  }
}

private struct StockCard: View {
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
      if let quote {
        Text(quote.formatted(quote.price))
          .font(.title3.bold().monospacedDigit())
      }
      if let nearest {
        let color = nearest.target.rule.kind.side.brandColor
        Gauge(value: nearest.progress) { EmptyView() }
          .gaugeStyle(.accessoryLinearCapacity)
          .tint(color)
        HStack {
          Text(nearest.target.rule.kind.title)
            .foregroundStyle(color)
            .lineLimit(1)
          Spacer()
          Text(nearest.distance.map { $0 == 0 ? "Now" : $0.formatted(.percent.precision(.fractionLength(1))) } ?? "—")
            .monospacedDigit()
        }
        .font(.caption2.weight(.semibold))
      }
    }
    .padding(10)
    .background(Brand.nightMiddle, in: .rect(cornerRadius: 16))
    .accessibilityElement(children: .combine)
  }
}

/// One stock: price, trend with its zones, and every alert.
private struct StockDetail: View {
  var symbol: String
  @Environment(WatchTargetStore.self) private var store

  var body: some View {
    let quote = store.quotes[symbol]
    let statuses = store.statuses.filter { $0.target.symbol == symbol }
    ScrollView {
      VStack(alignment: .leading, spacing: 10) {
        if let quote {
          VStack(alignment: .leading, spacing: 4) {
            Text(quote.formatted(quote.price))
              .font(.title2.bold().monospacedDigit())
            Text(quote.change, format: .percent.precision(.fractionLength(1)).sign(strategy: .always()))
              .font(.headline)
              .foregroundStyle(quote.change >= 0 ? Brand.buy : Brand.sell)
            let values = Array(quote.closes.suffix(22))
            let zones = statuses.map(\.target.rule).filter { $0.kind.isZone || $0.kind == .priceBelow || $0.kind == .priceAbove }
            Chart {
              ForEach(Array(zones.enumerated()), id: \.offset) { _, rule in
                RectangleMark(yStart: .value("Low", rule.lower), yEnd: .value("High", max(rule.lower * 1.003, rule.upper)))
                  .foregroundStyle(rule.kind.side.brandColor.opacity(0.3))
              }
              ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                LineMark(x: .value("Day", index), y: .value("Price", value))
                  .foregroundStyle((values.last ?? 0) >= (values.first ?? 0) ? Brand.buy : Brand.sell)
                  .interpolationMethod(.monotone)
              }
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(height: 64)
          }
          .padding(10)
          .background(Brand.nightMiddle, in: .rect(cornerRadius: 16))
        }
        ForEach(statuses) { status in
          let color = status.target.rule.kind.side.brandColor
          VStack(alignment: .leading, spacing: 4) {
            Label(status.summary, systemImage: status.target.rule.kind.systemImage)
              .font(.footnote.weight(.semibold))
              .foregroundStyle(color)
            Gauge(value: status.progress) { EmptyView() }
              .gaugeStyle(.accessoryLinearCapacity)
              .tint(color)
            Text(status.distance.map { $0 == 0 ? "Active now" : "\($0.formatted(.percent.precision(.fractionLength(1)))) away" } ?? "")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
          .padding(10)
          .background(color.opacity(0.15), in: .rect(cornerRadius: 14))
        }
      }
    }
    .navigationTitle(symbol)
  }
}

/// Dippy, the streak, and today's brief.
private struct StreakPage: View {
  @Environment(WatchTargetStore.self) private var store
  @State private var flaps = 0

  var body: some View {
    let progress = store.progress
    VStack(spacing: 8) {
      PhaseAnimator([0.0, 1.0, 0.3, 1.0, 0.0], trigger: flaps) { spread in
        OwlMark(wingSpread: spread)
          .frame(height: 70)
      } animation: { _ in .easeInOut(duration: 0.12) }
        .onTapGesture { flaps += 1 }
        .sensoryFeedback(.impact, trigger: flaps)
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
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Brand.nightMiddle.opacity(0.6))
    .accessibilityElement(children: .combine)
  }
}
