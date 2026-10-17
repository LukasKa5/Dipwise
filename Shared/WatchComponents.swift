import Charts
import SwiftUI

// The Apple Watch app's building blocks. They live in Shared so the iPhone intro shows the watch exactly as it is.
// Same language as the app's navy hero cards: solid navy, soft white tiles, rounded numbers, and Dippy.

extension View {
  /// A soft tile on navy, like the stat tiles on the app's Home card.
  func watchTile(cornerRadius: CGFloat = 18) -> some View {
    background(.white.opacity(0.08), in: .rect(cornerRadius: cornerRadius, style: .continuous))
  }
}

/// Dippy saying hello, with the same mood line as the app's Home card.
struct WatchDippyHeader: View {
  var greeting: String
  var message: String
  var isAsleep: Bool
  var hops = 0

  var body: some View {
    HStack(alignment: .center, spacing: isAsleep ? 12 : 9) {
      WidgetOwl(size: 30, isAsleep: isAsleep)
        .phaseAnimator([0.0, -6.0, 0.0], trigger: hops) { view, lift in
          view.offset(y: lift)
        }
      VStack(alignment: .leading, spacing: 1) {
        Text(greeting)
          .font(.system(size: 15, weight: .semibold, design: .rounded))
          .lineLimit(1)
          .minimumScaleFactor(0.7)
        Text(message)
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(.white.opacity(0.7))
          .lineLimit(3)
          .multilineTextAlignment(.leading)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .layoutPriority(1)
    }
    .padding(.leading, 4)
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}

/// The portfolio value with today's move and a small chart, like the app's Home card.
struct WatchPortfolioHero: View {
  var portfolio: WatchPortfolio

  var body: some View {
    let color = portfolio.dayChangeAmount >= 0 ? Brand.buy : Brand.sell
    VStack(alignment: .leading, spacing: 3) {
      Text("Portfolio")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.white.opacity(0.65))
      Text(portfolio.formatted(portfolio.value))
        .font(.system(size: 28, weight: .bold, design: .rounded))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.5)
      HStack(spacing: 3) {
        Image(systemName: portfolio.dayChange >= 0 ? "arrow.up.right" : "arrow.down.right")
          .font(.system(size: 10, weight: .heavy))
        Text("\(changeText(portfolio.dayChange)) · \(portfolio.dayChangeAmount >= 0 ? "+" : "")\(portfolio.formatted(portfolio.dayChangeAmount))")
          .monospacedDigit()
          .lineLimit(1)
          .minimumScaleFactor(0.6)
      }
      .font(.system(size: 13, weight: .semibold))
      .foregroundStyle(color)
      if portfolio.history.count > 1 {
        let low = portfolio.history.min() ?? 0
        let high = portfolio.history.max() ?? 1
        let pad = max((high - low) * 0.1, high * 0.001)
        Chart(Array(portfolio.history.enumerated()), id: \.offset) { index, value in
          AreaMark(x: .value(String(localized: "Day"), index), yStart: .value(String(localized: "Floor"), low - pad), yEnd: .value(String(localized: "Value"), value))
            .foregroundStyle(LinearGradient(colors: [color.opacity(0.25), color.opacity(0)], startPoint: .top, endPoint: .bottom))
            .interpolationMethod(.monotone)
          LineMark(x: .value(String(localized: "Day"), index), y: .value(String(localized: "Value"), value))
            .foregroundStyle(color)
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .interpolationMethod(.monotone)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: (low - pad)...(high + pad))
        .frame(height: 40)
        .padding(.top, 2)
        .accessibilityHidden(true)
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .watchTile()
    .accessibilityElement(children: .combine)
  }
}

/// One plan: the stock, what Dippy watches for, and how close it is.
struct WatchPlanCard: View {
  var status: TargetStatus
  var extraCount = 0

  var body: some View {
    let color = status.target.rule.kind.side.brandColor
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 7) {
        WidgetBadge(symbol: status.target.symbol, size: 24)
        VStack(alignment: .leading, spacing: 0) {
          Text(status.target.symbol)
            .font(.system(size: 15, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
          if let quote = status.quote {
            Text(compactPrice(quote.price, currency: quote.currency))
              .font(.system(size: 12, weight: .medium).monospacedDigit())
              .foregroundStyle(.white.opacity(0.7))
              .lineLimit(1)
          }
        }
        .layoutPriority(1)
        Spacer(minLength: 2)
        VStack(alignment: .trailing, spacing: 0) {
          Text(distanceText(status.distance))
            .font(.system(size: 17, weight: .bold, design: .rounded).monospacedDigit())
            .foregroundStyle(status.distance == 0 || (status.distance ?? 1) < 0.035 ? color : .white)
            .lineLimit(1)
            .fixedSize()
          Text(status.distance == 0 ? "now" : "to go")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.white.opacity(0.65))
        }
      }
      WidgetTrack(progress: status.progress, color: color)
      HStack(spacing: 4) {
        Image(systemName: status.target.rule.kind.systemImage)
          .font(.system(size: 10, weight: .bold))
        Text(compactSummary(status))
          .lineLimit(1)
          .minimumScaleFactor(0.7)
        if extraCount > 0 {
          Spacer(minLength: 2)
          Text("+\(extraCount)")
            .foregroundStyle(.white.opacity(0.55))
        }
      }
      .font(.system(size: 12, weight: .semibold))
      .foregroundStyle(color)
    }
    .padding(10)
    .watchTile(cornerRadius: 16)
    .accessibilityElement(children: .combine)
  }
}

/// A stock's price, a tiny chart, and today's move.
struct WatchMoverRow: View {
  var quote: Quote

