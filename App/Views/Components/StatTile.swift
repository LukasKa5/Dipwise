import SwiftUI

struct StatTile: View {
  var title: LocalizedStringKey
  var value: String
  var systemImage: String
  var tint: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Image(systemName: systemImage)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(tint)
      Text(value)
        .font(.title3.bold())
        .monospacedDigit()
        .fitsNumber()
      // Two lines reserved for every label, so every tile in a grid is exactly the same size.
      Text(title)
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .lineLimit(2, reservesSpace: true)
        .minimumScaleFactor(0.8)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .cardStyle(cornerRadius: 20)
    .accessibilityElement(children: .combine)
  }
}
