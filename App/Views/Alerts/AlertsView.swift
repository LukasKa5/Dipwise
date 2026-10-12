import Charts
import SwiftData
import SwiftUI

/// Every alert, shown as one card per stock with its price, chart, and zones up front.
struct AlertsView: View {
  private enum Filter: String, CaseIterable, Identifiable {
    case active = "Active"
    case buy = "Buy"
    case sell = "Sell"
    case smart = "Smart"
    case history = "History"
    var id: Self { self }
  }

  private enum Sort: String, CaseIterable, Identifiable {
    case closest = "Closest to trigger"
    case newest = "Newest"
    case symbol = "Stock A–Z"
    case change = "Today's move"
    var id: Self { self }
  }

  @Query(sort: \Holding.addedAt) private var holdings: [Holding]
  @Environment(QuoteStore.self) private var quotes
  @Environment(SubscriptionManager.self) private var subscription
  @Environment(FlockService.self) private var flock
  @Environment(\.modelContext) private var modelContext
  @AppStorage("alertsSort") private var sortRaw = Sort.closest.rawValue
  @State private var filter: Filter = .active
  @State private var editor: AlertEditorRequest?
  @State private var journalAlert: PriceAlert?
  @State private var planHolding: Holding?
  @State private var showsPaywall = false

  private var sort: Sort { Sort(rawValue: sortRaw) ?? .closest }

  private func matches(_ alert: PriceAlert) -> Bool {
    switch filter {
    case .history: !alert.isActive
    case .active: alert.isActive
    case .buy: alert.isActive && alert.kind.side == .buy
    case .sell: alert.isActive && alert.kind.side == .sell
    case .smart: alert.isActive && alert.kind.requiresPro
    }
  }

  private func distance(of alert: PriceAlert) -> Double {
    quotes[alert.symbol].flatMap { alert.distance(for: $0) } ?? .infinity
  }

