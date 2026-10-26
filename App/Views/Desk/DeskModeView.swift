import SwiftData
import SwiftUI

/// Desk Mode: a live, hands-on stock tracker for iPhone Duo standing like a tent on a desk, using its whole outer
/// display edge to edge and stepping around only the camera. Along the top: the time, the market's countdown, and
/// the three big indexes. On the left: the portfolio with a chart you can scrub. On the right: a heatmap of your
/// stocks sized by how much you hold and colored by today's move, your closest plans, or the flock. Tap any stock for
/// its chart, plan, and crowd. Your stocks run along the bottom like a ticker. The screen stays awake while it's open.
struct DeskModeView: View {
  /// Renders a fixed moment, for App Store screenshots.
  var frozenDate: Date?
  /// Where the outer camera sits, for renders that have no real device to ask.
  var simulatedCamera: CGRect?

  @Query(sort: \Holding.addedAt) private var holdings: [Holding]
  @Environment(QuoteStore.self) private var quotes
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Environment(FlockService.self) private var flock
  @State private var page = Page.heatmap
  @State private var isTouched = false
  @State private var selectedIndex: Int?
  @State private var focus: String?
  @State private var tickerWidth: CGFloat = 0
  @State private var camera: CGRect?

  enum Page: String, CaseIterable, Identifiable {
    case heatmap
    case plans
    case flock

    var id: Self { self }

    var title: LocalizedStringKey {
      switch self {
      case .heatmap: "Heatmap"
      case .plans: "Plans"
      case .flock: "Flock"
      }
    }
  }

  private static let indexes: [(symbol: String, name: String)] = [("^GSPC", "S&P 500"), ("^IXIC", "Nasdaq"), ("^DJI", "Dow")]

  private var pages: [Page] { flock.isAvailable ? Page.allCases : [.heatmap, .plans] }

  private var summary: PortfolioSummary {
    PortfolioSummary(holdings: holdings, quotes: quotes.quotes, baseCurrency: quotes.baseCurrency, convert: quotes.toBase, intraday: quotes.intraday)
  }

  /// Every active plan with its quote, closest to firing first.
  private var plans: [TargetStatus] {
    summary.activeAlerts.compactMap { alert in
      quotes[alert.symbol].map { TargetStatus(target: WatchedTarget(id: alert.id, symbol: alert.symbol, name: $0.name, rule: alert.rule), quote: $0) }
    }
    .sorted { ($0.distance ?? 1) < ($1.distance ?? 1) }
  }

