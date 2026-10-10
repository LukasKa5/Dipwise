import Charts
import SwiftData
import SwiftUI

/// Every alert, grouped by stock, with sorting and filters.
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
    case type = "Alert type"
    var id: Self { self }
  }

  @Query(sort: \Holding.addedAt) private var holdings: [Holding]
  @Environment(QuoteStore.self) private var quotes
  @Environment(SubscriptionManager.self) private var subscription
  @Environment(FlockService.self) private var flock
  @Environment(\.modelContext) private var modelContext
  @AppStorage("alertsSort") private var sortRaw = Sort.closest.rawValue
  @AppStorage("alertsGrouped") private var grouped = true
  @State private var filter: Filter = .active
  @State private var editor: (holding: Holding, alert: PriceAlert?)?
  @State private var journalAlert: PriceAlert?
  @State private var planHolding: Holding?
  @State private var showsPaywall = false

  private var sort: Sort { Sort(rawValue: sortRaw) ?? .closest }

  private func matches(_ alert: PriceAlert) -> Bool {
    switch filter {
    case .history: !alert.isActive
    case .active: alert.isActive
    case .buy: alert.isActive && alert.kind.side == .buy && !alert.kind.requiresPro
    case .sell: alert.isActive && alert.kind.side == .sell && !alert.kind.requiresPro
    case .smart: alert.isActive && alert.kind.requiresPro
    }
  }

  private func distance(of alert: PriceAlert) -> Double {
    quotes[alert.symbol].flatMap { alert.distance(for: $0) } ?? .infinity
  }

  private func sorted(_ alerts: [PriceAlert]) -> [PriceAlert] {
    alerts.sorted { lhs, rhs in
      switch sort {
      case .closest: filter == .history ? (lhs.triggeredAt ?? lhs.createdAt) > (rhs.triggeredAt ?? rhs.createdAt) : distance(of: lhs) < distance(of: rhs)
      case .newest: lhs.createdAt > rhs.createdAt
      case .symbol: (lhs.symbol, distance(of: lhs)) < (rhs.symbol, distance(of: rhs))
      case .type: (AlertKind.allCases.firstIndex(of: lhs.kind) ?? 0, distance(of: lhs)) < (AlertKind.allCases.firstIndex(of: rhs.kind) ?? 0, distance(of: rhs))
      }
    }
  }

  private var allMatching: [PriceAlert] {
    holdings.flatMap { $0.alerts ?? [] }.filter(matches)
  }

  /// Stocks with matching alerts, ordered by their closest alert or by name.
  private var groups: [(holding: Holding, alerts: [PriceAlert])] {
    let result = holdings.compactMap { holding -> (Holding, [PriceAlert])? in
      let alerts = sorted((holding.alerts ?? []).filter(matches))
      return alerts.isEmpty ? nil : (holding, alerts)
    }
    switch sort {
    case .symbol: return result.sorted { $0.0.symbol < $1.0.symbol }
    case .newest: return result.sorted { ($0.1.first?.createdAt ?? .distantPast) > ($1.1.first?.createdAt ?? .distantPast) }
    default: return result.sorted { distance(of: $0.1[0]) < distance(of: $1.1[0]) }
    }
  }

  var body: some View {
    NavigationStack {
      List {
        Section {
          Picker("Filter", selection: $filter.animation(.snappy)) {
            ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
          }
          .pickerStyle(.segmented)
          .listRowBackground(Color.clear)
          .listRowInsets(EdgeInsets())
        }

        if !subscription.isPro {
          Section {
            FreePlanUsage(used: holdings.flatMap(\.activeAlerts).count) { showsPaywall = true }
          }
        }

        if grouped {
          ForEach(groups, id: \.holding.id) { group in
            Section {
              ForEach(group.alerts) { alert in
                row(for: alert, holding: group.holding, showsSymbol: false)
              }
            } header: {
              StockGroupHeader(holding: group.holding, quote: quotes[group.holding.symbol], count: group.alerts.count) {
                addAlert(for: group.holding)
              }
            }
          }
        } else {
          Section {
            ForEach(sorted(allMatching)) { alert in
              if let holding = alert.holding {
                row(for: alert, holding: holding, showsSymbol: true)
              }
            }
          }
        }

        if allMatching.isEmpty && !holdings.isEmpty {
          Section {
            Text(filter == .history ? "Alerts that fire will appear here, ready for your Dip Journal." : "Nothing here yet. Tap + on a stock to build its plan.")
              .foregroundStyle(.secondary)
          }
        }
      }
      .listStyle(.insetGrouped)
      .scrollContentBackground(.hidden)
      .background(Palette.canvas)
      .navigationTitle("Alerts")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Menu("Sort", systemImage: "arrow.up.arrow.down") {
            Picker("Sort by", selection: $sortRaw) {
              ForEach(Sort.allCases) { Text($0.rawValue).tag($0.rawValue) }
            }
            Toggle("Group by stock", systemImage: "square.stack.3d.up", isOn: $grouped.animation(.snappy))
          }
        }
      }
      .refreshable { await MarketMonitor.refresh(context: modelContext, quotes: quotes, flock: flock) }
      .navigationDestination(for: String.self) { StockDetailView(symbol: $0) }
      .sheet(isPresented: Binding(get: { editor != nil }, set: { if !$0 { editor = nil } })) {
        if let editor { AlertEditorView(holding: editor.holding, alert: editor.alert) }
      }
      .sheet(item: $journalAlert) { alert in JournalSheet(alert: alert, quote: quotes[alert.symbol]) }
      .sheet(item: $planHolding) { holding in PlanBuilderView(holding: holding) }
      .sheet(isPresented: $showsPaywall) { PaywallView() }
      .overlay {
        if holdings.isEmpty {
          ContentUnavailableView("No Alerts Yet", systemImage: "bell.badge", description: Text("Add a stock, then set a green buy zone or a red sell zone. Dipwise watches it day and night."))
        }
      }
    }
  }

  private func row(for alert: PriceAlert, holding: Holding, showsSymbol: Bool) -> some View {
    Button {
      if alert.isActive { editor = (holding, alert) } else { journalAlert = alert }
    } label: {
      AlertListRow(alert: alert, quote: quotes[alert.symbol], showsSymbol: showsSymbol)
    }
    .buttonStyle(.plain)
    .swipeActions {
      Button("Delete", systemImage: "trash", role: .destructive) { delete(alert) }
      if !alert.isActive {
        Button("Re-arm", systemImage: "arrow.clockwise") { rearm(alert) }
          .tint(Palette.buy)
      }
    }
    .swipeActions(edge: .leading) {
      NavigationLink(value: holding.symbol) {
        Label("Open \(holding.symbol)", systemImage: "chart.xyaxis.line")
      }
      .tint(.indigo)
      if !alert.isActive {
        Button("Journal", systemImage: "book.closed") { journalAlert = alert }
          .tint(Palette.amber)
      }
    }
    .contextMenu {
      NavigationLink(value: holding.symbol) { Label("Open \(holding.symbol)", systemImage: "chart.xyaxis.line") }
      Button("Edit", systemImage: "pencil") { editor = (holding, alert) }
      if !alert.isActive {
        Button("Log Decision", systemImage: "book.closed") { journalAlert = alert }
        Button("Re-arm", systemImage: "arrow.clockwise") { rearm(alert) }
      }
      Button("Delete", systemImage: "trash", role: .destructive) { delete(alert) }
    }
  }

  private func addAlert(for holding: Holding) {
    if AlertLimits.canAddAlert(in: modelContext, isPro: subscription.isPro) {
      planHolding = holding
    } else {
      showsPaywall = true
    }
  }

  private func delete(_ alert: PriceAlert) {
    Task { await flock.withdraw(alert) }
    modelContext.delete(alert)
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

/// A stock's header in the grouped alert list: price, trend, and a shortcut to add alerts.
private struct StockGroupHeader: View {
  var holding: Holding
  var quote: Quote?
  var count: Int
  var add: () -> Void

  var body: some View {
    HStack(spacing: 10) {
      NavigationLink(value: holding.symbol) {
        HStack(spacing: 10) {
          TickerBadge(symbol: holding.symbol, size: 32)
          VStack(alignment: .leading, spacing: 1) {
            Text(holding.symbol)
              .font(.headline)
              .foregroundStyle(.primary)
            if let quote {
              HStack(spacing: 6) {
                Text(quote.formatted(quote.price))
                  .monospacedDigit()
                ChangeBadge(change: quote.change)
              }
              .font(.caption)
              .foregroundStyle(.secondary)
            }
          }
          if let quote {
            Sparkline(values: quote.recent(22).values)
              .frame(width: 64, height: 26)
          }
        }
      }
      .buttonStyle(.plain)
      Spacer()
      Button("Add alert for \(holding.symbol)", systemImage: "plus.circle.fill", action: add)
        .labelStyle(.iconOnly)
        .font(.title2)
        .foregroundStyle(.tint)
    }
    .textCase(nil)
    .padding(.vertical, 4)
  }
}

struct Sparkline: View {
  var values: [Double]

  var body: some View {
    let isUp = (values.last ?? 0) >= (values.first ?? 0)
    Chart(Array(values.enumerated()), id: \.offset) { index, value in
      LineMark(x: .value("Day", index), y: .value("Price", value))
        .foregroundStyle(isUp ? Palette.gain : Palette.loss)
        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
        .interpolationMethod(.monotone)
    }
    .chartXAxis(.hidden)
    .chartYAxis(.hidden)
    .chartYScale(domain: (values.min() ?? 0)...(values.max() ?? 1))
    .accessibilityHidden(true)
  }
}

private struct AlertListRow: View {
  var alert: PriceAlert
  var quote: Quote?
  var showsSymbol: Bool

  private var tint: Color { alert.kind.side.color }

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: alert.kind.systemImage)
        .font(.subheadline.weight(.bold))
        .foregroundStyle(tint)
        .frame(width: 36, height: 36)
        .background(tint.opacity(0.14), in: .circle)
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text(showsSymbol ? "\(alert.symbol) · \(alert.summary(for: quote))" : alert.summary(for: quote))
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
          if alert.repeats {
            Image(systemName: "repeat")
              .font(.caption)
              .foregroundStyle(.secondary)
              .accessibilityLabel("Repeats")
          }
          Spacer()
          status
        }
        if alert.isActive {
          TargetTrack(progress: quote.map { alert.progress(for: $0) } ?? 0, isReached: quote.flatMap { alert.distance(for: $0) } == 0, tint: tint)
        } else if let price = alert.triggeredPrice {
          HStack(spacing: 6) {
            Text("Fired at \(quote?.formatted(price) ?? price.formatted())")
            if let quote {
              ChangeBadge(change: quote.price / price - 1, caption: "since")
            }
            Spacer()
            if let action = alert.journalAction {
              Label(action.title, systemImage: action.systemImage)
                .foregroundStyle(Palette.amber)
            } else {
              Text("Log decision")
                .foregroundStyle(.tint)
            }
          }
          .font(.caption)
          .foregroundStyle(.secondary)
        }
      }
    }
    .padding(.vertical, 4)
    .contentShape(.rect)
    .accessibilityElement(children: .combine)
  }

  @ViewBuilder
  private var status: some View {
    if alert.isActive, let quote, let distance = alert.distance(for: quote) {
      Text(distance == 0 ? "Active now" : "\(distance.formatted(.percent.precision(.fractionLength(1)))) away")
        .font(.caption.weight(.semibold).monospacedDigit())
        .foregroundStyle(distance < 0.035 ? tint : .secondary)
    } else if let triggeredAt = alert.triggeredAt {
      Text(triggeredAt, format: .relative(presentation: .named))
        .font(.caption)
        .foregroundStyle(.secondary)
    } else if alert.isExpired {
      Text("Expired")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
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
          Text("Unlimited plans, smart alerts & the full crowd report")
            .font(.subheadline.weight(.semibold))
          Spacer()
          Image(systemName: "chevron.forward")
            .font(.footnote.weight(.semibold))
        }
      }
      .buttonStyle(.plain)
      .foregroundStyle(.tint)
    }
    .padding(.vertical, 4)
  }
}
