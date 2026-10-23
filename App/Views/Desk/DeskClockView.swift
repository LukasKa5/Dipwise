import SwiftData
import SwiftUI

/// Desk Clock: Dipwise as a bedside and desk clock on iPhone Duo's outer display, with the phone closed and standing
/// on its edge. A big, calm clock with Dippy beside it, a countdown to the market's next bell, and underneath your
/// portfolio and your closest buy zone. Late at night it glows a soft red, like a real alarm clock. The screen stays
/// awake while it's open.
struct DeskClockView: View {
  /// Renders a fixed moment, for App Store screenshots.
  var frozenDate: Date?

  @Query(sort: \Holding.addedAt) private var holdings: [Holding]
  @Environment(QuoteStore.self) private var quotes
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Environment(FlockService.self) private var flock

  private var summary: PortfolioSummary {
    PortfolioSummary(holdings: holdings, quotes: quotes.quotes, baseCurrency: quotes.baseCurrency, convert: quotes.toBase, intraday: quotes.intraday)
  }

  /// The plan closest to firing.
  private var closest: (alert: PriceAlert, quote: Quote)? {
    summary.activeAlerts.compactMap { alert in quotes[alert.symbol].map { (alert, $0) } }
      .min { ($0.alert.distance(for: $0.quote) ?? 1) < ($1.alert.distance(for: $1.quote) ?? 1) }
  }

