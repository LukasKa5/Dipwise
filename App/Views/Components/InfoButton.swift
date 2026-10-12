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
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
    }
  }
}

struct HelpSheet: View {
  var topic: HelpTopic
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(spacing: 20) {
          VStack(spacing: 12) {
            ZStack {
              Circle()
                .fill(Brand.nightMiddle)
                .frame(width: 104, height: 104)
              LivelyOwl(mood: .calm)
                .frame(width: 62, height: 72)
                .offset(y: 4)
              Image(systemName: topic.systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Palette.amber, in: .circle)
                .overlay { Circle().strokeBorder(Palette.canvas, lineWidth: 3) }
                .offset(x: 38, y: 36)
            }
            Text("Dippy explains")
              .font(.caption.weight(.bold))
              .textCase(.uppercase)
              .foregroundStyle(Palette.amber)
            Text(topic.title)
              .font(.title2.bold())
              .multilineTextAlignment(.center)
          }
          .padding(.top, 28)

          Text(topic.body)
            .font(.body)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .cardStyle(cornerRadius: 20)

          if let example = topic.example {
            HStack(alignment: .top, spacing: 12) {
              Image(systemName: "lightbulb.fill")
                .foregroundStyle(Palette.amber)
              VStack(alignment: .leading, spacing: 4) {
                Text("For example")
                  .font(.caption.weight(.bold))
                  .foregroundStyle(.secondary)
                Text(example)
                  .font(.callout)
              }
              Spacer(minLength: 0)
            }
            .padding(16)
            .background(Palette.amber.opacity(0.12), in: .rect(cornerRadius: 18))
          }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 20)
      }
      Button {
        dismiss()
      } label: {
        Text("Got it")
          .font(.headline)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 6)
      }
      .buttonStyle(.borderedProminent)
      .padding(.horizontal, 22)
      .padding(.bottom, 16)
    }
    .background(Palette.canvas)
  }
}
