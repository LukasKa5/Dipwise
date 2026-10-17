import SwiftUI

struct SectionHeader<Trailing: View>: View {
  var title: LocalizedStringKey
  var subtitle: LocalizedStringKey?
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
  init(title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil) {
    self.init(title: title, subtitle: subtitle) { EmptyView() }
  }
}