  private var groups: [(holding: Holding, alerts: [PriceAlert])] {
    let result = holdings.compactMap { holding -> (Holding, [PriceAlert])? in
      let alerts = (holding.alerts ?? []).filter(matches).sorted { lhs, rhs in
        filter == .history ? (lhs.triggeredAt ?? lhs.createdAt) > (rhs.triggeredAt ?? rhs.createdAt) : distance(of: lhs) < distance(of: rhs)
      }
      // Show stocks without alerts too in the Active view, so they can get a plan.
      if alerts.isEmpty && filter != .active { return nil }
      return (holding, alerts)
    }
    switch sort {
    case .symbol: return result.sorted { $0.0.symbol < $1.0.symbol }
    case .newest: return result.sorted { ($0.1.first?.createdAt ?? .distantPast) > ($1.1.first?.createdAt ?? .distantPast) }
    case .change: return result.sorted { abs(quotes[$0.0.symbol]?.change ?? 0) > abs(quotes[$1.0.symbol]?.change ?? 0) }
    case .closest: return result.sorted { ($0.1.first.map(distance) ?? .infinity) < ($1.1.first.map(distance) ?? .infinity) }
    }
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 18) {
          filterBar

          if !subscription.isPro {
            FreePlanUsage(used: holdings.flatMap(\.activeAlerts).count) { showsPaywall = true }
              .padding(16)
              .cardStyle()
          }

          if holdings.isEmpty {
            ContentUnavailableView("No Alerts Yet", systemImage: "bell.badge", description: Text("Add a stock, then set a green buy zone or a red sell zone. Dippy watches it day and night."))
              .padding(.top, 40)
          } else if groups.isEmpty {
            EmptyHint(systemImage: "clock.arrow.circlepath", text: filter == .history ? "Alerts that fire will appear here, ready for your Dip Journal." : "No alerts match this filter.")
          }

          ForEach(groups, id: \.holding.id) { group in
            StockAlertsCard(
              holding: group.holding,
              quote: quotes[group.holding.symbol],
              alerts: group.alerts,
              showsOdds: subscription.isPro,
              edit: { alert in
                if alert.isActive { editor = AlertEditorRequest(holding: group.holding, alert: alert) } else { journalAlert = alert }
              },
              add: { addAlert(for: group.holding) },
              plan: { planHolding = group.holding },
              delete: delete,
              rearm: rearm,
              journal: { journalAlert = $0 }
            )
          }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
        .frame(maxWidth: 700)
        .frame(maxWidth: .infinity)
      }
      .background(Palette.canvas)
      .navigationTitle("Alerts")
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          NavigationLink {
            AlertInsightsView()
          } label: {
            Label("Insights", systemImage: "chart.bar.xaxis")
          }
        }
        ToolbarItem(placement: .topBarTrailing) {
          Menu("Sort", systemImage: "arrow.up.arrow.down") {
            Picker("Sort by", selection: $sortRaw) {
              ForEach(Sort.allCases) { Text($0.rawValue).tag($0.rawValue) }
            }
          }
        }
      }
      .refreshable { await MarketMonitor.refresh(context: modelContext, quotes: quotes, flock: flock) }
      .navigationDestination(for: String.self) { StockDetailView(symbol: $0) }
      .sheet(item: $editor) { request in
        AlertEditorView(holding: request.holding, alert: request.alert)
      }
      .sheet(item: $journalAlert) { alert in JournalSheet(alert: alert, quote: quotes[alert.symbol]) }
      .sheet(item: $planHolding) { holding in PlanBuilderView(holding: holding) }
      .sheet(isPresented: $showsPaywall) { PaywallView() }
    }
  }

  private var filterBar: some View {
    ScrollView(.horizontal) {
      HStack(spacing: 8) {
        ForEach(Filter.allCases) { item in
          let isSelected = filter == item
          Button(item.rawValue) {
            withAnimation(.snappy) { filter = item }
          }
          .font(.subheadline.weight(.semibold))
          .padding(.horizontal, 16)
          .padding(.vertical, 9)
          .foregroundStyle(isSelected ? .white : .primary)
          .background(isSelected ? AnyShapeStyle(Brand.nightMiddle) : AnyShapeStyle(Palette.card), in: .capsule)
          .overlay { Capsule().strokeBorder(.quaternary, lineWidth: isSelected ? 0 : 1) }
          .buttonStyle(.plain)
          .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
      }
    }
    .scrollIndicators(.hidden)
    .scrollClipDisabled()
    .padding(.top, 8)
    .sensoryFeedback(.selection, trigger: filter)
  }

  private func addAlert(for holding: Holding) {
    if AlertLimits.canAddAlert(in: modelContext, isPro: subscription.isPro) {
      editor = AlertEditorRequest(holding: holding, alert: nil)
    } else {
      showsPaywall = true
    }
  }

  private func delete(_ alert: PriceAlert) {
    Task { await flock.withdraw(alert) }
    withAnimation(.smooth) { modelContext.delete(alert) }
    try? modelContext.save()
    SnapshotPublisher.publish(context: modelContext)
  }

  private func rearm(_ alert: PriceAlert) {
    guard AlertLimits.canAddAlert(in: modelContext, isPro: subscription.isPro) else {
      showsPaywall = true
      return
    }
    alert.rearm(currentPrice: quotes[alert.symbol]?.price ?? alert.priceAtCreation)
    try? modelContext.save()
    SnapshotPublisher.publish(context: modelContext)
  }
}

struct AlertEditorRequest: Identifiable {
  var holding: Holding
  var alert: PriceAlert?
  var id: String { alert.map { "\($0.id)" } ?? "new-\(holding.symbol)" }
}

