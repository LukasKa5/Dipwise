import SwiftUI

/// A stock's alerts. A few are listed as they are; many are folded into categories,
/// so a stock with 20+ alerts stays short and easy to scroll. Swipe a row to delete it.
struct FoldedAlertList<Row: View>: View {
  /// Sorted closest to triggering first.
  var alerts: [PriceAlert]
  var quote: Quote?
  var dividerInset: CGFloat = 64
  var delete: (PriceAlert) -> Void
  @ViewBuilder var row: (PriceAlert) -> Row

  @State private var expanded: Set<AlertCategory>?

  /// Up to this many alerts are shown without folding.
  static var unfoldedLimit: Int { 4 }

  private var groups: [(category: AlertCategory, alerts: [PriceAlert])] {
    let grouped = Dictionary(grouping: alerts, by: \.kind.category)
    return AlertCategory.allCases.compactMap { category in
      grouped[category].map { (category, $0) }
    }
  }

  /// Every group starts folded, so a long plan reads as a short summary first.
  private var defaultExpanded: Set<AlertCategory> { [] }

  var body: some View {
    if alerts.count <= Self.unfoldedLimit {
      rows(alerts)
    } else {
      ForEach(groups, id: \.category) { group in
        let isOpen = (expanded ?? defaultExpanded).contains(group.category)
        header(group.category, alerts: group.alerts, isOpen: isOpen)
        if isOpen {
          rows(group.alerts)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
        if group.category != groups.last?.category {
          Divider().padding(.leading, 16)
        }
      }
    }
  }

  private func rows(_ list: [PriceAlert]) -> some View {
    ForEach(list) { alert in
      row(alert)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
          Button("Delete", systemImage: "trash", role: .destructive) { delete(alert) }
        }
      if alert.id != list.last?.id {
        Divider().padding(.leading, dividerInset)
      }
    }
  }

  private func header(_ category: AlertCategory, alerts list: [PriceAlert], isOpen: Bool) -> some View {
    let nearest = quote.flatMap { quote in list.compactMap { $0.distance(for: quote) }.min() }
    return Button {
      withAnimation(.snappy) {
        var open = expanded ?? defaultExpanded
        if isOpen { open.remove(category) } else { open.insert(category) }
        expanded = open
      }
    } label: {
      HStack(spacing: 12) {
        Image(systemName: category.systemImage)
          .font(.subheadline.weight(.bold))
          .foregroundStyle(.tint)
          .frame(width: 36, height: 36)
          .background(.tint.opacity(0.12), in: .circle)
        VStack(alignment: .leading, spacing: 2) {
          Text(category.title)
            .font(.subheadline.weight(.semibold))
          Text("\(list.count) \(list.count == 1 ? "alert" : "alerts")")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer(minLength: 8)
        if let nearest {
          Text(nearest == 0 ? "Active now" : "Closest \(nearest.formatted(.percent.precision(.fractionLength(1))))")
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(nearest == 0 ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            .lineLimit(1)
            .fixedSize()
        }
        Image(systemName: "chevron.down")
          .font(.caption.weight(.bold))
          .foregroundStyle(.tertiary)
          .rotationEffect(.degrees(isOpen ? 0 : -90))
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(category.title), \(list.count) alerts")
    .accessibilityHint(isOpen ? "Collapses the group" : "Expands the group")
    .sensoryFeedback(.selection, trigger: isOpen)
  }
}

extension AlertCategory {
  var systemImage: String {
    switch self {
    case .zones: "arrow.up.and.down"
    case .moves: "bolt.fill"
    case .trend: "chart.line.uptrend.xyaxis"
    case .momentum: "gauge.with.dots.needle.67percent"
    case .position: "shield.lefthalf.filled"
    case .income: "leaf.fill"
    case .crowd: "person.3.fill"
    }
  }
}

extension View {
  /// Lets rows in a scroll view use swipe actions, like in a list. On older systems, rows keep their context menus.
  @ViewBuilder
  func swipeActionsContainerIfAvailable() -> some View {
    if #available(iOS 27.0, *) {
      swipeActionsContainer()
    } else {
      self
    }
  }
}
