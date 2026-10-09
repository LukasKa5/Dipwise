import SwiftUI

struct DashboardView: View {
  var portfolio: Portfolio
  @Binding var appearance: AppearanceMode

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 32) {
          HeroCard(portfolio: portfolio)

          VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Near Your Targets", subtitle: "Sorted by how close each stock is")
            ForEach(portfolio.nearestTargets) { holding in
              HoldingTargetRow(holding: holding)
            }
          }

          VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "From the Flock", subtitle: "What other Dipwise investors are planning")
            ScrollView(.horizontal) {
              HStack(spacing: 14) {
                ForEach(portfolio.insights) { insight in
                  CrowdInsightCard(insight: insight)
                }
              }
              .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
          }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 40)
        .frame(maxWidth: 680)
        .frame(maxWidth: .infinity)
      }
      .background(Palette.canvas)
      .navigationTitle("Dipwise")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Menu {
            Picker("Appearance", selection: $appearance) {
              ForEach(AppearanceMode.allCases) { mode in
                Label(mode.title, systemImage: mode.systemImage)
                  .tag(mode)
              }
            }
          } label: {
            Label("Appearance", systemImage: appearance.systemImage)
          }
        }
      }
    }
    .fontDesign(.rounded)
  }
}

private struct SectionHeader: View {
  var title: String
  var subtitle: String

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
        .font(.title2.bold())
        .accessibilityAddTraits(.isHeader)
      Text(subtitle)
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
  }
}
