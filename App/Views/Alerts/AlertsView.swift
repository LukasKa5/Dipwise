import SwiftData
import SwiftUI

struct AlertsView: View {
  private enum Filter: String, CaseIterable, Identifiable {
    case all = "All"
    case buy = "Buy"
    case sell = "Sell"
    case smart = "Smart"
    case reached = "History"
    var id: Self { self }
  }

  @Query(sort: \PriceAlert.createdAt, order: .reverse) private var alerts: [PriceAlert]
  @Environment(QuoteStore.self) private var quotes
  @Environment(SubscriptionManager.self) private var subscription
  @Environment(FlockService.self) private var flock
  @Environment(\.modelContext) private var modelContext
  @State private var filter: Filter = .all
  @State private var showsPaywall = false

  private var visible: [PriceAlert] {
    let tracked = alerts.filter { $0.holding != nil }
    switch filter {
    case .reached:
      return tracked.filter { !$0.isActive }.sorted { ($0.triggeredAt ?? $0.createdAt) > ($1.triggeredAt ?? $1.createdAt) }
    default:
      return tracked.filter { alert in
        guard alert.isActive else { return false }
        switch filter {
        case .buy: return alert.kind.side == .buy && !alert.kind.requiresPro
        case .sell: return alert.kind.side == .sell && !alert.kind.requiresPro
        case .smart: return alert.kind.requiresPro
        default: return true
        }
      }
      .sorted { distance(of: $0) < distance(of: $1) }
    }
  }

  private var activeCount: Int { alerts.filter { $0.isActive && $0.holding != nil }.count }

  var body: some View {
    NavigationStack {
      List {
        Section {
          Picker("Filter", selection: $filter) {
            ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
          }
          .pickerStyle(.segmented)
          .listRowBackground(Color.clear)
          .listRowInsets(EdgeInsets())
        }

        if !subscription.isPro {
          Section {
            FreePlanUsage(used: activeCount) { showsPaywall = true }
          }
        }

        Section {
          if visible.isEmpty {
            Text(filter == .reached ? "Alerts that fire will show up here." : "No alerts here yet. Open a stock to set a buy zone, sell zone, or smart alert.")
              .foregroundStyle(.secondary)
          }
          ForEach(visible) { alert in
            NavigationLink(value: alert.symbol) {
              AlertListRow(alert: alert, quote: quotes[alert.symbol])
            }
            .swipeActions {
              Button("Delete", systemImage: "trash", role: .destructive) { delete(alert) }
              if !alert.isActive {
                Button("Re-arm", systemImage: "arrow.clockwise") { rearm(alert) }
                  .tint(Palette.green)
              }
            }
          }
        }
      }
      .scrollContentBackground(.hidden)
      .background(Palette.canvas)
      .navigationTitle("Alerts")
      .refreshable { await MarketMonitor.refresh(context: modelContext, quotes: quotes, flock: flock) }
      .navigationDestination(for: String.self) { StockDetailView(symbol: $0) }
      .sheet(isPresented: $showsPaywall) { PaywallView() }
      .overlay {
        if alerts.isEmpty {
          ContentUnavailableView("No Alerts Yet", systemImage: "bell.badge", description: Text("Set a buy zone or sell zone on any stock and Dipwise will watch it day and night."))
        }
      }
    }
  }

  private func distance(of alert: PriceAlert) -> Double {
    quotes[alert.symbol].flatMap { alert.distance(for: $0) } ?? .infinity
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

private struct AlertListRow: View {
  var alert: PriceAlert
  var quote: Quote?

  private var tint: Color { alert.kind.side == .sell ? Palette.green : Palette.amber }

  var body: some View {
    HStack(spacing: 14) {
      TickerBadge(symbol: alert.symbol, size: 40)
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text(alert.symbol)
            .font(.headline)
          if alert.repeats {
            Image(systemName: "repeat")
              .font(.caption)
              .foregroundStyle(.secondary)
              .accessibilityLabel("Repeats")
          }
          Spacer()
          if alert.isActive, let quote, let distance = alert.distance(for: quote) {
            Text(distance == 0 ? "Active now" : "\(distance.formatted(.percent.precision(.fractionLength(1)))) away")
              .font(.subheadline.weight(.semibold).monospacedDigit())
              .foregroundStyle(distance < 0.035 ? tint : .secondary)
          } else if let triggeredAt = alert.triggeredAt {
            Text(triggeredAt, format: .relative(presentation: .named))
              .font(.subheadline)
              .foregroundStyle(.secondary)
          } else if alert.isExpired {
            Text("Expired")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        }
        Label(alert.summary(for: quote), systemImage: alert.kind.systemImage)
          .font(.subheadline)
          .foregroundStyle(tint)
        if alert.isActive {
          TargetTrack(progress: quote.map { alert.progress(for: $0) } ?? 0, tint: tint)
        } else if let price = alert.triggeredPrice {
          HStack {
            Text("Fired at \(quote?.formatted(price) ?? price.formatted())")
            if let quote {
              Text("· since then")
              ChangeBadge(change: quote.price / price - 1)
            }
          }
          .font(.caption)
          .foregroundStyle(.secondary)
        }
      }
    }
    .padding(.vertical, 4)
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
          Text("Unlimited zones, smart alerts & the full crowd report")
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
