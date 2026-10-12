import Charts
import SwiftData
import SwiftUI

/// Statistics about the user's alerts: plan health, odds, and how past alerts worked out.
struct AlertInsightsView: View {
  @Query(sort: \Holding.addedAt) private var holdings: [Holding]
  @Environment(QuoteStore.self) private var quotes
  @Environment(SubscriptionManager.self) private var subscription
  @State private var planHolding: Holding?
  @State private var signalRequest: AlertEditorRequest?
  @State private var signalRule: AlertRule?

  private var insights: AlertInsights { AlertInsights(holdings: holdings, quotes: quotes.quotes) }
  private var isPro: Bool { subscription.isPro }

  var body: some View {
    let insights = insights
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        health(insights)
        signals
        coverage(insights)
        summary(insights)
        likely(insights)
        trackRecord(insights)
        missed(insights)
        activity(insights)
        gaps(insights)
        Text("Odds are estimates from each stock's past year of price moves. They aren't predictions or investment advice.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .padding(20)
      .frame(maxWidth: 700)
      .frame(maxWidth: .infinity)
    }
    .background(Palette.canvas)
    .navigationTitle("Insights")
    .navigationBarTitleDisplayMode(.inline)
    .sheet(item: $planHolding) { PlanBuilderView(holding: $0) }
    .sheet(item: $signalRequest) { request in
      AlertEditorView(holding: request.holding, alert: nil, initialRule: signalRule)
    }
  }

  // MARK: Sections

  private func health(_ insights: AlertInsights) -> some View {
    HStack(spacing: 18) {
      ZStack {
        Circle().stroke(.white.opacity(0.12), lineWidth: 10)
        Circle()
          .trim(from: 0, to: Double(insights.planHealth) / 100)
          .stroke(Palette.buy, style: StrokeStyle(lineWidth: 10, lineCap: .round))
          .rotationEffect(.degrees(-90))
        Text("\(insights.planHealth)")
          .font(.system(size: 30, weight: .heavy, design: .rounded))
      }
      .frame(width: 92, height: 92)
      .overlay(alignment: .topTrailing) {
        // Dippy perches on the ring, leaving the text room to breathe.
        LivelyOwl().frame(width: 32, height: 37).offset(x: 8, y: -16)
      }
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 2) {
          Text("Plan health")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          InfoButton(topic: .planHealth)
        }
        Text(insights.healthLabel)
          .font(.title2.bold())
          .fixedSize(horizontal: false, vertical: true)
        Text("Every stock needs a buy zone, a sell zone, and protection.")
          .font(.footnote)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(20)
    .padding(.top, 6)
    .heroCardStyle()
    .accessibilityElement(children: .combine)
  }

  private var signals: some View {
    let found = SignalScanner.signals(for: holdings, quotes: quotes.quotes)
    return VStack(alignment: .leading, spacing: 14) {
      SectionHeader(title: "Signals right now", subtitle: "What the indicators say about your stocks today") {
        InfoButton(topic: .signals)
      }
      if found.isEmpty {
        EmptyHint(systemImage: "dot.radiowaves.left.and.right", text: "No strong signals on your stocks today. Dippy keeps scanning.")
      } else {
        VStack(spacing: 0) {
          ForEach(Array(found.enumerated()), id: \.element.id) { index, signal in
            signalRow(signal)
              .proLocked(!isPro && index >= 2, message: "See every live signal")
            if index < found.count - 1 {
              Divider().padding(.leading, 60)
            }
          }
        }
        .cardStyle()
      }
    }
  }

