import SwiftUI

/// The "night watch" card at the top of Home: portfolio value over a chart with the owl perched in the dip.
struct HeroCard: View {
  var title: String
  var value: String
  var change: Double?
  var changeCaption: String
  var series: [Double]
  var stats: [HeroStat]

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      VStack(alignment: .leading, spacing: 6) {
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

      if series.count > 1 {
        DipChart(values: series)
          .frame(height: 180)
      } else {
        HStack {
          Spacer()
          OwlMark()
            .frame(height: 110)
          Spacer()
        }
        .padding(.vertical, 20)
      }

      HStack(spacing: 10) {
        ForEach(stats) { stat in
          HeroStatTile(stat: stat)
        }
      }
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
