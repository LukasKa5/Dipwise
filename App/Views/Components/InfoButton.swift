import SwiftUI

/// A small "?" that opens a plain-language explanation from Dippy.
struct InfoButton: View {
  var topic: HelpTopic
  @Environment(\.isOnNavyCard) private var isOnNavyCard
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
      HelpSheet(topic: topic, isNavy: isOnNavyCard)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .presentationBackground(isOnNavyCard ? Brand.nightMiddle : Palette.canvas)
    }
  }
}

struct HelpSheet: View {
  var topic: HelpTopic
  /// Navy when opened from a navy card, otherwise the app's normal colors.
  var isNavy = false
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(spacing: 20) {
          VStack(spacing: 12) {
            ZStack {
              Circle()
                .fill(Brand.nightTop)
                .frame(width: 104, height: 104)
              LivelyOwl(mood: .calm)
                .frame(width: 62, height: 72)
                .offset(y: 4)
              Image(systemName: topic.systemImage)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Palette.amber, in: .circle)
                .overlay { Circle().strokeBorder(isNavy ? Brand.nightMiddle : Palette.canvas, lineWidth: 3) }
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
            .fixedSize(horizontal: false, vertical: true)
            .padding(18)
            .background(cardFill, in: .rect(cornerRadius: 20))

          if !topic.alertKinds.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
              ForEach(topic.alertKinds) { kind in
                AlertKindExplanation(kind: kind)
                if kind != topic.alertKinds.last {
                  Divider().padding(.leading, 62)
                }
              }
            }
            .background(cardFill, in: .rect(cornerRadius: 20))
          }

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
                  .fixedSize(horizontal: false, vertical: true)
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
      .tint(Brand.buy)
      .foregroundStyle(Brand.owlInk)
      .padding(.horizontal, 22)
      .padding(.bottom, 16)
    }
    .background((isNavy ? Brand.nightMiddle : Palette.canvas).ignoresSafeArea())
    .environment(\.isOnNavyCard, false)
    .modifier(NavyScheme(isOn: isNavy))
  }

  private var cardFill: AnyShapeStyle {
    isNavy ? AnyShapeStyle(.white.opacity(0.08)) : AnyShapeStyle(Palette.card)
  }
}

/// Forces dark mode only for the navy version, so the normal sheet follows the system.
private struct NavyScheme: ViewModifier {
  var isOn: Bool

  func body(content: Content) -> some View {
    if isOn {
      content.environment(\.colorScheme, .dark)
    } else {
      content
    }
  }
}

/// One alert type with what it watches for, in plain language.
struct AlertKindExplanation: View {
  var kind: AlertKind

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: kind.systemImage)
        .font(.subheadline.weight(.bold))
        .foregroundStyle(kind.side.color)
        .frame(width: 34, height: 34)
        .background(kind.side.color.opacity(0.16), in: .circle)
      VStack(alignment: .leading, spacing: 3) {
        Text(kind.title)
          .font(.subheadline.weight(.semibold))
        Text(kind.explanation)
          .font(.footnote)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
    }
    .padding(14)
    .accessibilityElement(children: .combine)
  }
}
