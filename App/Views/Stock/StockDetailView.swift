import SwiftData
import SwiftUI

struct StockDetailView: View {
  var symbol: String

  @Query private var matches: [Holding]
  @Environment(QuoteStore.self) private var quotes
  @Environment(FlockService.self) private var flock
  @Environment(SubscriptionManager.self) private var subscription
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @State private var range: ChartRange = .month
  @State private var rangeQuote: Quote?
  @State private var editingAlert: AlertEditorTarget?
  @State private var showsPositionEditor = false
  @State private var showsRemoveConfirmation = false
  @State private var showsPaywall = false

  init(symbol: String) {
    self.symbol = symbol
    _matches = Query(filter: #Predicate<Holding> { $0.symbol == symbol })
  }

  private var holding: Holding? { matches.first }
  private var quote: Quote? { quotes[symbol] }
  private var chartValues: [Double] {
    range == .month ? (quote?.closes ?? []) : (rangeQuote?.closes ?? [])
  }

  var body: some View {
    Group {
      if let holding {
        content(for: holding)
      } else {
        ContentUnavailableView("Not Watching \(symbol)", systemImage: "binoculars", description: Text("This stock was removed."))
      }
    }
    .background(Palette.canvas)
    .navigationTitle(symbol)
    .navigationBarTitleDisplayMode(.inline)
    .sheet(item: $editingAlert) { target in
      if let holding {
        AlertEditorView(holding: holding, alert: target.alert)
      }
    }
    .sheet(isPresented: $showsPositionEditor) {
      if let holding { PositionEditorView(holding: holding) }
    }
    .sheet(isPresented: $showsPaywall) { PaywallView() }
    .task(id: range) {
      guard range != .month else { return }
      rangeQuote = try? await QuoteService().quote(for: symbol, range: range)
    }
  }

  private func content(for holding: Holding) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 28) {
        header(for: holding)
        alertsSection(for: holding)
        if holding.isOwned { positionSection(for: holding) }
        FlockStatsSection(symbol: symbol, quote: quote, userAlerts: holding.activeAlerts)
        DisclaimerFooter(lastUpdated: quote?.updatedAt)
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 32)
      .frame(maxWidth: 700)
      .frame(maxWidth: .infinity)
    }
    .refreshable { await quotes.refresh(symbols: [symbol]) }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Menu("Options", systemImage: "ellipsis") {
          Button(holding.isOwned ? "Edit Position" : "Add Position", systemImage: "chart.pie") { showsPositionEditor = true }
          Button("Stop Watching", systemImage: "trash", role: .destructive) { showsRemoveConfirmation = true }
        }
      }
    }
    .confirmationDialog("Stop watching \(symbol)?", isPresented: $showsRemoveConfirmation, titleVisibility: .visible) {
      Button("Stop Watching", role: .destructive) { remove(holding) }
    } message: {
      Text("This removes the stock and all of its alerts.")
    }
  }

  // MARK: Sections

  private func header(for holding: Holding) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 4) {
        Text(holding.name)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.white.opacity(0.65))
        Text(quote.map { $0.formatted($0.price) } ?? "—")
          .font(.system(size: 40, weight: .bold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(.white)
          .contentTransition(.numericText())
        if let quote {
          ChangeBadge(change: rangeChange ?? quote.change, caption: range == .month && rangeChange == nil ? "today" : range.title,
                      positiveColor: Brand.mint, negativeColor: Brand.loss)
        }
      }

      if chartValues.count > 1 {
        DipChart(
          values: chartValues,
          levels: holding.activeAlerts.map { alert in
            DipChart.Level(price: alert.targetPrice, kind: alert.kind, label: "\(alert.kind.shortTitle) \(quote?.formatted(alert.targetPrice) ?? "")")
          },
          owlSize: 46
        )
        .frame(height: 220)
      } else {
        ProgressView()
          .tint(.white)
          .frame(maxWidth: .infinity, minHeight: 220)
      }

      Picker("Range", selection: $range) {
        ForEach(ChartRange.allCases) { Text($0.title).tag($0) }
      }
      .pickerStyle(.segmented)
    }
    .padding(20)
    .background(Brand.nightGradient, in: .rect(cornerRadius: 32))
    .environment(\.colorScheme, .dark)
    .padding(.top, 8)
  }

  private var rangeChange: Double? {
    guard range != .month, let first = chartValues.first, let last = chartValues.last, first > 0 else { return nil }
    return last / first - 1
  }

  private func alertsSection(for holding: Holding) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      SectionHeader(title: "Your Alerts") {
        Button("Add Alert", systemImage: "plus") {
          if AlertLimits.canAddAlert(in: modelContext, isPro: subscription.isPro) {
            editingAlert = AlertEditorTarget(alert: nil)
          } else {
            showsPaywall = true
          }
        }
        .labelStyle(.iconOnly)
        .font(.title3.weight(.semibold))
      }
      let alerts = (holding.alerts ?? []).sorted { ($0.isActive ? 0 : 1, $0.targetPrice) < ($1.isActive ? 0 : 1, $1.targetPrice) }
      if alerts.isEmpty {
        EmptyHint(systemImage: "bell.badge", text: "No alerts yet. Tap + to choose the price you're waiting for.")
      } else {
        ForEach(alerts) { alert in
          Button {
            editingAlert = AlertEditorTarget(alert: alert)
          } label: {
            AlertCard(alert: alert, quote: quote)
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  private func positionSection(for holding: Holding) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      SectionHeader(title: "Your Position") {
        Button("Edit") { showsPositionEditor = true }
          .font(.subheadline.weight(.semibold))
      }
      VStack(spacing: 0) {
        PositionRow(title: "Shares", value: holding.shares.formatted())
        Divider().padding(.leading, 16)
        PositionRow(title: "Market value", value: quote.map { $0.formatted(holding.value(at: $0.price)) } ?? "—")
        if holding.averageCost > 0 {
          Divider().padding(.leading, 16)
          PositionRow(title: "Average cost", value: quote?.formatted(holding.averageCost) ?? holding.averageCost.formatted())
          if let quote, let gain = holding.gain(at: quote.price) {
            Divider().padding(.leading, 16)
            HStack {
              Text("Total return")
              Spacer()
              ChangeBadge(change: gain)
            }
            .padding(16)
          }
        }
      }
      .cardStyle()
    }
  }

  private func remove(_ holding: Holding) {
    let alerts = holding.alerts ?? []
    Task {
      for alert in alerts { await flock.withdraw(alert) }
    }
    modelContext.delete(holding)
    try? modelContext.save()
    SnapshotPublisher.publish(context: modelContext)
    dismiss()
  }
}

struct AlertEditorTarget: Identifiable {
  var alert: PriceAlert?
  var id: String { alert.map { "\($0.id)" } ?? "new" }
}

private struct PositionRow: View {
  var title: String
  var value: String

  var body: some View {
    HStack {
      Text(title)
      Spacer()
      Text(value)
        .monospacedDigit()
        .foregroundStyle(.secondary)
    }
    .padding(16)
  }
}
