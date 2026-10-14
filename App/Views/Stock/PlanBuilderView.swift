import SwiftData
import SwiftUI

/// Every alert on a stock in one place: one buy zone, one sell zone, and any smart alerts.
/// It's the only alert screen, so adding, changing, and following a suggestion all happen here.
struct PlanBuilderView: View {
  var holding: Holding
  /// An alert to start with already picked, such as a signal from Insights or a zone copied from the crowd.
  var suggestion: AlertRule?
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      PlanBuilderForm(holding: holding, isNewStock: false, suggestion: suggestion) { dismiss() }
    }
  }
}

/// Opens the plan for a stock, optionally with a suggested alert already picked.
struct PlanRequest: Identifiable {
  var holding: Holding
  var suggestion: AlertRule?
  var id: String { "\(holding.symbol)-\(suggestion?.kind.rawValue ?? "plan")" }
}

/// The alerts screen itself. Also the last step of adding a stock, pushed inside that flow.
struct PlanBuilderForm: View {
  var holding: Holding
  /// The stock was just added: the user can skip, and there's no way back to the previous step.
  var isNewStock: Bool
  var suggestion: AlertRule? = nil
  var onFinish: () -> Void

  @Environment(\.modelContext) private var modelContext
  @Environment(QuoteStore.self) private var quotes
  @Environment(FlockService.self) private var flock
  @Environment(SubscriptionManager.self) private var subscription
  @Environment(ProgressStore.self) private var progress
  @State private var draft = PlanDraft()
  @State private var budget: Double?
  @State private var showsPaywall = false
  @State private var didLoad = false

  private var quote: Quote? { quotes[holding.symbol] }
  private func format(_ value: Double) -> String { quote?.formatted(value) ?? value.formatted() }

  private func round(_ value: Double) -> Double {
    let step: Double = value >= 1000 ? 1 : (value >= 10 ? 0.05 : 0.001)
    return (value / step).rounded() * step
  }

  private var rules: [(rule: AlertRule, budget: Double)] {
    guard let quote else { return [] }
    var draft = draft
    draft.budget = budget ?? 0
    return draft.rules(price: quote.price, cost: holding.averageCost)
  }

  /// New alerts this plan adds (zones replace the existing buy or sell plan).
  private var newAlertCount: Int {
    rules.filter { item in
      switch item.rule.kind.side {
      case .buy where item.rule.kind.isZone: holding.buyZone == nil
      case .sell where item.rule.kind.isZone: holding.sellZone == nil
      default: !holding.activeAlerts.contains { $0.kind == item.rule.kind }
      }
    }.count
  }

  private var needsPro: Bool {
    guard !subscription.isPro else { return false }
    return !draft.smart.isEmpty || AlertLimits.activeAlertCount(in: modelContext) + newAlertCount > FreeTier.maxActiveAlerts
  }

