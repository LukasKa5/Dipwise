import SwiftUI

/// A small "?" that opens a plain-language explanation from Dippy.
struct InfoButton: View {
  var topic: HelpTopic
  @State private var isPresented = false

  var body: some View {
    Button {
      isPresented = true
    } label: {
      Image(systemName: "questionmark.circle.fill")
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .frame(minWidth: 28, minHeight: 28)
        .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("What is \(topic.title)?")
    .sheet(isPresented: $isPresented) {
      HelpSheet(topic: topic)
        .presentationDetents([.medium, .large])
    }
  }
}

struct HelpSheet: View {
  var topic: HelpTopic
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        HStack(alignment: .bottom, spacing: 12) {
          LivelyOwl(mood: .calm)
            .frame(width: 60, height: 68)
          VStack(alignment: .leading, spacing: 4) {
            Label("Dippy explains", systemImage: topic.systemImage)
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(Palette.amber)
            Text(topic.title)
              .font(.title2.bold())
          }
        }
        Text(topic.body)
          .font(.body)
          .fixedSize(horizontal: false, vertical: true)
        if let example = topic.example {
          VStack(alignment: .leading, spacing: 6) {
            Text("Example")
              .font(.caption.weight(.bold))
              .foregroundStyle(.secondary)
            Text(example)
              .font(.callout)
          }
          .padding(16)
          .frame(maxWidth: .infinity, alignment: .leading)
          .cardStyle(cornerRadius: 18)
        }
        Button("Got it") { dismiss() }
          .buttonStyle(.borderedProminent)
          .frame(maxWidth: .infinity)
          .padding(.top, 6)
      }
      .padding(24)
    }
    .background(Palette.canvas)
  }
}
