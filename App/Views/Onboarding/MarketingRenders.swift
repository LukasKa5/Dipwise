#if DEBUG
import Charts
import SwiftUI

/// Development only: renders the Apple Watch pages from the real watch components at 6× scale, and Dippy's poses
/// at 8× on a transparent background, so App Store screenshots stay razor sharp at any size. Launch with
/// `-marketingScene watch`; the PNGs land in the app's Documents folder as `watch-<page>.png` and `owl-<pose>.png`.
struct MarketingRenders: View {
  var model: OnboardingModel

  @State private var saved: [String] = []

  /// The Apple Watch Ultra display width in points, less the page's side padding.
  private static let width: CGFloat = 211 - 16
  private static let scale: CGFloat = 6

  /// The same holdings and plans as the demo iPhone, so every screenshot tells the same story.
  private static let holdings: [(String, Double)] = [
    ("NVDA", 120), ("AAPL", 60), ("AMZN", 50), ("GOOGL", 40), ("MSFT", 30), ("VOO", 25), ("META", 12), ("TSLA", 10),
  ]
  private static let plans: [(String, Double, Double)] = [
    ("AMZN", 236.20, 249.30), ("NVDA", 206.35, 217.80), ("AAPL", 306.30, 323.35), ("META", 668.65, 705.80),
  ]

  private var statuses: [TargetStatus] {
    let targets = Self.plans.enumerated().compactMap { offset, plan -> WatchedTarget? in
      guard let quote = model.quotes[plan.0] else { return nil }
      return WatchedTarget(
        id: UUID(uuidString: "00000000-0000-4000-8000-00000000000\(offset)") ?? UUID(),
        symbol: plan.0, name: quote.name, rule: AlertRule(kind: .buyZone, lower: plan.1, upper: plan.2))
    }
    return TargetStatus.sorted(targets: targets, quotes: model.quotes)
  }

  private var portfolio: WatchPortfolio? {
    let stocks = Self.holdings.compactMap { symbol, shares -> WatchedStock? in
      guard let quote = model.quotes[symbol] else { return nil }
      return WatchedStock(symbol: symbol, name: quote.name, shares: shares, averageCost: quote.price / 1.62)
    }
    return WatchPortfolio.make(stocks: stocks, quotes: model.quotes, currency: "USD", rates: [:])
  }

  private var movers: [Quote] {
    MoversProvider.sorted(Self.holdings.compactMap { model.quotes[$0.0] })
  }

  var body: some View {
    VStack(spacing: 8) {
      Text("Rendered \(saved.count) images")
      ForEach(saved, id: \.self) { Text($0).font(.caption.monospaced()) }
    }
    .task { render() }
  }

  // MARK: Pages

  private var today: some View {
    VStack(alignment: .leading, spacing: 8) {
      WatchDippyHeader(greeting: "Good morning", message: OwlMood.calm.watchMessage, isAsleep: false)
      if let portfolio {
        WatchPortfolioHero(portfolio: portfolio)
      }
      WatchSectionTitle(title: "Closest plans")
      ForEach(statuses.prefix(2)) { WatchPlanCard(status: $0) }
      WatchSectionTitle(title: "Today's movers")
      ForEach(movers.prefix(3), id: \.symbol) { WatchMoverRow(quote: $0) }
    }
  }

