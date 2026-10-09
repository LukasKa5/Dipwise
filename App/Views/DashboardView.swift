import SwiftUI

struct DashboardView: View {
  var portfolio: Portfolio

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 28) {
          PortfolioSummaryCard(portfolio: portfolio)

          VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Near Your Targets", systemImage: "scope")
            ForEach(portfolio.nearestTargets) { holding in
              HoldingTargetRow(holding: holding)
            }
          }

          VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "From the Flock", systemImage: "person.3.fill")
            ForEach(portfolio.insights) { insight in
              CrowdInsightCard(insight: insight)
            }
          }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
      }
      .background(Palette.canvas)
      .navigationTitle("Dipwise")
    }
    .fontDesign(.rounded)
  }
}

private struct SectionHeader: View {
  var title: String
  var systemImage: String

  var body: some View {
    Label(title, systemImage: systemImage)
      .font(.title3.bold())
      .labelStyle(SectionLabelStyle())
      .accessibilityAddTraits(.isHeader)
  }
}

private struct SectionLabelStyle: LabelStyle {
  func makeBody(configuration: Configuration) -> some View {
    HStack(spacing: 8) {
      configuration.icon
        .foregroundStyle(.tint)
      configuration.title
    }
  }
}