/// One stock and all of its alerts.
private struct StockAlertsCard: View {
  var holding: Holding
  var quote: Quote?
  var alerts: [PriceAlert]
  var showsOdds: Bool
  var edit: (PriceAlert) -> Void
  var add: () -> Void
  var plan: () -> Void
  var delete: (PriceAlert) -> Void
  var rearm: (PriceAlert) -> Void
  var journal: (PriceAlert) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      NavigationLink(value: holding.symbol) {
        VStack(alignment: .leading, spacing: 12) {
          HStack(spacing: 12) {
            TickerBadge(symbol: holding.symbol, size: 48)
            VStack(alignment: .leading, spacing: 2) {
              Text(holding.symbol)
                .font(.title3.bold())
              Text(holding.name)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            Spacer()
            if let quote {
              VStack(alignment: .trailing, spacing: 2) {
                Text(quote.formatted(quote.price))
                  .font(.title3.bold().monospacedDigit())
                ChangeBadge(change: quote.change)
              }
            }
            Image(systemName: "chevron.forward")
              .font(.footnote.weight(.bold))
              .foregroundStyle(.tertiary)
          }
          if let quote {
            MiniPlanChart(quote: quote, buyZone: holding.buyZone, sellZone: holding.sellZone)
              .frame(height: 76)
              .padding(10)
              .background(Palette.canvas.opacity(0.7), in: .rect(cornerRadius: 16))
          }
        }
        .padding(16)
        .contentShape(.rect)
      }
      .buttonStyle(.plain)

      Divider().padding(.horizontal, 16)

      if alerts.isEmpty {
        Text("No alerts yet. Give \(holding.symbol) a plan.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .padding(.horizontal, 18)
          .padding(.vertical, 12)
      }

      ForEach(alerts) { alert in
        Button {
          edit(alert)
        } label: {
          AlertRow(alert: alert, quote: quote, showsOdds: showsOdds)
        }
        .buttonStyle(.plain)
        .contextMenu {
          Button(alert.isActive ? "Edit" : "Log Decision", systemImage: alert.isActive ? "pencil" : "book.closed") { edit(alert) }
          if !alert.isActive {
            Button("Re-arm", systemImage: "arrow.clockwise") { rearm(alert) }
          }
          Button("Delete", systemImage: "trash", role: .destructive) { delete(alert) }
        }
        if alert.id != alerts.last?.id {
          Divider().padding(.leading, 64)
        }
      }

      HStack(spacing: 10) {
        Button(action: add) {
          Label("Add alert", systemImage: "plus")
            .frame(maxWidth: .infinity)
        }
        Button(action: plan) {
          Label("Plan", systemImage: "wand.and.stars")
            .frame(maxWidth: .infinity)
        }
      }
      .font(.subheadline.weight(.semibold))
      .buttonStyle(.bordered)
      .padding(12)
    }
    .cardStyle(cornerRadius: 26)
  }
}

/// A compact price chart with the stock's buy zone in green and sell zone in red.
private struct MiniPlanChart: View {
  var quote: Quote
  var buyZone: PriceAlert?
  var sellZone: PriceAlert?

  var body: some View {
    let values = Array(quote.closes.suffix(44))
    let zones = [buyZone, sellZone].compactMap { $0 }
    let bounds = values + zones.flatMap { [$0.targetPrice, max($0.targetPrice, $0.upperPrice)] }
    let isUp = (values.last ?? 0) >= (values.first ?? 0)
    Chart {
      ForEach(zones) { zone in
        RectangleMark(yStart: .value("Low", zone.targetPrice), yEnd: .value("High", max(zone.targetPrice * 1.003, zone.upperPrice)))
          .foregroundStyle(zone.kind.side.color.opacity(0.28))
      }
      ForEach(Array(values.enumerated()), id: \.offset) { index, value in
        LineMark(x: .value("Day", index), y: .value("Price", value))
          .foregroundStyle(isUp ? Palette.gain : Palette.loss)
          .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
          .interpolationMethod(.monotone)
      }
      if let last = values.last {
        PointMark(x: .value("Day", values.count - 1), y: .value("Price", last))
          .symbolSize(50)
          .foregroundStyle(isUp ? Palette.gain : Palette.loss)
      }
    }
    .chartXAxis(.hidden)
    .chartYAxis(.hidden)
    .chartYScale(domain: (bounds.min() ?? 0) * 0.99...(bounds.max() ?? 1) * 1.04)
    .chartOverlay { proxy in
      GeometryReader { geometry in
        if let plotFrame = proxy.plotFrame,
           let dip = values.indices.dropLast().min(by: { values[$0] < values[$1] }),
           let position = proxy.position(for: (x: dip, y: values[dip])) {
          let origin = geometry[plotFrame].origin
          LivelyOwl(hopsOnTap: false)
            .frame(width: 24, height: 28)
            .position(x: origin.x + position.x, y: origin.y + position.y - 14)
        }
      }
    }
    .accessibilityHidden(true)
  }
}

