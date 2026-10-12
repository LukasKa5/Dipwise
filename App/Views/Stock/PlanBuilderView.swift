import SwiftData
import SwiftUI

/// Set up a stock's whole plan at once: one buy zone, one sell zone, and any smart alerts.
struct PlanBuilderView: View {
  var holding: Holding

  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Environment(QuoteStore.self) private var quotes
  @Environment(FlockService.self) private var flock
  @Environment(SubscriptionManager.self) private var subscription
  @Environment(ProgressStore.self) private var progress
  @State private var draft = PlanDraft()
  @State private var template: PlanTemplate?
  @State private var budget: Double?
  @State private var showsPaywall = false

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
    return draft.rules(price: quote.price, cost: holding.averageCost, round: round)
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
    NavigationStack {
      Form {
        Group {
          Section {
            templates
          } header: {
            Text("Start from a template")
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
            if draft.buyZone {
              Picker("How deep", selection: $draft.depth) {
                ForEach(PlanDraft.Depth.allCases) { Text($0.title).tag($0) }
              }
              .pickerStyle(.segmented)
              LabeledContent("Budget") {
                TextField("Optional", value: $budget, format: .currency(code: quote?.currency ?? "USD"))
                  .keyboardType(.decimalPad)
                  .multilineTextAlignment(.trailing)
              }
            }
            Toggle(isOn: $draft.sellZone.animation(.snappy)) {
              Label("Sell zone", systemImage: "arrow.up.to.line.compact")
                .foregroundStyle(Palette.sell)
            }
            if draft.sellZone {
              Picker("Target", selection: $draft.sellTarget) {
                ForEach(PlanDraft.SellTarget.allCases) { Text($0.title).tag($0) }
              }
              .pickerStyle(.segmented)
            }
          } header: {
            Text("Buy & sell")
          } footer: {
            Text(holding.buyZone != nil || holding.sellZone != nil ? "This replaces \(holding.symbol)'s current buy and sell zones." : "One buy zone and one sell zone keep the plan simple.")
          }

          ForEach(AlertCategory.allCases.filter { $0 != .zones }) { category in
            Section {
              SmartChips(kinds: AlertKind.smart.filter { $0.category == category && (holding.isOwned || !$0.needsCost) }, selection: $draft.smart, isPro: subscription.isPro)
                .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
            } header: {
              Text(category.title)
            }
          }
        }
        .dipwiseRows()
      }
      .dipwiseListStyle()
      .navigationTitle("Plan \(holding.symbol)")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button(needsPro ? "Unlock" : "Save Plan") {
            if needsPro { showsPaywall = true } else { save() }
          }
          .disabled(rules.isEmpty || quote == nil)
        }
      }
      .onChange(of: draft) { if template.map(PlanDraft.init(template:)) != draft { template = nil } }
      .sheet(isPresented: $showsPaywall) { PaywallView() }
      .onAppear {
        draft.smart = Set(holding.smartAlerts.map(\.kind))
      }
    }
  }

  private var templates: some View {
    ScrollView(.horizontal) {
      HStack(spacing: 10) {
        ForEach(PlanTemplate.allCases) { item in
          Button {
            withAnimation(.snappy) {
              template = item
              draft = PlanDraft(template: item)
            }
          } label: {
            VStack(alignment: .leading, spacing: 6) {
              Image(systemName: item.systemImage)
                .font(.title3)
              Text(item.title)
                .font(.subheadline.weight(.bold))
              Text(item.subtitle)
                .font(.caption)
                .foregroundStyle(template == item ? .white.opacity(0.85) : .secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            }
            .foregroundStyle(template == item ? .white : .primary)
            .frame(width: 140, height: 104, alignment: .topLeading)
            .padding(12)
            .background(template == item ? AnyShapeStyle(Brand.nightMiddle) : AnyShapeStyle(Palette.canvas), in: .rect(cornerRadius: 16))
          }
          .buttonStyle(.plain)
          .accessibilityAddTraits(template == item ? .isSelected : [])
        }
      }
      .padding(.horizontal, 4)
    }
    .scrollIndicators(.hidden)
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
    dismiss()
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
