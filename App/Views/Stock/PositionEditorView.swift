import SwiftUI

struct PositionEditorView: View {
  @Bindable var holding: Holding
  @Environment(\.dismiss) private var dismiss
  @State private var shares: Double?
  @State private var averageCost: Double?

  var body: some View {
    NavigationStack {
      Form {
        Group {
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
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            holding.shares = max(0, shares ?? 0)
            holding.averageCost = max(0, averageCost ?? 0)
            dismiss()
          }
        }
      }
      .onAppear {
        shares = holding.shares > 0 ? holding.shares : nil
        averageCost = holding.averageCost > 0 ? holding.averageCost : nil
      }
    }
  }
}
