import SwiftUI

/// The top of Home when the user watches stocks but hasn't added anything they own yet.
struct FirstPositionCard: View {
  var greeting: String
  var stats: [HeroStat]
  var addPosition: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 6) {
          Text(greeting)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.7))
          Text("Add your first stock to your portfolio")
            .font(.title2.bold())
            .fixedSize(horizontal: false, vertical: true)
          Text("Enter the shares you own and Dippy tracks your value, returns, and dividends.")
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.7))
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        LivelyOwl()
          .frame(width: 70, height: 80)
          .padding(.top, 6)
      }

      Button(action: addPosition) {
        Label("Add to Portfolio", systemImage: "plus")
          .font(.headline)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 6)
      }
      .buttonStyle(.borderedProminent)
      .tint(Palette.buy)
      .foregroundStyle(Brand.owlInk)

      HStack(spacing: 10) {
        ForEach(stats) { stat in
          HeroStatTile(stat: stat)
        }
      }
      .fixedSize(horizontal: false, vertical: true)
    }
    .padding(20)
    .heroCardStyle()
  }
}
