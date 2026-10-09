import SwiftData
import SwiftUI

/// Create or edit a price alert for one stock.
struct AlertEditorView: View {
  var holding: Holding
  var alert: PriceAlert?

  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Environment(QuoteStore.self) private var quotes
  @Environment(FlockService.self) private var flock
  @Environment(SubscriptionManager.self) private var subscription
  @State private var kind: TargetKind = .buyBelow
  @State private var target: Double?
  @State private var note = ""
  @State private var showsDeleteConfirmation = false
  @State private var showsPaywall = false

  private var quote: Quote? { quotes[holding.symbol] }
  private var stats: FlockStats? { flock.stats[holding.symbol] }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Picker("Alert type", selection: $kind) {
            ForEach(TargetKind.allCases) { Text($0.title).tag($0) }
          }
          .pickerStyle(.segmented)
          .listRowSeparator(.hidden)
          TargetPriceField(price: $target, kind: kind, quote: quote)
        } footer: {
          Text(kind == .buyBelow ? "You'll be notified when the price drops to or below your target." : "You'll be notified when the price rises to or above your target.")
        }

        if let stats, stats.hasEnoughData, let target, target > 0 {
          Section("The Flock") {
            FlockComparisonRow(stats: stats, kind: kind, target: target, isPro: subscription.isPro) {
              showsPaywall = true
            }
          }
        }

        Section {
          TextField("e.g. Strong fundamentals, waiting for a pullback", text: $note, axis: .vertical)
            .lineLimit(2...4)
        } header: {
          Text("Your reason")
        } footer: {
          Text("Dipwise shows this in the notification, so future you remembers the plan.")
        }

        if let alert {
          Section {
            if !alert.isActive {
              Button("Re-arm Alert", systemImage: "arrow.clockwise") { rearm(alert) }
            }
            Button("Delete Alert", systemImage: "trash", role: .destructive) { showsDeleteConfirmation = true }
          }
        }
      }
      .navigationTitle(alert == nil ? "New Alert" : "Edit Alert")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save", action: save)
            .disabled((target ?? 0) <= 0)
        }
      }
      .confirmationDialog("Delete this alert?", isPresented: $showsDeleteConfirmation, titleVisibility: .visible) {
        Button("Delete Alert", role: .destructive) { delete() }
      }
      .sheet(isPresented: $showsPaywall) { PaywallView() }
      .onAppear(perform: load)
      .task {
        if let quote { await flock.load(symbol: holding.symbol, currentPrice: quote.price) }
      }
    }
  }

  private func load() {
    guard let alert else {
      if let quote { target = (quote.price * 0.9 * 100).rounded() / 100 }
      return
    }
    kind = alert.kind
    target = alert.targetPrice
    note = alert.note
  }

  private func save() {
    guard let target, target > 0 else { return }
    let current = quote?.price ?? target
    let edited: PriceAlert
    if let alert {
      let changed = alert.kind != kind || alert.targetPrice != target
      alert.kind = kind
      alert.targetPrice = target
      alert.note = note
      if changed {
        alert.headsUpSentAt = nil
        Task {
          await flock.withdraw(alert)
          await flock.share(alert)
          try? modelContext.save()
        }
      }
      edited = alert
    } else {
      let alert = PriceAlert(kind: kind, targetPrice: target, priceAtCreation: current, note: note)
      alert.holding = holding
      modelContext.insert(alert)
      Task {
        await NotificationManager.requestAuthorization()
        await flock.share(alert)
        try? modelContext.save()
      }
      edited = alert
    }
    if let quote, edited.isActive {
      // If the target is already reached, alert right away.
      let events = AlertEngine.evaluate([edited], quotes: [quote.symbol: quote], headsUpThreshold: nil)
      Task { await NotificationManager.post(events) }
    }
    try? modelContext.save()
    SnapshotPublisher.publish(context: modelContext)
    dismiss()
  }

  private func rearm(_ alert: PriceAlert) {
    guard AlertLimits.canAddAlert(in: modelContext, isPro: subscription.isPro) else {
      showsPaywall = true
      return
    }
    alert.rearm(currentPrice: quote?.price ?? alert.priceAtCreation)
    try? modelContext.save()
    SnapshotPublisher.publish(context: modelContext)
    dismiss()
  }

  private func delete() {
    guard let alert else { return }
    Task { await flock.withdraw(alert) }
    modelContext.delete(alert)
    try? modelContext.save()
    SnapshotPublisher.publish(context: modelContext)
    dismiss()
  }
}

/// Compares the user's target with where the flock has set theirs.
struct FlockComparisonRow: View {
  var stats: FlockStats
  var kind: TargetKind
  var target: Double
  var isPro: Bool
  var upgrade: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let median = kind == .buyBelow ? stats.medianBuy : stats.medianSell {
        LabeledContent("Flock median \(kind.shortTitle.lowercased()) target") {
          Text(median, format: .number.precision(.fractionLength(2)))
            .monospacedDigit()
            .foregroundStyle(Palette.amber)
        }
      }
      if isPro {
        if let patience = stats.patience(of: target, kind: kind) {
          Text("Your target is more patient than \(patience, format: .percent.precision(.fractionLength(0))) of the flock.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      } else {
        Button("See how your target compares with Pro", systemImage: "lock.fill", action: upgrade)
          .font(.subheadline)
      }
    }
  }
}