  var body: some View {
    Form {
      Group {
        if isNewStock {
          Section {
            HStack(spacing: 14) {
              LivelyOwl(hopsOnTap: true)
                .frame(width: 48, height: 55)
              VStack(alignment: .leading, spacing: 3) {
                Text("Dippy is watching \(holding.symbol)")
                  .font(.headline)
                Text("Now tell him what to look for. Pick a zone, any smart alerts, or skip for now.")
                  .font(.subheadline)
                  .foregroundStyle(.secondary)
                  .fixedSize(horizontal: false, vertical: true)
              }
            }
            .padding(.vertical, 4)
          }
        }

        if let quote {
          Section {
            ZoneTrack(
              price: quote.price,
              bands: rules.filter { $0.rule.kind.isZone }.map { ZoneTrack.Band(range: $0.rule.lower...$0.rule.upper, side: $0.rule.kind.side, isCrowd: false) }
                + [flock.reports[holding.symbol]?.buyZone.map { ZoneTrack.Band(range: $0, side: .buy, isCrowd: true) }].compactMap { $0 },
              low: nil,
              high: nil,
              format: format
            )
            .padding(.vertical, 6)
            ZoneLegend(showsCrowd: flock.reports[holding.symbol]?.buyZone != nil)
          } header: {
            Text("Preview")
          }
        }

        Section {
          Toggle(isOn: $draft.buyZone.animation(.snappy)) {
            Label("Buy zone", systemImage: "arrow.down.to.line.compact")
              .foregroundStyle(Palette.buy)
          }
          if draft.buyZone, let quote {
            ZoneEditorChart(values: quote.recent(64).values, side: .buy, lower: $draft.buyLower, upper: $draft.buyUpper,
                            crowdZone: flock.reports[holding.symbol]?.buyZone, format: format)
              .frame(height: 210)
              .padding(.vertical, 4)
            LabeledContent("Zone", value: "\(format(draft.buyLower)) – \(format(draft.buyUpper))")
              .foregroundStyle(Palette.buy)
            LabeledContent("Budget") {
              TextField("Optional", value: $budget, format: .currency(code: quote.currency))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
            }
          }
        } header: {
          HStack {
            Text("Buy")
            Spacer()
            InfoButton(topic: .zones)
          }
        } footer: {
          Text("Drag the green handles to the range where you'd happily buy.")
        }

        Section {
          Toggle(isOn: $draft.sellZone.animation(.snappy)) {
            Label("Sell zone", systemImage: "arrow.up.to.line.compact")
              .foregroundStyle(Palette.sell)
          }
          if draft.sellZone, let quote {
            ZoneEditorChart(values: quote.recent(64).values, side: .sell, lower: $draft.sellLower, upper: $draft.sellUpper,
                            crowdZone: flock.reports[holding.symbol]?.sellZone, format: format)
              .frame(height: 210)
              .padding(.vertical, 4)
            LabeledContent("Zone", value: "\(format(draft.sellLower)) – \(format(draft.sellUpper))")
              .foregroundStyle(Palette.sell)
          }
        } header: {
          Text("Sell")
        } footer: {
          Text("Drag the red handles to where you'd take profit.")
        }

        ForEach(AlertCategory.allCases.filter { $0 != .zones }) { category in
          let kinds = AlertKind.smart.filter { $0.category == category && (holding.isOwned || !$0.needsCost) }
          Section {
            SmartChips(kinds: kinds, selection: $draft.smart, isPro: subscription.isPro)
              .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
            // What each picked alert does, right where it was picked.
            ForEach(kinds.filter { draft.smart.contains($0) }) { kind in
              SelectedAlertRow(kind: kind) {
                withAnimation(.snappy) { _ = draft.smart.remove(kind) }
              }
            }
          } header: {
            HStack {
              Text(category.title)
              Spacer()
              InfoButton(topic: .category(category))
            }
          }
        }
      }
      .dipwiseRows()
    }
    .dipwiseListStyle()
    .navigationTitle(isNewStock ? "Set Alerts" : "Alerts for \(holding.symbol)")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button(isNewStock ? "Skip" : "Cancel", action: onFinish)
      }
      ToolbarItem(placement: .confirmationAction) {
        Button(needsPro ? "Unlock" : "Save") {
          if needsPro { showsPaywall = true } else { save() }
        }
        .disabled(rules.isEmpty || quote == nil)
      }
    }
    .navigationBarBackButtonHidden(isNewStock)
    .sheet(isPresented: $showsPaywall) { PaywallView() }
    .onAppear {
      guard !didLoad else { return }
      didLoad = true
      draft.smart = Set(holding.smartAlerts.map(\.kind))
      // With no alerts yet, start with a buy zone. Otherwise show exactly what's set.
      let hasAlerts = !holding.activeAlerts.isEmpty
      draft.buyZone = hasAlerts ? holding.buyZone != nil : true
      draft.sellZone = hasAlerts ? holding.sellZone != nil : false
      guard let quote else { return }
      if let zone = holding.buyZone {
        draft.buyLower = zone.targetPrice
        draft.buyUpper = max(zone.upperPrice, zone.targetPrice * 1.01)
        budget = zone.budget > 0 ? zone.budget : nil
      } else {
        draft.buyLower = round(quote.price * 0.90)
        draft.buyUpper = round(quote.price * 0.95)
      }
      if let zone = holding.sellZone {
        draft.sellLower = zone.targetPrice
        draft.sellUpper = max(zone.upperPrice, zone.targetPrice * 1.01)
      } else {
        draft.sellLower = round(quote.price * 1.10)
        draft.sellUpper = round(quote.price * 1.18)
      }
      if let suggestion { apply(suggestion) }
    }
  }

  /// Turns on the suggested alert, keeping everything already planned.
  private func apply(_ rule: AlertRule) {
    switch rule.kind {
    case .buyZone:
      draft.buyZone = true
      draft.buyLower = round(rule.lower)
      draft.buyUpper = round(max(rule.upper, rule.lower * 1.01))
    case .sellZone:
      draft.sellZone = true
      draft.sellLower = round(rule.lower)
      draft.sellUpper = round(max(rule.upper, rule.lower * 1.01))
    default:
      draft.smart.insert(rule.kind)
    }
  }

  private func save() {
    guard let quote else { return }
    for item in rules {
      let existing: PriceAlert? = switch item.rule.kind {
      case .buyZone: holding.buyZone
      case .sellZone: holding.sellZone
      default: holding.activeAlerts.first { $0.kind == item.rule.kind }
      }
      if let existing {
        existing.rule = item.rule
        if item.budget > 0 { existing.budget = item.budget }
        existing.conditionMet = false
        existing.prime(with: quote)
        continue
      }
      let alert = PriceAlert(rule: item.rule, priceAtCreation: quote.price)
      alert.budget = item.budget
      alert.holding = holding
      alert.prime(with: quote)
      modelContext.insert(alert)
      progress.record(.alertCreated)
      Task { await flock.share(alert) }
    }
    // Remove zones the user switched off.
    if !draft.buyZone, let zone = holding.buyZone { modelContext.delete(zone) }
    if !draft.sellZone, let zone = holding.sellZone { modelContext.delete(zone) }
    try? modelContext.save()
    SnapshotPublisher.publish(context: modelContext)
    ToastCenter.shared.show("Dippy is watching \(holding.symbol)", systemImage: "binoculars.fill")
    Task { await NotificationManager.requestAuthorization() }
    onFinish()
  }
}

