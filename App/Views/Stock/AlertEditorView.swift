import SwiftData
import SwiftUI

/// Create or edit any kind of alert for one stock: zones, price levels, or smart alerts.
struct AlertEditorView: View {
  var holding: Holding
  var alert: PriceAlert?
  var initialRule: AlertRule?

  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Environment(QuoteStore.self) private var quotes
  @Environment(FlockService.self) private var flock
  @Environment(SubscriptionManager.self) private var subscription
  @Environment(ProgressStore.self) private var progress
  @State private var kind: AlertKind = .buyZone
  @State private var lower: Double = 0
  @State private var upper: Double = 0
  @State private var percent: Double = 0.1
  @State private var averageDays = 200
  @State private var budget: Double?
  @State private var repeats = false
  @State private var expiry: Expiry = .never
  @State private var note = ""
  @State private var didLoad = false
  @State private var showsDeleteConfirmation = false
  @State private var showsPaywall = false

  private var quote: Quote? { quotes[holding.symbol] }
  private var report: FlockReport? { flock.reports[holding.symbol] }
  private func format(_ value: Double) -> String { quote?.formatted(value) ?? value.formatted(.number.precision(.fractionLength(2))) }

  private var rule: AlertRule {
    AlertRule(kind: kind, lower: lower, upper: kind.isZone ? upper : 0, percent: kind.usesPercent ? percent : 0,
              averageDays: averageDays, peak: alert?.peakPrice ?? quote?.price ?? 0)
  }

  private var isLocked: Bool { kind.requiresPro && !subscription.isPro }
  private var isValid: Bool {
    switch kind {
    case .buyZone, .sellZone: lower > 0 && upper > lower
    case .priceBelow, .priceAbove: lower > 0
    case .dropFromHigh, .dailyMove, .trailingStop: percent > 0
    case .belowAverage: true
    }
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          AlertKindPicker(selection: $kind, isPro: subscription.isPro)
            .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
            .listRowBackground(Color.clear)
        } footer: {
          Text(kind.explanation)
        }

        conditionSection

        if kind.side == .buy {
          Section {
            LabeledContent("Budget") {
              TextField("Optional", value: $budget, format: .currency(code: quote?.currency ?? "USD"))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
            }
            if let budget, budget > 0, let price = rule.referencePrice ?? quote?.price, price > 0 {
              LabeledContent("You'd get about", value: "\((budget / price).formatted(.number.precision(.fractionLength(0...2)))) shares")
            }
          } header: {
            Text("Your plan")
          } footer: {
            Text("Dipwise reminds you of this plan when the alert fires, and counts it toward your buying power.")
          }
        }

        if let report, report.hasEnoughData, kind.side != .watch {
          Section("The Flock") {
            FlockComparisonRow(report: report, rule: rule, isPro: subscription.isPro, format: format) {
              showsPaywall = true
            }
          }
        }

