import SwiftUI

struct ProBadge: View {
  var body: some View {
    Text("PRO")
      .font(.caption2.weight(.heavy))
      .foregroundStyle(Brand.owlInk)
      .padding(.horizontal, 7)
      .padding(.vertical, 3)
      .background(Brand.amber, in: .capsule)
      .accessibilityLabel("Dipwise Pro")
  }
}
