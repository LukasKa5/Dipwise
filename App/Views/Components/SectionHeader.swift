import SwiftUI

struct SectionHeader<Trailing: View>: View {
  var title: String
  var subtitle: String?
  @ViewBuilder var trailing: Trailing

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.title2.bold())
          .accessibilityAddTraits(.isHeader)
        if let subtitle {
          Text(subtitle)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }
      Spacer()
      trailing
    }
  }
}

extension SectionHeader where Trailing == EmptyView {
  init(title: String, subtitle: String? = nil) {
    self.init(title: title, subtitle: subtitle) { EmptyView() }
  }
}