        Section {
          Toggle("Repeat", isOn: $repeats)
          Picker("Expires", selection: $expiry) {
            ForEach((alert?.expiresAt != nil ? [Expiry.custom] : []) + Expiry.allCases) { Text($0.title).tag($0) }
          }
          TextField("Why? e.g. Strong earnings, waiting for a pullback", text: $note, axis: .vertical)
            .lineLimit(2...4)
        } header: {
          Text("Options")
        } footer: {
          Text(repeats ? "You'll be alerted every time the condition is newly met." : "The alert turns off after it fires. You can re-arm it any time.")
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
          Button(isLocked ? "Unlock" : "Save") {
            if isLocked { showsPaywall = true } else { save() }
          }
          .disabled(!isValid)
        }
      }
      .confirmationDialog("Delete this alert?", isPresented: $showsDeleteConfirmation, titleVisibility: .visible) {
        Button("Delete Alert", role: .destructive) { delete() }
      }
      .sheet(isPresented: $showsPaywall) { PaywallView() }
      .onAppear(perform: load)
      .onChange(of: kind) { oldKind, newKind in
        if oldKind.side != newKind.side || oldKind.isZone != newKind.isZone { suggestLevels() }
        if newKind.usesPercent { percent = defaultPercent(for: newKind) }
      }
      .task {
        if let quote { await flock.load(symbol: holding.symbol, currentPrice: quote.price) }
      }
    }
  }

  // MARK: Condition

  @ViewBuilder
  private var conditionSection: some View {
    if let quote {
      switch kind {
      case .buyZone, .sellZone, .priceBelow, .priceAbove:
        Section {
          ZoneEditorChart(
            values: quote.recent(64).values,
            side: kind.side,
            lower: $lower,
            upper: kind.isZone ? $upper : nil,
            crowdZone: kind.side == .buy ? report?.buyZone : report?.sellZone,
            format: format
          )
          .frame(height: 230)
          .padding(.vertical, 6)

          if kind.isZone {
            LabeledContent("From") { priceField($lower) }
            LabeledContent("To") { priceField($upper) }
          } else {
            LabeledContent("Price") { priceField($lower) }
          }
          presets(for: quote)
        } header: {
          Text("Drag to set your \(kind.isZone ? "zone" : "level")")
        } footer: {
          Text(levelDescription(for: quote))
        }

      case .dropFromHigh, .dailyMove, .trailingStop:
        Section {
          VStack(alignment: .leading, spacing: 12) {
            HStack {
              Text(kind == .dailyMove ? "Move size" : "Drop")
              Spacer()
              Text(percent, format: .percent.precision(.fractionLength(0)))
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(kind.side.color)
            }
            Slider(value: $percent, in: percentRange) {
              Text("Percentage")
            } minimumValueLabel: {
              Text(percentRange.lowerBound, format: .percent.precision(.fractionLength(0)))
            } maximumValueLabel: {
              Text(percentRange.upperBound, format: .percent.precision(.fractionLength(0)))
            }
          }
        } footer: {
          Text(percentDescription(for: quote))
        }

      case .belowAverage:
        Section {
          Picker("Average", selection: $averageDays) {
            Text("50-day").tag(50)
            Text("100-day").tag(100)
            Text("200-day").tag(200)
          }
          .pickerStyle(.segmented)
        } footer: {
          if let average = quote.movingAverage(days: averageDays) {
            Text("The \(averageDays)-day average is \(format(average)). Today's price is \(abs(quote.price / average - 1).formatted(.percent.precision(.fractionLength(1)))) \(quote.price >= average ? "above" : "below") it.")
          } else {
            Text("Not enough price history for this average yet.")
          }
        }
      }
    } else {
      Section { ProgressView("Loading price…") }
    }
  }

  private func priceField(_ value: Binding<Double>) -> some View {
    TextField("Price", value: value, format: .number.precision(.fractionLength(2)))
      .keyboardType(.decimalPad)
      .multilineTextAlignment(.trailing)
      .font(.body.weight(.semibold).monospacedDigit())
      .foregroundStyle(kind.side.color)
  }

  private func presets(for quote: Quote) -> some View {
    ScrollView(.horizontal) {
      HStack(spacing: 8) {
        ForEach(presetOptions(for: quote), id: \.title) { preset in
          Button(preset.title) {
            withAnimation(.snappy) {
              lower = preset.lower
              if kind.isZone { upper = preset.upper }
            }
          }
          .font(.subheadline.weight(.semibold))
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background((kind.side.color).opacity(0.14), in: .capsule)
          .foregroundStyle(kind.side.color)
          .buttonStyle(.plain)
        }
      }
    }
    .scrollIndicators(.hidden)
  }

  private func presetOptions(for quote: Quote) -> [(title: String, lower: Double, upper: Double)] {
    let price = quote.price
    var options: [(String, Double, Double)]
    if kind.side == .buy {
      options = [("−3 to −6%", price * 0.94, price * 0.97), ("−5 to −10%", price * 0.90, price * 0.95), ("−10 to −15%", price * 0.85, price * 0.90)]
      options.append(("Near 52-week low", quote.low52, quote.low52 * 1.04))
      if let zone = report?.buyZone { options.insert(("Crowd zone", zone.lowerBound, zone.upperBound), at: 0) }
    } else {
      options = [("+5 to +10%", price * 1.05, price * 1.10), ("+10 to +20%", price * 1.10, price * 1.20)]
      options.append(("Near 52-week high", quote.high52 * 0.97, quote.high52))
      if let zone = report?.sellZone { options.insert(("Crowd zone", zone.lowerBound, zone.upperBound), at: 0) }
    }
    if !kind.isZone {
      options = options.map { ($0.0, kind.side == .buy ? $0.2 : $0.1, 0) }
    }
    return options.map { (title: $0.0, lower: rounded($0.1), upper: rounded($0.2)) }
  }

  private func levelDescription(for quote: Quote) -> String {
    let level = kind == .buyZone ? upper : lower
    guard level > 0 else { return "" }
    let offset = level / quote.price - 1
    let distance = "\(abs(offset).formatted(.percent.precision(.fractionLength(1)))) \(offset < 0 ? "below" : "above") today's \(format(quote.price))"
    if kind.isZone {
      return "You'll be alerted when the price enters the zone, \(distance)."
    }
    return "Triggers \(distance)."
  }

  private var percentRange: ClosedRange<Double> {
    switch kind {
    case .dailyMove: 0.02...0.15
    case .trailingStop: 0.03...0.30
    default: 0.05...0.50
    }
  }

  private func percentDescription(for quote: Quote) -> String {
    switch kind {
    case .dropFromHigh:
      let level = quote.high52 * (1 - percent)
      return "52-week high is \(format(quote.high52)), so this triggers at \(format(level)). Today the stock is \(abs(quote.drawdownFromHigh).formatted(.percent.precision(.fractionLength(1)))) below its high."
    case .trailingStop:
      let peak = max(alert?.peakPrice ?? 0, quote.price)
      return "Tracks the highest price from now on. Right now it would trigger at \(format(peak * (1 - percent)))."
    case .dailyMove:
      return "Fires when \(holding.symbol) rises or falls \(percent.formatted(.percent.precision(.fractionLength(0)))) or more in a single day."
    default:
      return ""
    }
  }

  // MARK: Actions

  private func defaultPercent(for kind: AlertKind) -> Double {
    switch kind {
    case .dailyMove: 0.05
    case .trailingStop: 0.08
    default: 0.2
    }
  }

  private func rounded(_ value: Double) -> Double {
    let step: Double = value >= 1000 ? 1 : (value >= 10 ? 0.05 : 0.001)
    return (value / step).rounded() * step
  }

  private func suggestLevels() {
    guard let quote else { return }
    let price = quote.price
    switch kind.side {
    case .buy:
      lower = rounded(price * (kind.isZone ? 0.90 : 0.92))
      upper = rounded(price * 0.95)
    case .sell:
      lower = rounded(price * 1.10)
      upper = rounded(price * 1.18)
    case .watch:
      break
    }
  }

  private func load() {
    guard !didLoad else { return }
    didLoad = true
    if let alert {
      let rule = alert.rule
      kind = rule.kind
      lower = rule.lower
      upper = rule.upper
      percent = rule.percent > 0 ? rule.percent : defaultPercent(for: rule.kind)
      averageDays = rule.averageDays
      budget = alert.budget > 0 ? alert.budget : nil
      repeats = alert.repeats
      expiry = alert.expiresAt == nil ? .never : .custom
      note = alert.note
    } else if let initialRule {
      kind = initialRule.kind
      percent = initialRule.percent > 0 ? initialRule.percent : defaultPercent(for: initialRule.kind)
      if initialRule.lower > 0 {
        lower = rounded(initialRule.lower)
        upper = rounded(initialRule.upper)
      } else {
        suggestLevels()
      }
    } else {
      suggestLevels()
    }
  }

  private func save() {
    guard isValid else { return }
    let current = quote?.price ?? lower
    let target: PriceAlert
    if let alert {
      let changed = alert.rule != rule
      alert.rule = rule
      if changed {
        alert.conditionMet = false
        alert.headsUpSentAt = nil
        Task {
          await flock.withdraw(alert)
          await flock.share(alert)
          try? modelContext.save()
        }
      }
      target = alert
    } else {
      let alert = PriceAlert(rule: rule, priceAtCreation: current)
      alert.holding = holding
      modelContext.insert(alert)
      progress.record(.alertCreated)
      Task {
        await NotificationManager.requestAuthorization()
        await flock.share(alert)
        try? modelContext.save()
      }
      target = alert
    }
    target.budget = max(0, budget ?? 0)
    target.repeats = repeats
    target.note = note
    if let date = expiry.date(from: .now) { target.expiresAt = date } else if expiry == .never { target.expiresAt = nil }

    if let quote, target.isActive {
      // If the condition is already met, alert right away.
      let events = AlertEngine.evaluate([target], quotes: [quote.symbol: quote], headsUpThreshold: nil)
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

enum Expiry: String, CaseIterable, Identifiable {
  case never
  case week
  case month
  case quarter
  case custom

  var id: Self { self }

  static var allCases: [Expiry] { [.never, .week, .month, .quarter] }

  var title: String {
    switch self {
    case .never: "Never"
    case .week: "In 1 week"
    case .month: "In 1 month"
    case .quarter: "In 3 months"
    case .custom: "Keep current"
    }
  }

  func date(from start: Date) -> Date? {
    let calendar = Calendar.current
    switch self {
    case .never, .custom: return nil
    case .week: return calendar.date(byAdding: .day, value: 7, to: start)
    case .month: return calendar.date(byAdding: .month, value: 1, to: start)
    case .quarter: return calendar.date(byAdding: .month, value: 3, to: start)
    }
  }
}

/// A horizontally scrolling picker of alert types, with Pro types marked.
struct AlertKindPicker: View {
  @Binding var selection: AlertKind
  var isPro: Bool

  var body: some View {
    ScrollView(.horizontal) {
      HStack(spacing: 10) {
        ForEach(AlertKind.allCases) { kind in
          let isSelected = kind == selection
          let tint: Color = kind.side.color
          Button {
            withAnimation(.snappy) { selection = kind }
          } label: {
            VStack(alignment: .leading, spacing: 8) {
              HStack {
                Image(systemName: kind.systemImage)
                  .font(.headline)
                  .foregroundStyle(isSelected ? Brand.owlInk : tint)
                Spacer()
                if kind.requiresPro && !isPro {
                  Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(isSelected ? Brand.owlInk : .secondary)
                }
              }
              Text(kind.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Brand.owlInk : .primary)
                .lineLimit(1)
            }
            .frame(width: 112, alignment: .leading)
            .padding(12)
            .background(isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(Palette.card), in: .rect(cornerRadius: 16))
            .overlay {
              RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.quaternary, lineWidth: isSelected ? 0 : 1)
            }
          }
          .buttonStyle(.plain)
          .accessibilityAddTraits(isSelected ? .isSelected : [])
          .accessibilityHint(kind.requiresPro && !isPro ? "Dipwise Pro" : "")
        }
      }
      .padding(.horizontal, 20)
    }
    .scrollIndicators(.hidden)
  }
}

/// Compares the user's level with where the flock has set theirs.
struct FlockComparisonRow: View {
  var report: FlockReport
  var rule: AlertRule
  var isPro: Bool
  var format: (Double) -> String
  var upgrade: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      let side = rule.kind.side
      if let zone = side == .buy ? report.buyZone : report.sellZone {
        LabeledContent("Crowd \(side == .buy ? "buy" : "sell") zone") {
          Text("\(format(zone.lowerBound))–\(format(zone.upperBound))")
            .monospacedDigit()
            .foregroundStyle(side.color)
        }
      }
      if isPro {
        if let level = rule.referencePrice, let patience = report.patience(of: level, side: side) {
          Text("Your level is more patient than \(patience, format: .percent.precision(.fractionLength(0))) of investors on this side.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      } else {
        Button("Compare your level with the crowd", systemImage: "lock.fill", action: upgrade)
          .font(.subheadline)
      }
    }
  }
}