  var body: some View {
    TimelineView(.everyMinute) { context in
      let now = frozenDate ?? context.date
      let style = ClockStyle(date: now)
      GeometryReader { geometry in
        let isWide = geometry.size.width > geometry.size.height
        Group {
          if isWide {
            VStack(spacing: 0) {
              HStack(alignment: .center, spacing: 12) {
                clock(now, style: style, size: geometry.size)
                Spacer(minLength: 0)
                dippy(now, height: geometry.size.height * 0.36)
              }
              .frame(maxHeight: .infinity)
              HStack(spacing: 10) {
                portfolioTile(style: style)
                planTile(style: style)
              }
            }
          } else {
            VStack(spacing: 14) {
              dippy(now, height: geometry.size.height * 0.16)
              clock(now, style: style, size: geometry.size)
              Spacer(minLength: 0)
              portfolioTile(style: style)
              planTile(style: style)
            }
          }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
      }
      .foregroundStyle(style.ink)
      .background {
        LinearGradient(colors: style.background, startPoint: .top, endPoint: .bottom)
          .ignoresSafeArea()
      }
      .overlay(alignment: .topTrailing) {
        Button("Close Desk Clock", systemImage: "xmark") { dismiss() }
          .labelStyle(.iconOnly)
          .font(.subheadline.weight(.bold))
          .foregroundStyle(style.ink.opacity(0.6))
          .frame(width: 36, height: 36)
          .background(style.ink.opacity(0.1), in: .circle)
          .padding(10)
      }
    }
    .environment(\.colorScheme, .dark)
    .statusBarHidden()
    .persistentSystemOverlays(.hidden)
    .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
    .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    .task {
      guard frozenDate == nil else { return }
      // Fresh prices every minute while it stands on the desk.
      while !Task.isCancelled {
        await MarketMonitor.refresh(context: modelContext, quotes: quotes, flock: flock)
        try? await Task.sleep(for: .seconds(60))
      }
    }
  }

  // MARK: Pieces

  private func clock(_ now: Date, style: ClockStyle, size: CGSize) -> some View {
    let isOpen = MarketClock.isOpen(at: now)
    let bell = MarketClock.nextChange(after: now)
    return VStack(alignment: .leading, spacing: 2) {
      Text(now, format: .dateTime.weekday(.wide).month(.wide).day())
        .font(.headline)
        .foregroundStyle(style.ink.opacity(0.6))
      let digits = min(size.height * 0.34, size.width * 0.24)
      HStack(alignment: .firstTextBaseline, spacing: digits * 0.06) {
        Text(now, format: .dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
          .font(.system(size: digits, weight: .semibold, design: .rounded).monospacedDigit())
          .contentTransition(.numericText())
        if let period = Self.dayPeriod(for: now) {
          Text(period)
            .font(.system(size: digits * 0.26, weight: .bold, design: .rounded))
            .foregroundStyle(style.ink.opacity(0.6))
        }
      }
      .lineLimit(1)
      .minimumScaleFactor(0.5)
      HStack(spacing: 7) {
        Circle()
          .fill(isOpen ? style.accent : style.ink.opacity(0.4))
          .frame(width: 8, height: 8)
        let countdown = countdownText(to: bell, from: now, isLive: frozenDate == nil)
        Text(isOpen ? "Market closes in \(countdown)" : "Market opens in \(countdown)")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(style.ink.opacity(0.75))
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
    }
  }

  /// "AM" or "PM", small beside the digits, where the person's clock uses 12 hours.
  private static func dayPeriod(for date: Date) -> String? {
    let format = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current) ?? ""
    guard format.contains("a") else { return nil }
    let calendar = Calendar.current
    return calendar.component(.hour, from: date) < 12 ? calendar.amSymbol : calendar.pmSymbol
  }

  private func dippy(_ now: Date, height: CGFloat) -> some View {
    LivelyOwl(mood: MarketClock.isOpen(at: now) ? .calm : .sleeping)
      .frame(width: height * 0.87, height: height)
  }

  private func portfolioTile(style: ClockStyle) -> some View {
    let summary = summary
    let isUp = summary.dayChangeAmount >= 0
    return VStack(alignment: .leading, spacing: 2) {
      Text("Portfolio")
        .font(.caption.weight(.bold))
        .foregroundStyle(style.ink.opacity(0.55))
      Text(quotes.formatBase(summary.totalValue))
        .font(.system(.title3, design: .rounded).weight(.bold).monospacedDigit())
        .lineLimit(1)
        .minimumScaleFactor(0.6)
      Label("\(changeText(summary.dayChange)) today", systemImage: isUp ? "arrow.up.right" : "arrow.down.right")
        .font(.caption.weight(.semibold).monospacedDigit())
        .foregroundStyle(style.isNight ? style.ink : (isUp ? Brand.buy : Brand.sell))
        .lineLimit(1)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(style.ink.opacity(0.07), in: .rect(cornerRadius: 16, style: .continuous))
    .accessibilityElement(children: .combine)
  }

  @ViewBuilder
  private func planTile(style: ClockStyle) -> some View {
    if let closest {
      let status = TargetStatus(target: WatchedTarget(id: closest.alert.id, symbol: closest.alert.symbol, name: closest.quote.name, rule: closest.alert.rule),
                                quote: closest.quote)
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 8) {
          WidgetBadge(symbol: closest.alert.symbol, size: 26)
          VStack(alignment: .leading, spacing: 0) {
            Text("Closest plan · \(closest.alert.symbol)")
              .font(.caption.weight(.bold))
              .lineLimit(1)
            Text(compactSummary(status))
              .font(.caption2.weight(.semibold))
              .foregroundStyle(style.isNight ? style.ink.opacity(0.7) : closest.alert.kind.side.brandColor)
              .lineLimit(1)
              .minimumScaleFactor(0.7)
          }
          Spacer(minLength: 4)
          DistanceLabel(status: status)
        }
        ZoneRuler(status: status)
      }
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(style.ink.opacity(0.07), in: .rect(cornerRadius: 16, style: .continuous))
      .accessibilityElement(children: .combine)
    } else {
      Text("Set a buy zone and Dippy will watch it here.")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(style.ink.opacity(0.7))
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(style.ink.opacity(0.07), in: .rect(cornerRadius: 16, style: .continuous))
    }
  }
}

/// The clock's colors: the app's navy by day, and a soft, dim red late at night so it never lights up the room.
private struct ClockStyle {
  var isNight: Bool

  init(date: Date) {
    let hour = Calendar.current.component(.hour, from: date)
    isNight = hour >= 22 || hour < 6
  }

  var ink: Color { isNight ? Color(red: 1, green: 0.36, blue: 0.3).opacity(0.85) : .white }
  var accent: Color { isNight ? ink : Brand.buy }
  var background: [Color] { isNight ? [.black, .black] : [Brand.nightTop, Brand.nightMiddle, Brand.nightBottom] }
}