  var body: some View {
    TimelineView(.everyMinute) { context in
      let now = frozenDate ?? context.date
      GeometryReader { geometry in
        let size = geometry.size
        // With the camera in the bottom corner, the panels run right down to its top edge, and the ticker fills the
        // strip beside it, its stocks streaming out from the camera toward the left.
        let bottomCamera = (simulatedCamera ?? camera).flatMap { $0.minY > size.height / 2 ? $0 : nil }
        VStack(spacing: 8) {
          topBar(now)
          HStack(alignment: .top, spacing: 8) {
            portfolio
              .frame(width: size.width * 0.42)
            panel
          }
          .frame(maxHeight: .infinity)
          ticker
            .frame(height: bottomCamera.map { $0.height } ?? 22)
            .padding(.trailing, bottomCamera.map { max(0, size.width - 12 - $0.minX + 10) } ?? 0)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, bottomCamera.map { max(4, size.height - $0.maxY) } ?? 8)
      }
      .ignoresSafeArea()
    }
    .foregroundStyle(.white)
    .background {
      LinearGradient(colors: [Brand.nightTop, Brand.nightMiddle, Brand.nightBottom], startPoint: .top, endPoint: .bottom)
        .ignoresSafeArea()
    }
    .modifier(CameraReader(camera: $camera))
    .environment(\.colorScheme, .dark)
    .statusBarHidden()
    .persistentSystemOverlays(.hidden)
    .sensoryFeedback(.selection, trigger: page)
    .sensoryFeedback(.selection, trigger: focus)
    .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
    .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    .task {
      guard frozenDate == nil else { return }
      // Fresh prices every minute while it stands on the desk.
      while !Task.isCancelled {
        await MarketMonitor.refresh(context: modelContext, quotes: quotes, flock: flock)
        await quotes.refresh(symbols: Self.indexes.map(\.symbol))
        try? await Task.sleep(for: .seconds(60))
      }
    }
    .task {
      guard frozenDate == nil else { return }
      // The panel tours its pages by itself until someone touches it.
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(15))
        guard !isTouched, focus == nil, let index = pages.firstIndex(of: page) else { continue }
        withAnimation(.easeInOut(duration: 0.35)) { page = pages[(index + 1) % pages.count] }
      }
    }
  }

  // MARK: Top bar

  private func topBar(_ now: Date) -> some View {
    let isOpen = MarketClock.isOpen(at: now)
    let countdown = countdownText(to: MarketClock.nextChange(after: now), from: now, isLive: frozenDate == nil)
    return HStack(spacing: 8) {
      Text(now, format: .dateTime.hour().minute())
        .font(.system(size: 26, weight: .bold, design: .rounded).monospacedDigit())
        .fitsNumber(0.7)
      HStack(spacing: 5) {
        Circle().fill(isOpen ? Brand.buy : .white.opacity(0.4)).frame(width: 7, height: 7)
        Text(isOpen ? "Closes in \(countdown)" : "Opens in \(countdown)")
          .fitsNumber(0.5)
      }
      .font(.footnote.weight(.semibold))
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(.white.opacity(0.08), in: .capsule)
      .layoutPriority(1)
      Spacer(minLength: 4)
      ForEach(Self.indexes, id: \.symbol) { index in
        if let quote = quotes[index.symbol] {
          HStack(spacing: 4) {
            Text(index.name).foregroundStyle(.white.opacity(0.7))
            Text(quote.change.formatted(.percent.precision(.fractionLength(2)).sign(strategy: .always())))
              .foregroundStyle(quote.change >= 0 ? Brand.buy : Brand.sell)
          }
          .font(.footnote.weight(.bold).monospacedDigit())
          .fitsNumber(0.6)
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(.white.opacity(0.08), in: .capsule)
        }
      }
      Button("Close Desk Mode", systemImage: "xmark") { dismiss() }
        .labelStyle(.iconOnly)
        .font(.caption.weight(.bold))
        .foregroundStyle(.white.opacity(0.7))
        .frame(width: 28, height: 28)
        .background(.white.opacity(0.1), in: .circle)
    }
  }

  // MARK: Portfolio

  private var portfolio: some View {
    let summary = summary
    let isUp = summary.dayChangeAmount >= 0
    let day = summary.history(period: .preset(.day))
    let history = day.values.count > 2 ? day : summary.history(period: .preset(.month))
    let selected = selectedIndex.flatMap { history.values.indices.contains($0) ? $0 : nil }
    return VStack(alignment: .leading, spacing: 3) {
      Text(selected.flatMap { history.dates.indices.contains($0) ? history.dates[$0].formatted(date: .abbreviated, time: .shortened) : nil } ?? String(localized: "Portfolio"))
        .font(.caption.weight(.bold))
        .foregroundStyle(selected == nil ? .white.opacity(0.6) : Brand.mint)
      Text(quotes.formatBase(selected.map { history.values[$0] } ?? summary.totalValue))
        .font(.system(size: 38, weight: .bold, design: .rounded).monospacedDigit())
        .fitsNumber()
        .contentTransition(.numericText())
      Text("\(changeText(summary.dayChange)) · \(isUp ? "+" : "")\(quotes.formatBase(summary.dayChangeAmount)) today")
        .font(.headline.monospacedDigit())
        .foregroundStyle(isUp ? Brand.buy : Brand.sell)
        .fitsNumber()
      InteractiveChart(values: history.values, dates: history.dates,
                       lineColor: (history.values.last ?? 0) >= (history.values.first ?? 0) ? Brand.buy : Brand.sell,
                       gridColor: .white.opacity(0.08), owlSize: 28, selectedIndex: $selectedIndex)
        .frame(maxHeight: .infinity)
        .padding(.top, 4)
    }
    .padding(12)
    .frame(maxHeight: .infinity, alignment: .top)
    .background(.white.opacity(0.06), in: .rect(cornerRadius: 18, style: .continuous))
  }

  // MARK: Panel

  private var panel: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 4) {
        ForEach(pages) { option in
          Button {
            isTouched = true
            focus = nil
            withAnimation(.easeInOut(duration: 0.2)) { page = option }
          } label: {
            Text(option.title)
              .font(.caption.weight(.bold))
              .foregroundStyle(page == option && focus == nil ? Brand.owlInk : .white.opacity(0.75))
              .frame(maxWidth: .infinity)
              .padding(.vertical, 6)
              .background(page == option && focus == nil ? AnyShapeStyle(Brand.mint) : AnyShapeStyle(.clear), in: .capsule)
              .contentShape(.capsule)
          }
          .buttonStyle(.plain)
          .accessibilityAddTraits(page == option ? .isSelected : [])
        }
      }
      .padding(3)
      .background(.white.opacity(0.08), in: .capsule)

      // Pages swap in place with a quick crossfade, never sliding across the screen.
      ZStack {
        if let focus, let quote = quotes[focus] {
          stockDetail(symbol: focus, quote: quote)
        } else {
          switch page {
          case .heatmap: heatmap
          case .plans: plansPage
          case .flock: flockPage
          }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .transition(.opacity)
      .animation(.easeInOut(duration: 0.2), value: page)
      .animation(.easeInOut(duration: 0.2), value: focus)
    }
    .padding(10)
    .frame(maxHeight: .infinity, alignment: .top)
    .background(.white.opacity(0.06), in: .rect(cornerRadius: 18, style: .continuous))
  }

  /// Every stock you own as a tile, as big as its share of the portfolio and as green or red as today's move.
  private var heatmap: some View {
    let positions = summary.positions.sorted { $0.weight > $1.weight }
    let rows = Self.rows(of: positions.map { HeatTile(symbol: $0.holding.symbol, weight: $0.weight, change: $0.quote.change) })
    return VStack(spacing: 4) {
      ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
        GeometryReader { geometry in
          // Small holdings still get a readable tile.
          let floor = row.reduce(0) { $0 + $1.weight } * 0.2
          let shown = row.map { max($0.weight, floor) }
          let total = max(shown.reduce(0, +), 0.0001)
          HStack(spacing: 4) {
            ForEach(Array(row.enumerated()), id: \.element.id) { index, item in
              Button {
                isTouched = true
                focus = item.symbol
              } label: {
                VStack(spacing: 1) {
                  Text(item.symbol)
                    .font(.headline.weight(.heavy))
                  Text(changeText(item.change))
                    .font(.subheadline.weight(.bold).monospacedDigit())
                }
                .fitsNumber(0.6)
                .padding(4)
                .frame(width: max(0, (geometry.size.width - CGFloat(row.count - 1) * 4) * shown[index] / total), height: geometry.size.height)
                .background(Self.heat(item.change), in: .rect(cornerRadius: 8, style: .continuous))
              }
              .buttonStyle(.plain)
              .accessibilityLabel("\(item.symbol), \(changeText(item.change)) today")
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  private var plansPage: some View {
    if plans.isEmpty {
      Text("Set a buy zone and Dippy will watch it here.")
        .font(.subheadline)
        .foregroundStyle(.white.opacity(0.7))
    } else {
      VStack(spacing: 6) {
        ForEach(plans.prefix(3)) { status in
          Button {
            isTouched = true
            focus = status.target.symbol
          } label: {
            VStack(alignment: .leading, spacing: 5) {
              HStack(spacing: 8) {
                WidgetBadge(symbol: status.target.symbol, size: 24)
                VStack(alignment: .leading, spacing: 0) {
                  Text(status.target.symbol)
                    .font(.caption.bold())
                  Text(compactSummary(status))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(status.target.rule.kind.side.brandColor)
                    .fitsNumber(0.6)
                }
                Spacer(minLength: 4)
                DistanceLabel(status: status)
              }
              ZoneRuler(status: status)
            }
            .frame(maxHeight: .infinity)
            .contentShape(.rect)
          }
          .buttonStyle(.plain)
          .accessibilityElement(children: .combine)
        }
      }
    }
  }

  private var flockPage: some View {
    let overview = flock.overview
    return VStack(alignment: .leading, spacing: 7) {
      HStack(spacing: 10) {
        if let sentiment = flock.sentiment {
          SentimentGauge(score: sentiment.score, color: sentiment.score >= 60 ? Brand.buy : (sentiment.score < 40 ? Brand.sell : Brand.amber))
            .frame(width: 70, height: 40)
          VStack(alignment: .leading, spacing: 0) {
            Text("\(Int(sentiment.score.rounded())) · \(sentiment.label)")
              .font(.subheadline.weight(.bold))
            Text("Flock Fear & Greed")
              .font(.caption2)
              .foregroundStyle(.white.opacity(0.6))
          }
          .fitsNumber(0.7)
        } else {
          Label("\(overview.investors.formatted()) anonymous investors", systemImage: "person.3.fill")
            .font(.caption.weight(.semibold))
            .fitsNumber(0.7)
        }
      }
      Text("In the crowd's buy zone")
        .font(.caption.weight(.bold))
        .foregroundStyle(.white.opacity(0.6))
      ForEach(flock.radar.prefix(3)) { item in
        Button {
          isTouched = true
          focus = item.symbol
        } label: {
          HStack(spacing: 8) {
            WidgetBadge(symbol: item.symbol, size: 22)
            Text(item.symbol)
              .font(.caption.bold())
            Spacer(minLength: 4)
            Text("\(item.watchers) waiting")
              .font(.caption2)
              .foregroundStyle(.white.opacity(0.6))
            Text("\(item.conviction)%")
              .font(.caption.weight(.bold).monospacedDigit())
              .foregroundStyle(Brand.buy)
          }
          .frame(maxHeight: .infinity)
          .contentShape(.rect)
        }
        .buttonStyle(.plain)
      }
    }
    .task { await flock.loadSentiment() }
  }

  /// One stock up close: price, today's move, its last month with your zones, your plan, and the crowd.
  private func stockDetail(symbol: String, quote: Quote) -> some View {
    let plan = plans.first { $0.target.symbol == symbol }
    let zones = summary.activeAlerts.filter { $0.symbol == symbol && ($0.kind.isZone || $0.kind == .priceBelow || $0.kind == .priceAbove) }.map(\.rule)
    let report = flock.reports[symbol]
    return VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        WidgetBadge(symbol: symbol, size: 26)
        VStack(alignment: .leading, spacing: 0) {
          Text(symbol).font(.subheadline.bold())
          Text(quote.formatted(quote.price))
            .font(.caption.monospacedDigit())
            .foregroundStyle(.white.opacity(0.7))
            .fitsNumber()
        }
        Spacer(minLength: 4)
        WidgetChangePill(change: quote.change)
        Button("Back", systemImage: "xmark") { focus = nil }
          .labelStyle(.iconOnly)
          .font(.caption2.weight(.bold))
          .frame(width: 24, height: 24)
          .background(.white.opacity(0.12), in: .circle)
          .buttonStyle(.plain)
      }
      WidgetSparkline(values: Array(quote.closes.suffix(30)), zones: zones)
        .frame(maxHeight: .infinity)
      if let plan {
        HStack {
          Text(compactSummary(plan))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(plan.target.rule.kind.side.brandColor)
            .fitsNumber(0.6)
          Spacer(minLength: 4)
          DistanceLabel(status: plan)
        }
      }
      if let report, report.hasEnoughData {
        Label("Flock: \(report.convictionLabel) · \(report.watcherCount) watching", systemImage: "person.3.fill")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.white.opacity(0.7))
          .fitsNumber(0.6)
      }
    }
    .task {
      if flock.isAvailable { await flock.load(symbol: symbol, currentPrice: quote.price) }
    }
  }

  // MARK: Ticker

  /// Every stock you follow, drifting slowly from the camera side to the left like a ticker. The row repeats as often
  /// as it takes to fill the strip, so a short list loops seamlessly too.
  private var ticker: some View {
    let items = summary.positions.map(\.quote)
    return TimelineView(.animation(minimumInterval: 1 / 30, paused: frozenDate != nil)) { context in
      GeometryReader { geometry in
        let row = HStack(spacing: 20) {
          ForEach(items, id: \.symbol) { quote in
            HStack(spacing: 6) {
              Text(quote.symbol).font(.subheadline.weight(.bold))
              Text(quote.formatted(quote.price))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.white.opacity(0.7))
              Text(changeText(quote.change))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(quote.change >= 0 ? Brand.buy : Brand.sell)
            }
          }
        }
        .fixedSize()
        let copies = tickerWidth > 0 ? Int((geometry.size.width / tickerWidth).rounded(.up)) + 1 : 2
        let offset = frozenDate == nil && tickerWidth > 0
          ? -CGFloat(context.date.timeIntervalSinceReferenceDate * 24).truncatingRemainder(dividingBy: tickerWidth) : 0
        HStack(spacing: 20) {
          ForEach(0..<max(copies, 2), id: \.self) { copy in
            if copy == 0 {
              row.onGeometryChange(for: CGFloat.self) { $0.size.width + 20 } action: { tickerWidth = $0 }
            } else {
              row
            }
          }
        }
        .offset(x: offset)
        .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
        .clipped()
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Your stocks today")
  }

  // MARK: Helpers

  private struct HeatTile: Identifiable {
    var symbol: String
    var weight: Double
    var change: Double
    var id: String { symbol }
  }

  /// Splits weighted tiles into one to three rows of similar total weight, biggest first.
  private static func rows(of items: [HeatTile]) -> [[HeatTile]] {
    guard !items.isEmpty else { return [] }
    let count = items.count <= 3 ? 1 : (items.count <= 7 ? 2 : 3)
    var rows = Array(repeating: [HeatTile](), count: count)
    var totals = Array(repeating: 0.0, count: count)
    for item in items {
      let index = totals.indices.min { totals[$0] < totals[$1] } ?? 0
      rows[index].append(item)
      totals[index] += item.weight
    }
    return rows.filter { !$0.isEmpty }
  }

  /// Green for up and red for down, stronger with the size of the move, up to 3%.
  private static func heat(_ change: Double) -> Color {
    let strength = min(abs(change) / 0.03, 1)
    return (change >= 0 ? Brand.buy : Brand.sell).opacity(0.22 + 0.6 * strength)
  }
}

/// Reads where the outer camera sits on iPhone Duo, so only the content beside it steps aside.
private struct CameraReader: ViewModifier {
  @Binding var camera: CGRect?

  func body(content: Content) -> some View {
    if #available(iOS 27.1, *) {
      content.onGeometryChange(for: CGRect?.self) { proxy in
        proxy.reservedRegions(kind: .occlusion).first?.frame
      } action: { camera = $0 }
    } else {
      content
    }
  }
}
