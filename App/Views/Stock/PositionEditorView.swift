import SwiftData
import SwiftUI

struct PositionEditorView: View {
  var holding: Holding
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      PositionForm(holding: holding, showsCancel: true) { dismiss() }
    }
  }
}

/// Shares and average cost for one stock. Use inside a navigation stack.
struct PositionForm: View {
  @Bindable var holding: Holding
  var showsCancel = false
  var onDone: () -> Void

  @Environment(\.modelContext) private var modelContext
  @State private var shares: Double?
  @State private var averageCost: Double?

  var body: some View {
    Form {
      Group {
        Section {
          HStack(spacing: 12) {
            TickerBadge(symbol: holding.symbol, size: 40)
            VStack(alignment: .leading, spacing: 2) {
              Text(holding.symbol)
                .font(.headline)
              Text(holding.name)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
          }
        }
        Section {
          LabeledContent("Shares") {
            TextField("0", value: $shares, format: .number)
              .keyboardType(.decimalPad)
              .multilineTextAlignment(.trailing)
          }
          LabeledContent("Average cost") {
            TextField("Optional", value: $averageCost, format: .number.precision(.fractionLength(2)))
              .keyboardType(.decimalPad)
              .multilineTextAlignment(.trailing)
          }
        } footer: {
          Text("Set shares to 0 to just watch \(holding.symbol). Dipwise never connects to your broker.")
        }
      }
      .dipwiseRows()
    }
    .dipwiseListStyle()
    .navigationTitle("Position")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if showsCancel {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", action: onDone)
        }
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("Save") {
          holding.shares = max(0, shares ?? 0)
          holding.averageCost = max(0, averageCost ?? 0)
          try? modelContext.save()
          SnapshotPublisher.publish(context: modelContext)
          onDone()
        }
      }
    }
    .onAppear {
      shares = holding.shares > 0 ? holding.shares : nil
      averageCost = holding.averageCost > 0 ? holding.averageCost : nil
    }
  }
}
