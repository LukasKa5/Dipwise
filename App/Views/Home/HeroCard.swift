import SwiftUI

/// The "night watch" card at the top of Home. Scrub the chart to read past values; tap the header for details.
struct HeroCard: View {
  var title: String
  var value: String
  var change: Double?
  var changeCaption: String
  var values: [Double]
  var dates: [Date]
  var stats: [HeroStat]
  var format: (Double) -> String
  @Binding var range: ChartRange
  var openDetails: (() -> Void)?

  @State private var selectedIndex: Int?

  private var selection: (value: Double, date: Date?)? {
    guard let selectedIndex, values.indices.contains(selectedIndex) else { return nil }
    return (values[selectedIndex], dates.indices.contains(selectedIndex) ? dates[selectedIndex] : nil)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      header

      if values.count > 1 {
        InteractiveChart(values: values, dates: dates, selectedIndex: $selectedIndex)
          .frame(height: 190)
      } else {
        HStack {
          Spacer()
          LivelyOwl().frame(height: 110)
          Spacer()
        }
        .padding(.vertical, 20)
      }

      Picker("Range", selection: $range) {
        ForEach(ChartRange.allCases.filter { $0 != .fiveYears }) { Text($0.title).tag($0) }
      }
      .pickerStyle(.segmented)

      HStack(spacing: 10) {
        ForEach(stats) { stat in
          HeroStatTile(stat: stat)
        }
      }
      .contentShape(.rect)
      .onTapGesture { openDetails?() }
    }
    .padding(22)
    .background {
      ZStack {
        Brand.nightGradient
        RadialGradient(colors: [Brand.mint.opacity(0.18), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 320)
      }
    }
    .clipShape(.rect(cornerRadius: 32))
    .overlay {
      RoundedRectangle(cornerRadius: 32)
        .strokeBorder(.white.opacity(0.08))
    }
    .shadow(color: Brand.nightBottom.opacity(0.25), radius: 24, y: 12)
    .environment(\.colorScheme, .dark)
  }

  private var header: some View {
    Button {
      openDetails?()
    } label: {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 6) {
          if let selection {
            Text(selection.date?.formatted(date: .abbreviated, time: .omitted) ?? "")
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(Brand.mint)
            Text(format(selection.value))
              .font(.system(size: 40, weight: .bold, design: .rounded))
              .monospacedDigit()
              .foregroundStyle(.white)
              .minimumScaleFactor(0.6)
              .lineLimit(1)
            if let last = values.last, selection.value > 0 {
              ChangeBadge(change: last / selection.value - 1, caption: "since then", positiveColor: Brand.mint, negativeColor: Brand.loss)
            }
          } else {
            Text(title)
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(.white.opacity(0.65))
            Text(value)
              .font(.system(size: 40, weight: .bold, design: .rounded))
              .monospacedDigit()
              .foregroundStyle(.white)
              .minimumScaleFactor(0.6)
              .lineLimit(1)
              .contentTransition(.numericText())
            if let change {
              ChangeBadge(change: change, caption: changeCaption, positiveColor: Brand.mint, negativeColor: Brand.loss)
            }
          }
        }
        Spacer()
        if openDetails != nil {
          Image(systemName: "chevron.forward")
            .font(.headline)
            .foregroundStyle(.white.opacity(0.5))
            .padding(.top, 4)
            .accessibilityHidden(true)
        }
      }
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .disabled(openDetails == nil)
    .accessibilityHint(openDetails == nil ? "" : "Opens portfolio details")
  }
}

struct HeroStat: Identifiable {
  var value: String
  var label: String
  var systemImage: String
  var tint: Color

  var id: String { label }
}

private struct HeroStatTile: View {
  var stat: HeroStat

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Image(systemName: stat.systemImage)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(stat.tint)
      Text(stat.value)
        .font(.title3.bold())
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .contentTransition(.numericText())
      Text(stat.label)
        .font(.caption.weight(.medium))
        .foregroundStyle(.white.opacity(0.6))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(.white.opacity(0.07), in: .rect(cornerRadius: 18))
    .accessibilityElement(children: .combine)
  }
}