  private func signalRow(_ signal: MarketSignal) -> some View {
    let holding = holdings.first { $0.symbol == signal.symbol }
    let hasAlert = holding?.activeAlerts.contains { $0.kind == signal.kind } ?? false
    return HStack(spacing: 12) {
      Image(systemName: signal.kind.systemImage)
        .font(.subheadline.weight(.bold))
        .foregroundStyle(signal.kind.side.color)
        .frame(width: 36, height: 36)
        .background(signal.kind.side.color.opacity(0.14), in: .circle)
      VStack(alignment: .leading, spacing: 2) {
        Text("\(signal.symbol) · \(signal.headline)")
          .font(.subheadline.weight(.semibold))
        Text(signal.detail)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
      if hasAlert {
        Image(systemName: "bell.fill")
          .foregroundStyle(.secondary)
          .accessibilityLabel("Alert already set")
      } else if let holding, let quote = quotes[signal.symbol] {
        Button("Alert me") {
          signalRule = AlertRule.defaults(for: signal.kind, price: quote.price, cost: holding.averageCost)
          signalRequest = AlertEditorRequest(holding: holding, alert: nil)
        }
        .font(.caption.weight(.semibold))
        .buttonStyle(.bordered)
        .controlSize(.small)
      }
    }
    .padding(14)
    .accessibilityElement(children: .combine)
  }

  private func coverage(_ insights: AlertInsights) -> some View {
    let counts = Dictionary(grouping: insights.active, by: \.kind.category).mapValues(\.count)
    return VStack(alignment: .leading, spacing: 14) {
      SectionHeader(title: "Your alert toolkit", subtitle: "Active alerts by type")
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
        ForEach(AlertCategory.allCases) { category in
          let count = counts[category] ?? 0
          VStack(alignment: .leading, spacing: 6) {
            Text("\(count)")
              .font(.title2.bold().monospacedDigit())
              .foregroundStyle(count > 0 ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
            Text(category.title)
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .minimumScaleFactor(0.8)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(12)
          .cardStyle(cornerRadius: 16)
          .accessibilityElement(children: .combine)
        }
      }
    }
  }

  private func summary(_ insights: AlertInsights) -> some View {
    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
      StatTile(title: "Watching now", value: "\(insights.active.count)", systemImage: "eye.fill", tint: Palette.buy)
      StatTile(title: "Fired so far", value: "\(insights.fired.count)", systemImage: "bell.badge.fill", tint: Palette.amber)
      StatTile(title: "Hit rate", value: insights.hitRate.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? "—", systemImage: "target", tint: Palette.buy)
      StatTile(title: "Avg. wait to fire", value: insights.averageDaysToFire.map { "\(Int($0.rounded())) days" } ?? "—", systemImage: "hourglass", tint: Palette.amber)
    }
  }

  private func likely(_ insights: AlertInsights) -> some View {
    InsightSection(title: "Most likely next", subtitle: "Chance to fire within 30 days", systemImage: "dice.fill", isLocked: !isPro, message: "See the odds for every alert") {
      if insights.mostLikely.isEmpty {
        Text("Set a few alerts to see their odds.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      } else {
        VStack(spacing: 14) {
          ForEach(insights.mostLikely.prefix(6)) { item in
            NavigationLink(value: item.alert.symbol) {
              HStack(spacing: 12) {
                TickerBadge(symbol: item.alert.symbol, size: 34)
                VStack(alignment: .leading, spacing: 5) {
                  HStack {
                    Text(item.alert.symbol).font(.subheadline.bold())
                    Text(item.alert.summary(for: quotes[item.alert.symbol]))
                      .font(.caption)
                      .foregroundStyle(item.alert.kind.side.color)
                      .lineLimit(1)
                  }
                  GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                      Capsule().fill(.quaternary)
                      Capsule().fill(item.alert.kind.side.color)
                        .frame(width: max(4, geometry.size.width * item.odds.monthChance))
                    }
                  }
                  .frame(height: 6)
                  Text(item.odds.lastTriggeredText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                Text(item.odds.monthChance, format: .percent.precision(.fractionLength(0)))
                  .font(.headline.monospacedDigit())
                  .frame(width: 48, alignment: .trailing)
              }
              .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
          }
        }
      }
    }
  }

  private func trackRecord(_ insights: AlertInsights) -> some View {
    InsightSection(title: "How your alerts worked out", subtitle: "Price change since each alert fired", systemImage: "checkmark.seal.fill", isLocked: !isPro, message: "See your alert track record") {
      if insights.buyOutcomes.isEmpty && insights.sellOutcomes.isEmpty {
        Text("When your alerts fire, Dippy tracks what the price did next.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      } else {
        VStack(alignment: .leading, spacing: 14) {
          HStack(spacing: 12) {
            MiniStat(title: "Buy alerts since", value: insights.buyAverage.map { $0.formatted(.percent.precision(.fractionLength(1)).sign(strategy: .always())) } ?? "—",
                     color: (insights.buyAverage ?? 0) >= 0 ? Palette.gain : Palette.loss)
            MiniStat(title: "Buys in profit", value: insights.buyWinRate.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? "—")
            MiniStat(title: "Good sell calls", value: insights.sellGoodCalls.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? "—")
          }
          ForEach((insights.buyOutcomes + insights.sellOutcomes).prefix(6)) { outcome in
            HStack {
              Image(systemName: outcome.alert.kind.systemImage)
                .foregroundStyle(outcome.alert.kind.side.color)
                .frame(width: 22)
              Text(outcome.alert.symbol).font(.subheadline.bold())
              Text(outcome.alert.triggeredAt.map { "fired \($0.formatted(.relative(presentation: .named)))" } ?? "")
                .font(.caption)
                .foregroundStyle(.secondary)
              Spacer()
              ChangeBadge(change: outcome.change)
            }
            .accessibilityElement(children: .combine)
          }
        }
      }
    }
  }

  @ViewBuilder
  private func missed(_ insights: AlertInsights) -> some View {
    if !insights.missed.isEmpty {
      InsightSection(title: "Missed opportunities", subtitle: "Buy alerts that fired and rose since", systemImage: "exclamationmark.bubble.fill", isLocked: !isPro, message: "See the dips you didn't act on") {
        VStack(spacing: 10) {
          ForEach(insights.missed.prefix(4)) { outcome in
            HStack {
              Text(outcome.alert.symbol).font(.subheadline.bold())
              Text(outcome.alert.summary(for: quotes[outcome.alert.symbol]))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
              Spacer()
              Text("up \(outcome.change.formatted(.percent.precision(.fractionLength(1))))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.gain)
            }
            .accessibilityElement(children: .combine)
          }
          Text("Consider adding a budget to your buy zones so you're ready next time.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  private func activity(_ insights: AlertInsights) -> some View {
    InsightSection(title: "Alerts fired", subtitle: "Last 12 weeks", systemImage: "chart.bar.fill", isLocked: !isPro, message: "See your alert activity over time") {
      Chart(insights.weeklyFired, id: \.week) { item in
        BarMark(x: .value("Week", item.week, unit: .weekOfYear), y: .value("Fired", item.count))
          .foregroundStyle(Palette.amber.gradient)
          .cornerRadius(4)
      }
      .chartXAxis {
        AxisMarks(values: .stride(by: .month)) { _ in
          AxisValueLabel(format: .dateTime.month(.abbreviated))
        }
      }
      .frame(height: 130)
      .accessibilityLabel("Alerts fired per week")
    }
  }

  @ViewBuilder
  private func gaps(_ insights: AlertInsights) -> some View {
    if !insights.gaps.isEmpty {
      VStack(alignment: .leading, spacing: 14) {
        SectionHeader(title: "Finish your plans", subtitle: "Quick wins for a healthier plan")
        VStack(spacing: 0) {
          ForEach(insights.gaps.prefix(6)) { gap in
            HStack(spacing: 12) {
              TickerBadge(symbol: gap.holding.symbol, size: 34)
              VStack(alignment: .leading, spacing: 2) {
                Text(gap.holding.symbol).font(.subheadline.bold())
                Text("No \(gap.missing) yet")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              Spacer()
              Button("Add") { planHolding = gap.holding }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(14)
            if gap.id != insights.gaps.prefix(6).last?.id {
              Divider().padding(.leading, 60)
            }
          }
        }
        .cardStyle()
      }
    }
  }
}

private struct InsightSection<Content: View>: View {
  var title: String
  var subtitle: String
  var systemImage: String
  var isLocked: Bool
  var message: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 2) {
          Label(title, systemImage: systemImage)
            .font(.headline)
          Text(subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        if isLocked { ProBadge() }
      }
      content
        .proLocked(isLocked, message: message)
    }
    .padding(18)
    .cardStyle()
  }
}