private struct AlertRow: View {
  var alert: PriceAlert
  var quote: Quote?
  var showsOdds: Bool

  var body: some View {
    let tint = alert.kind.side.color
    let distance = quote.flatMap { alert.distance(for: $0) }
    HStack(spacing: 12) {
      Image(systemName: alert.kind.systemImage)
        .font(.subheadline.weight(.bold))
        .foregroundStyle(tint)
        .frame(width: 36, height: 36)
        .background(tint.opacity(0.14), in: .circle)
      VStack(alignment: .leading, spacing: 4) {
        Text(alert.summary(for: quote))
          .font(.subheadline.weight(.semibold))
          .fixedSize(horizontal: false, vertical: true)
        if alert.isActive {
          if let quote {
            TargetTrack(progress: alert.progress(for: quote), isReached: distance == 0, tint: tint)
          }
          if showsOdds, let quote, let odds = AlertOdds(rule: alert.rule, quote: quote), (distance ?? 1) > 0 {
            Label(odds.headline, systemImage: "dice")
              .font(.caption)
              .foregroundStyle(Palette.amber)
          }
        } else if let price = alert.triggeredPrice {
          HStack(spacing: 6) {
            Text("Fired at \(quote?.formatted(price) ?? price.formatted())")
            if let quote { ChangeBadge(change: quote.price / price - 1, caption: "since") }
          }
          .font(.caption)
          .foregroundStyle(.secondary)
          Text(alert.journalAction.map { "You \($0.title.lowercased())" } ?? "Tap to log what you did")
            .font(.caption.weight(.semibold))
            .foregroundStyle(alert.journalAction == nil ? AnyShapeStyle(.tint) : AnyShapeStyle(Palette.amber))
        }
      }
      Spacer(minLength: 6)
      if alert.isActive {
        Text(distance == 0 ? "Now" : distance.map { $0.formatted(.percent.precision(.fractionLength(1))) } ?? "—")
          .font(.subheadline.bold().monospacedDigit())
          .foregroundStyle(distance == 0 || (distance ?? 1) < 0.035 ? tint : .secondary)
      } else if let triggeredAt = alert.triggeredAt {
        Text(triggeredAt, format: .relative(presentation: .named))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .contentShape(.rect)
    .accessibilityElement(children: .combine)
  }
}

private struct FreePlanUsage: View {
  var used: Int
  var upgrade: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("Free plan")
          .font(.headline)
        Spacer()
        Text("\(min(used, FreeTier.maxActiveAlerts)) of \(FreeTier.maxActiveAlerts) alerts")
          .font(.subheadline.monospacedDigit())
          .foregroundStyle(.secondary)
      }
      ProgressView(value: Double(min(used, FreeTier.maxActiveAlerts)), total: Double(FreeTier.maxActiveAlerts))
        .tint(Palette.amber)
      Button(action: upgrade) {
        HStack {
          ProBadge()
          Text("Unlimited alerts, 20 smart alert types & odds")
            .font(.subheadline.weight(.semibold))
          Spacer()
          Image(systemName: "chevron.forward")
            .font(.footnote.weight(.semibold))
        }
      }
      .buttonStyle(.plain)
      .foregroundStyle(.tint)
    }
  }
}
