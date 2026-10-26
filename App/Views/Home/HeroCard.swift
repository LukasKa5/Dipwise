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
  @Binding var period: ChartPeriod
  var earliest: Date
  var openDetails: (() -> Void)?
  var mood: OwlMood = .calm
  var status: DippyStatus?

  @State private var selectedIndex: Int?

  private var isIntraday: Bool {
    guard let first = dates.first, let last = dates.last else { return false }
    return last.timeIntervalSince(first) < 2 * 86_400
  }

  private var selection: (value: Double, date: Date?)? {
    guard let selectedIndex, values.indices.contains(selectedIndex) else { return nil }
    return (values[selectedIndex], dates.indices.contains(selectedIndex) ? dates[selectedIndex] : nil)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      header

      if values.count > 1 {
        InteractiveChart(values: values, dates: dates, owlMood: mood, selectedIndex: $selectedIndex)
          .frame(height: 190)
      } else {
        HStack {
          Spacer()
          LivelyOwl().frame(height: 110)
          Spacer()
        }
        .padding(.vertical, 20)
      }

      if let status {
        Button {
          if status.canWake { OwlWake.shared.wake() }
        } label: {
          Label(status.text, systemImage: status.systemImage)
            .font(.footnote.weight(.semibold))
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentTransition(.opacity)
        }
        .buttonStyle(.plain)
        .disabled(!status.canWake)
        .accessibilityHint(status.canWake ? "Wakes Dippy" : "")
        .animation(.smooth, value: status)
      }

      PeriodPicker(period: $period, presets: [.day, .week, .month, .threeMonths, .year], earliest: earliest)

      HStack(spacing: 10) {
        ForEach(stats) { stat in
          HeroStatTile(stat: stat)
        }
      }
      .fixedSize(horizontal: false, vertical: true)
      .contentShape(.rect)
      .onTapGesture { openDetails?() }
    }
    .padding(20)
    .heroCardStyle()
  }

  private var header: some View {
    Button {
      openDetails?()
    } label: {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 6) {
          if let selection {
            Text(selection.date.map { isIntraday ? $0.formatted(date: .omitted, time: .shortened) : $0.formatted(date: .abbreviated, time: .omitted) } ?? "")
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(.tint)
            Text(format(selection.value))
              .font(.system(size: 40, weight: .bold, design: .rounded))
              .monospacedDigit()
              .minimumScaleFactor(0.5)
              .lineLimit(1)
            if let last = values.last, selection.value > 0 {
              ChangeBadge(change: last / selection.value - 1, caption: "since then", positiveColor: Palette.gain, negativeColor: Palette.loss)
            }
          } else {
            Text(title)
              .font(.subheadline.weight(.semibold))
            Text(value)
              .font(.system(size: 40, weight: .bold, design: .rounded))
              .monospacedDigit()
              .minimumScaleFactor(0.5)
              .lineLimit(1)
              .contentTransition(.numericText())
            if let change {
              ChangeBadge(change: change, caption: changeCaption, positiveColor: Palette.gain, negativeColor: Palette.loss)
            }
          }
        }
        Spacer()
        if openDetails != nil {
          Image(systemName: "chevron.forward")
            .font(.headline)
            .foregroundStyle(.tertiary)
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

struct HeroStatTile: View {
  var stat: HeroStat

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Image(systemName: stat.systemImage)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(stat.tint)
        .frame(height: 20)
      Text(stat.value)
        .font(.title3.bold())
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .contentTransition(.numericText())
      Text(LocalizedStringKey(stat.label))
        .font(.caption.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
    .frame(maxWidth: .infinity, minHeight: 74, maxHeight: .infinity, alignment: .topLeading)
    .padding(14)
    .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 16))
    .accessibilityElement(children: .combine)
  }
}
