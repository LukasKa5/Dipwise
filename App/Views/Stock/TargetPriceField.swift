import SwiftUI

/// Price entry with quick percentage chips relative to the current price.
struct TargetPriceField: View {
  @Binding var price: Double?
  var kind: TargetKind
  var quote: Quote?

  private var offsets: [Double] {
    kind == .buyBelow ? [-0.03, -0.05, -0.10, -0.15, -0.20] : [0.03, 0.05, 0.10, 0.15, 0.25]
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Target price")
        Spacer()
        TextField("Price", value: $price, format: .number.precision(.fractionLength(2)))
          .keyboardType(.decimalPad)
          .multilineTextAlignment(.trailing)
          .font(.title3.bold().monospacedDigit())
          .foregroundStyle(Palette.amber)
          .frame(maxWidth: 160)
      }
      if let quote {
        ScrollView(.horizontal) {
          HStack(spacing: 8) {
            ForEach(offsets, id: \.self) { offset in
              Button {
                price = (quote.price * (1 + offset) * 100).rounded() / 100
              } label: {
                Text(offset, format: .percent.precision(.fractionLength(0)).sign(strategy: .always()))
                  .font(.subheadline.weight(.semibold).monospacedDigit())
                  .padding(.horizontal, 12)
                  .padding(.vertical, 6)
                  .background(Palette.amber.opacity(0.14), in: .capsule)
                  .foregroundStyle(Palette.amber)
              }
              .buttonStyle(.plain)
              .accessibilityLabel("\(offset.formatted(.percent.precision(.fractionLength(0))).replacingOccurrences(of: "-", with: "")) \(kind == .buyBelow ? "below" : "above") current price")
            }
          }
        }
        .scrollIndicators(.hidden)
        if let price, price > 0 {
          let offset = price / quote.price - 1
          Text("\(abs(offset), format: .percent.precision(.fractionLength(1))) \(offset < 0 ? "below" : "above") today's \(quote.formatted(quote.price))")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }
    }
  }
}