  private var plansPage: some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(statuses) { WatchPlanCard(status: $0) }
    }
  }

  private var watchlist: some View {
    VStack(spacing: 8) {
      ForEach(Self.holdings.map(\.0), id: \.self) { symbol in
        if let quote = model.quotes[symbol] { WatchMoverRow(quote: quote) }
      }
    }
  }

  @ViewBuilder private var stock: some View {
    if let quote = model.quotes["NVDA"] {
      VStack(alignment: .leading, spacing: 8) {
        chartCard(quote)
        if let status = statuses.first(where: { $0.target.symbol == "NVDA" }) {
          WatchSectionTitle(title: "Your plan")
          WatchPlanCard(status: status)
        }
      }
    }
  }

  /// The watch app's stock chart card, as it looks before the Crown is turned.
  private func chartCard(_ quote: Quote) -> some View {
    let values = Array(quote.closes.suffix(21))
    let color = (values.last ?? 0) >= (values.first ?? 0) ? Brand.buy : Brand.sell
    let low = values.min() ?? 0
    let high = values.max() ?? 1
    let pad = max((high - low) * 0.1, high * 0.001)
    return VStack(alignment: .leading, spacing: 3) {
      Text(quote.name)
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.white.opacity(0.65))
        .lineLimit(1)
      Text(quote.formatted(quote.price))
        .font(.system(size: 26, weight: .bold, design: .rounded))
        .monospacedDigit()
      Text("\(changeText(quote.change)) today")
        .font(.system(size: 12, weight: .semibold).monospacedDigit())
        .foregroundStyle(quote.change >= 0 ? Brand.buy : Brand.sell)
      Chart(Array(values.enumerated()), id: \.offset) { offset, value in
        AreaMark(x: .value("Day", offset), yStart: .value("Floor", low - pad), yEnd: .value("Price", value))
          .foregroundStyle(LinearGradient(colors: [color.opacity(0.25), color.opacity(0)], startPoint: .top, endPoint: .bottom))
          .interpolationMethod(.monotone)
        LineMark(x: .value("Day", offset), y: .value("Price", value))
          .foregroundStyle(color)
          .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
          .interpolationMethod(.monotone)
      }
      .chartXAxis(.hidden)
      .chartYAxis(.hidden)
      .chartYScale(domain: (low - pad)...(high + pad))
      .frame(height: 62)
      HStack(spacing: 2) {
        ForEach(["1W", "1M", "3M", "1Y"], id: \.self) { title in
          Text(title)
            .font(.system(size: 12, weight: .bold))
            .frame(maxWidth: .infinity, minHeight: 24)
            .background(title == "1M" ? AnyShapeStyle(.white.opacity(0.18)) : AnyShapeStyle(.clear), in: .capsule)
            .foregroundStyle(title == "1M" ? .white : .white.opacity(0.6))
        }
      }
      .padding(2)
      .background(.white.opacity(0.06), in: .capsule)
    }
    .padding(10)
    .watchTile()
  }

  // MARK: Rendering

  private func render() {
    let pages: [(String, AnyView)] = [
      ("today", AnyView(today)), ("plans", AnyView(plansPage)), ("stock", AnyView(stock)), ("watchlist", AnyView(watchlist)),
    ]
    let folder = URL.documentsDirectory
    for (name, page) in pages {
      let renderer = ImageRenderer(content:
        page
          .frame(width: Self.width)
          .foregroundStyle(.white)
          .environment(\.colorScheme, .dark)
          .padding(.vertical, 2)
          .background(Brand.nightMiddle)
      )
      renderer.scale = Self.scale
      guard let data = renderer.uiImage?.pngData() else { continue }
      let url = folder.appending(path: "watch-\(name).png")
      try? data.write(to: url)
      saved.append(url.lastPathComponent)
    }
    renderOwls(into: folder)
  }

  /// Dippy's poses, with room around him for open wings.
  private func renderOwls(into folder: URL) {
    let poses: [(name: String, owl: OwlMark)] = [
      ("idle", OwlMark()),
      ("look-left", OwlMark(lookOffset: CGSize(width: -1, height: 0))),
      ("look-right", OwlMark(lookOffset: CGSize(width: 1, height: 0.2))),
      ("look-up", OwlMark(lookOffset: CGSize(width: 0.3, height: -0.9))),
      ("look-down", OwlMark(lookOffset: CGSize(width: 0.2, height: 1))),
      ("wink", OwlMark(blink: 1, rightEyeOpen: 1)),
      ("sleep", OwlMark(blink: 1)),
      ("wings", OwlMark(wingSpread: 1)),
    ]
    for pose in poses {
      let renderer = ImageRenderer(content:
        pose.owl
          .frame(width: 170, height: 196)
          .padding(.horizontal, 140)
          .padding(.top, 160)
      )
      renderer.scale = 8
      guard let data = renderer.uiImage?.pngData() else { continue }
      let url = folder.appending(path: "owl-\(pose.name).png")
      try? data.write(to: url)
      saved.append(url.lastPathComponent)
    }
  }
}
#endif
