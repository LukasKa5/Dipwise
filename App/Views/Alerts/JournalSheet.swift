import SwiftUI

/// Log what you did after an alert fired.
struct JournalSheet: View {
  var alert: PriceAlert
  var quote: Quote?
  @Environment(\.dismiss) private var dismiss
  @Environment(ProgressStore.self) private var progress
  @State private var action: JournalAction?
  @State private var price: Double?

  var body: some View {
    NavigationStack {
      Form {
        Group {
        Section {
          LabeledContent(alert.symbol, value: alert.summary(for: quote))
          if let triggered = alert.triggeredPrice {
            LabeledContent("Fired at", value: quote?.formatted(triggered) ?? triggered.formatted())
          }
        }
        Section("What did you do?") {
          LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(JournalAction.allCases) { option in
              Button {
                withAnimation(.snappy) { action = option }
              } label: {
                Label(option.title, systemImage: option.systemImage)
                  .font(.headline)
                  .frame(maxWidth: .infinity)
                  .padding(.vertical, 14)
                  .background(action == option ? AnyShapeStyle(Palette.buy) : AnyShapeStyle(.quaternary.opacity(0.5)), in: .rect(cornerRadius: 14))
                  .foregroundStyle(action == option ? .white : .primary)
              }
              .buttonStyle(.plain)
              .accessibilityAddTraits(action == option ? .isSelected : [])
            }
          }
          .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
        }
        if action?.needsPrice == true {
          Section {
            TextField("Price", value: $price, format: .number.precision(.fractionLength(2)))
              .keyboardType(.decimalPad)
          } header: {
            Text("At what price?")
          } footer: {
            Text("Dipwise compares this with today's price so you can see how your decisions worked out.")
          }
        }
        }
        .dipwiseRows()
      }
      .dipwiseListStyle()
      .navigationTitle("Dip Journal")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            let isNew = alert.journalAction == nil
            alert.journalAction = action
            alert.journalPrice = action?.needsPrice == true ? (price ?? 0) : 0
            alert.journalDate = .now
            if isNew { progress.record(.journal) }
            dismiss()
          }
          .disabled(action == nil)
        }
      }
      .onAppear {
        action = alert.journalAction
        price = alert.journalPrice > 0 ? alert.journalPrice : alert.triggeredPrice
      }
    }
  }
}