  var body: some View {
    HStack(spacing: 7) {
      WidgetBadge(symbol: quote.symbol, size: 22)
      VStack(alignment: .leading, spacing: 0) {
        Text(quote.symbol)
          .font(.system(size: 14, weight: .semibold))
          .lineLimit(1)
          .minimumScaleFactor(0.6)
        Text(compactPrice(quote.price, currency: quote.currency))
          .font(.system(size: 12, weight: .medium).monospacedDigit())
          .foregroundStyle(.white.opacity(0.7))
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
      .layoutPriority(1)
      Spacer(minLength: 2)
      Text(changeText(quote.change))
        .font(.system(size: 12, weight: .bold).monospacedDigit())
        .foregroundStyle(quote.change >= 0 ? Brand.buy : Brand.sell)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background((quote.change >= 0 ? Brand.buy : Brand.sell).opacity(0.16), in: .capsule)
        .lineLimit(1)
        .fixedSize()
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .watchTile(cornerRadius: 16)
    .accessibilityElement(children: .combine)
  }
}

/// Whether the US market is open, and when that changes.
struct WatchMarketStatus: View {
  var isOpen: Bool
  var nextChange: Date
  var market: Quote?

  var body: some View {
    HStack(spacing: 5) {
      Circle()
        .fill(isOpen ? Brand.buy : .white.opacity(0.4))
        .frame(width: 6, height: 6)
      Text(isOpen ? String(localized: "Open until \(nextChange.formatted(date: .omitted, time: .shortened))") : String(localized: "Opens \(nextChange.formatted(.dateTime.weekday(.abbreviated).hour().minute()))"))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      Spacer(minLength: 2)
      if let market {
        Text("S&P \(changeText(market.change))")
          .foregroundStyle(market.change >= 0 ? Brand.buy : Brand.sell)
          .lineLimit(1)
          .fixedSize()
      }
    }
    .font(.system(size: 12, weight: .semibold).monospacedDigit())
    .foregroundStyle(.white.opacity(0.8))
    .accessibilityElement(children: .combine)
  }
}

/// A small header above a group, like the app's section titles.
struct WatchSectionTitle: View {
  var title: LocalizedStringKey

  var body: some View {
    Text(title)
      .font(.system(size: 13, weight: .bold, design: .rounded))
      .foregroundStyle(.white.opacity(0.7))
      .padding(.top, 4)
      .accessibilityAddTraits(.isHeader)
  }
}

extension OwlMood {
  /// A short line for Apple Watch, where every word counts.
  var watchMessage: String {
    switch self {
    case .sleeping: String(localized: "Markets closed. Your alerts stay on.")
    case .celebrating: String(localized: "A green day. I'm on watch.")
    case .reassuring: String(localized: "A red day. Plans pay off in dips.")
    case .calm: String(localized: "All quiet. I'm watching your zones.")
    }
  }
}

/// The greeting for the time of day, without depending on the app's own helpers.
enum WatchGreeting {
  static func text(at date: Date = .now) -> String {
    switch Calendar.current.component(.hour, from: date) {
    case 5..<12: String(localized: "Good morning")
    case 12..<18: String(localized: "Good afternoon")
    default: String(localized: "Good evening")
    }
  }
}