/// A picked smart alert with what it does, and a quick way to remove it.
private struct SelectedAlertRow: View {
  var kind: AlertKind
  var remove: () -> Void

  var body: some View {
  HStack(alignment: .top, spacing: 12) {
    Image(systemName: kind.systemImage)
      .font(.footnote.weight(.bold))
      .foregroundStyle(kind.side.color)
      .frame(width: 30, height: 30)
      .background(kind.side.color.opacity(0.14), in: .circle)
    VStack(alignment: .leading, spacing: 2) {
      Text(kind.title)
        .font(.subheadline.weight(.semibold))
      Text(kind.explanation)
        .font(.footnote)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
    Spacer(minLength: 0)
    Button("Remove \(kind.title)", systemImage: "xmark.circle.fill", action: remove)
      .labelStyle(.iconOnly)
      .font(.title3)
      .foregroundStyle(.tertiary)
      .buttonStyle(.plain)
  }
  .padding(.vertical, 2)
  .transition(.opacity.combined(with: .move(edge: .top)))
  }
}

/// Toggleable chips for picking several smart alerts at once.
struct SmartChips: View {
  var kinds: [AlertKind]
  @Binding var selection: Set<AlertKind>
  var isPro: Bool

  var body: some View {
  FlowLayout(spacing: 8) {
    ForEach(kinds) { kind in
      let isOn = selection.contains(kind)
      Button {
        withAnimation(.snappy) {
          if isOn { selection.remove(kind) } else { selection.insert(kind) }
        }
      } label: {
        HStack(spacing: 6) {
          Image(systemName: kind.systemImage)
          Text(kind.title)
          if kind.requiresPro && !isPro {
            Image(systemName: "lock.fill").font(.caption2)
          }
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .foregroundStyle(isOn ? .white : kind.side.color)
        .background(isOn ? AnyShapeStyle(kind.side.color) : AnyShapeStyle(kind.side.color.opacity(0.12)), in: .capsule)
      }
      .buttonStyle(.plain)
      .accessibilityAddTraits(isOn ? .isSelected : [])
      .accessibilityHint(kind.explanation)
    }
  }
  .sensoryFeedback(.selection, trigger: selection)
  }
}

/// Lays out views in rows, wrapping to the next line when they don't fit.
struct FlowLayout: Layout {
  var spacing: CGFloat = 8

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let width = proposal.width ?? .infinity
    var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if x + size.width > width, x > 0 {
        x = 0
        y += rowHeight + spacing
        rowHeight = 0
      }
      x += size.width + spacing
      maxX = max(maxX, x - spacing)
      rowHeight = max(rowHeight, size.height)
    }
    return CGSize(width: min(maxX, width), height: y + rowHeight)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if x + size.width > bounds.maxX, x > bounds.minX {
        x = bounds.minX
        y += rowHeight + spacing
        rowHeight = 0
      }
      subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
      x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
    }
  }
}
