#if DEBUG
import Charts
import SwiftData
import SwiftUI

/// Development only: renders the Apple Watch pages from the real watch components at 6× scale, and Dippy's poses
/// at 8× on a transparent background, so App Store screenshots stay razor sharp at any size. Launch with
/// `-marketingScene watch`; the PNGs land in the app's Documents folder as `watch-<page>.png` and `owl-<pose>.png`.
struct MarketingRenders: View {
  var model: OnboardingModel

  @State private var saved: [String] = []
  @Environment(QuoteStore.self) private var quotes
  @Environment(FlockService.self) private var flock
  @Environment(\.modelContext) private var modelContext

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
    Self.holdings.compactMap { model.quotes[$0.0] }.sorted { abs($0.change) > abs($1.change) }
  }

  var body: some View {
    VStack(spacing: 8) {
      Text("Rendered \(saved.count) images")
      ForEach(saved, id: \.self) { Text($0).font(.caption.monospaced()) }
    }
    .task {
      render()
      await renderDesk()
      renderOdds()
      renderHint()
      await renderCallouts()
    }
  }

  // MARK: Pages

  private var today: some View {
    VStack(alignment: .leading, spacing: 8) {
      WatchDippyHeader(greeting: "Good morning", message: String(localized: "AMZN is 3.6% from your buy zone."), isAsleep: false)
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

  /// Desk Mode on iPhone Duo's outer display, standing like a tent in landscape (678 × 466 points), at 9:41 with
  /// the market open.
  private func renderDesk() async {
    let holdings = (try? modelContext.fetch(FetchDescriptor<Holding>())) ?? []
    await quotes.refresh(symbols: holdings.map(\.symbol))
    await quotes.refresh(symbols: ["^GSPC", "^IXIC", "^DJI"])
    await flock.loadOverview()
    await flock.loadSentiment()
    try? await Task.sleep(for: .seconds(2))
    let day = QuoteService.marketingDate ?? .now
    let morning = Calendar.current.date(bySettingHour: 9, minute: 41, second: 0, of: day) ?? day
    let renderer = ImageRenderer(content:
      // In this pose the outer camera sits in the bottom trailing corner.
      DeskModeView(frozenDate: morning, simulatedCamera: CGRect(x: 678 - 52, y: 466 - 52, width: 40, height: 40))
        .environment(quotes)
        .environment(flock)
        .modelContainer(DipwiseApp.container)
        .frame(width: 678, height: 466)
    )
    renderer.scale = 3
    guard let data = renderer.uiImage?.pngData() else { return }
    let url = URL.documentsDirectory.appending(path: "desk-mode.png")
    try? data.write(to: url)
    saved.append(url.lastPathComponent)
  }

  /// The intro's own "Try it" chip, for the hint on the buy zone screenshot.
  private func renderHint() {
    let renderer = ImageRenderer(content:
      MissionChip(text: "Drag a green handle", isDone: false)
        .environment(\.colorScheme, .dark)
        .padding(4)
        .background(Brand.nightMiddle, in: .capsule)
    )
    renderer.scale = 3
    guard let data = renderer.uiImage?.pngData() else { return }
    let url = URL.documentsDirectory.appending(path: "hint-drag.png")
    try? data.write(to: url)
    saved.append(url.lastPathComponent)
  }

  /// The Your Odds card for NVDA's buy zone, as it sits on the stock screen.
  private func renderOdds() {
    let holdings = (try? modelContext.fetch(FetchDescriptor<Holding>())) ?? []
    guard let holding = holdings.first(where: { $0.symbol == "NVDA" }), let zone = holding.buyZone, let quote = quotes["NVDA"] else { return }
    let renderer = ImageRenderer(content:
      OddsForecastCard(symbol: "NVDA", quote: quote, buyZone: zone.rule, sellZone: holding.sellZone?.rule, isPro: true)
        .frame(width: 400)
    )
    renderer.scale = 3
    guard let data = renderer.uiImage?.pngData() else { return }
    let url = URL.documentsDirectory.appending(path: "odds-card.png")
    try? data.write(to: url)
    saved.append(url.lastPathComponent)
  }

  /// The pieces the App Store screenshots lift out of the screen, rendered whole and crisp: the flock's fear and greed
  /// card at the Flock's width, and the buy-zone notification as iOS shows it on the lock screen.
  private func renderCallouts() async {
    await flock.loadSentiment()
    var images: [(String, AnyView, CGFloat)] = [("notification-card", AnyView(MarketingNotificationCard()), 412)]
    if let sentiment = flock.sentiment {
      images.append(("sentiment-card", AnyView(FlockSentimentCard(sentiment: sentiment, mine: nil)), 400))
    }
    for (name, view, width) in images {
      let renderer = ImageRenderer(content: view.frame(width: width))
      renderer.scale = 3
      guard let data = renderer.uiImage?.pngData() else { continue }
      let url = URL.documentsDirectory.appending(path: "\(name).png")
      try? data.write(to: url)
      saved.append(url.lastPathComponent)
    }
  }

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
      ("wave", OwlMark(lookOffset: CGSize(width: 0.2, height: -0.2), rightWing: 1.05)),
      ("surprise", OwlMark(leftWing: 0.35, rightWing: 0.35, eyeScale: 1.24)),
      ("blush", OwlMark(joy: 1)),
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
/// The buy-zone alert exactly as it lands on the lock screen: app icon, title, "now", and the plan, on iOS's light
/// notification platter.
private struct MarketingNotificationCard: View {
  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(.appIconPreview)
        .resizable()
        .frame(width: 38, height: 38)
        .clipShape(.rect(cornerRadius: 9, style: .continuous))
      VStack(alignment: .leading, spacing: 1) {
        HStack(spacing: 5) {
          Text("NVDA entered your buy zone")
            .font(.system(size: 15, weight: .semibold))
          Spacer(minLength: 4)
          Text("now")
            .font(.system(size: 13))
            .foregroundStyle(Color(white: 0.45))
        }
        Text("Now $211.38, inside $205.65–$217.10. Your plan: buy 3 shares.")
          .font(.system(size: 15))
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .foregroundStyle(Color(white: 0.06))
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .background(Color(red: 0.95, green: 0.95, blue: 0.97), in: .rect(cornerRadius: 24, style: .continuous))
    .environment(\.colorScheme, .light)
  }
}
#endif
