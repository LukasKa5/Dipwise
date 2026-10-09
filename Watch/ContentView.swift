import SwiftUI

struct ContentView: View {
  @Environment(WatchTargetStore.self) private var store

  var body: some View {
    NavigationStack {
      List {
        if store.targets.isEmpty {
          VStack(spacing: 10) {
            OwlMark()
              .frame(height: 60)
            Text("Add price targets in Dipwise on your iPhone.")
              .font(.footnote)
              .multilineTextAlignment(.center)
              .foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity)
          .listRowBackground(Color.clear)
        } else {
          ForEach(store.statuses) { status in
            TargetRow(status: status)
          }
        }
      }
      .navigationTitle("Dipwise")
      .refreshable { await store.refresh() }
    }
    .tint(Brand.mint)
  }
}

private struct TargetRow: View {
  var status: TargetStatus

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(status.target.symbol)
          .font(.headline)
        Spacer()
        if let distance = status.distance {
          Text(distance == 0 ? "Reached" : distance.formatted(.percent.precision(.fractionLength(1))))
            .font(.headline.monospacedDigit())
            .foregroundStyle(distance < 0.035 ? Brand.amber : .primary)
        }
      }
      Gauge(value: status.progress) { EmptyView() }
        .gaugeStyle(.accessoryLinearCapacity)
        .tint(Brand.amber)
      Text("\(status.target.kind.title) \(status.quote?.formatted(status.target.target) ?? status.target.target.formatted())")
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 4)
    .accessibilityElement(children: .combine)
  }
}
