import SwiftData
import SwiftUI

struct AlertsView: View {
  @Query(sort: \PriceAlert.createdAt, order: .reverse) private var alerts: [PriceAlert]
  @Environment(QuoteStore.self) private var quotes
  @Environment(SubscriptionManager.self) private var subscription
  @Environment(FlockService.self) private var flock
  @Environment(\.modelContext) private var modelContext
  @State private var showsPaywall = false

  private var active: [PriceAlert] {
    alerts.filter { $0.isActive && $0.holding != nil }.sorted { distance(of: $0) < distance(of: $1) }
  }

  private var reached: [PriceAlert] {
    alerts.filter { !$0.isActive && $0.holding != nil }.sorted { ($0.triggeredAt ?? .distantPast) > ($1.triggeredAt ?? .distantPast) }
  }

  var body: some View {
    NavigationStack {
      List {
        if !subscription.isPro {
          Section {
            FreePlanUsage(used: active.count) { showsPaywall = true }
          }
        }

        Section("Watching") {
          if active.isEmpty {
            Text("No active alerts. Open a stock and tap + to add one.")
              .foregroundStyle(.secondary)
          }
          ForEach(active) { alert in
            NavigationLink(value: alert.symbol) {
              AlertListRow(alert: alert, quote: quotes[alert.symbol])
            }
            .swipeActions {
              Button("Delete", systemImage: "trash", role: .destructive) { delete(alert) }
            }
          }
        }

        if !reached.isEmpty {
          Section("Reached") {
            ForEach(reached) { alert in
              NavigationLink(value: alert.symbol) {
                AlertListRow(alert: alert, quote: quotes[alert.symbol])
              }
              .swipeActions {
                Button("Delete", systemImage: "trash", role: .destructive) { delete(alert) }
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
      .refreshable { await MarketMonitor.refresh(context: modelContext, quotes: quotes) }
      .navigationDestination(for: String.self) { StockDetailView(symbol: $0) }
      .sheet(isPresented: $showsPaywall) { PaywallView() }
      .overlay {
        if alerts.isEmpty {
          ContentUnavailableView("No Alerts Yet", systemImage: "bell.badge", description: Text("Set a buy or sell target on any stock and Dipwise will watch it day and night."))
        }
      }
    }
  }

  private func distance(of alert: PriceAlert) -> Double {
    quotes[alert.symbol].map { alert.distance(from: $0.price) } ?? .infinity
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

  var body: some View {
    HStack(spacing: 14) {
      TickerBadge(symbol: alert.symbol, size: 40)
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text(alert.symbol)
            .font(.headline)
          Spacer()
          if alert.isActive, let quote {
            Text("\(alert.distance(from: quote.price), format: .percent.precision(.fractionLength(1))) away")
              .font(.subheadline.weight(.semibold).monospacedDigit())
              .foregroundStyle(alert.distance(from: quote.price) < 0.035 ? Palette.amber : .secondary)
          } else if let triggeredAt = alert.triggeredAt {
            Text(triggeredAt, format: .relative(presentation: .named))
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        }
        Label("\(alert.kind.title) \(quote?.formatted(alert.targetPrice) ?? alert.targetPrice.formatted())", systemImage: alert.kind.systemImage)
          .font(.subheadline)
          .foregroundStyle(Palette.amber)
        if alert.isActive {
          TargetTrack(progress: quote.map { alert.progress(from: $0.price) } ?? 0)
        } else if let price = alert.triggeredPrice {
          Text("Reached at \(quote?.formatted(price) ?? price.formatted())")
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
          Text("Unlimited alerts, heads-ups & full flock stats")
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
