import SwiftUI

/// Preset ranges plus a custom date span.
struct PeriodPicker: View {
  @Binding var period: ChartPeriod
  var presets: [ChartRange] = ChartRange.allCases
  /// The earliest date the user may pick for a custom range.
  var earliest: Date

  @State private var showsCustom = false

  var body: some View {
    HStack(spacing: 4) {
      ForEach(presets) { range in
        let isSelected = period == .preset(range)
        Button(range.title) {
          withAnimation(.snappy) { period = .preset(range) }
        }
        .font(.subheadline.weight(.semibold))
        .frame(maxWidth: .infinity, minHeight: 32)
        .background(isSelected ? AnyShapeStyle(.white.opacity(0.18)) : AnyShapeStyle(.clear), in: .capsule)
        .foregroundStyle(.primary)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
      }
      Button {
        showsCustom = true
      } label: {
        Label(period.isCustom ? period.title : "Custom", systemImage: "calendar")
          .labelStyle(period.isCustom ? AnyLabelStyle(.titleOnly) : AnyLabelStyle(.iconOnly))
          .font(.subheadline.weight(.semibold))
          .lineLimit(1)
          .minimumScaleFactor(0.6)
          .frame(maxWidth: period.isCustom ? 140 : .infinity, minHeight: 32)
          .padding(.horizontal, period.isCustom ? 8 : 0)
          .background(period.isCustom ? AnyShapeStyle(.white.opacity(0.18)) : AnyShapeStyle(.clear), in: .capsule)
          .foregroundStyle(.primary)
      }
      .accessibilityLabel(period.isCustom ? "Custom range, \(period.title)" : "Custom range")
    }
    .buttonStyle(.plain)
    .padding(3)
    .background(.quaternary.opacity(0.5), in: .capsule)
    .sensoryFeedback(.selection, trigger: period)
    .sheet(isPresented: $showsCustom) {
      CustomPeriodSheet(period: $period, earliest: earliest)
        .presentationDetents([.medium, .large])
        .presentationBackground(Brand.nightMiddle)
    }
  }
}

private struct AnyLabelStyle: LabelStyle {
  private let make: (Configuration) -> AnyView

  init<S: LabelStyle>(_ style: S) {
    make = { AnyView(style.makeBody(configuration: $0)) }
  }

  func makeBody(configuration: Configuration) -> some View {
    make(configuration)
  }
}

private struct CustomPeriodSheet: View {
  @Binding var period: ChartPeriod
  var earliest: Date
  @Environment(\.dismiss) private var dismiss
  @State private var start = Calendar.current.date(byAdding: .month, value: -6, to: .now) ?? .now
  @State private var end = Date.now

  var body: some View {
    NavigationStack {
      Form {
        Group {
          Section {
            DatePicker("From", selection: $start, in: earliest...end, displayedComponents: .date)
            DatePicker("To", selection: $end, in: start...Date.now, displayedComponents: .date)
          } footer: {
            Text("Pick any period to see how prices moved.")
          }
          Section("Quick picks") {
            quickPick("Year to date", start: Calendar.current.date(from: Calendar.current.dateComponents([.year], from: .now)) ?? .now)
            quickPick("Last 5 years", start: Calendar.current.date(byAdding: .year, value: -5, to: .now) ?? .now)
          }
        }
        .listRowBackground(Color.white.opacity(0.08))
      }
      .scrollContentBackground(.hidden)
      .background(Brand.nightMiddle)
      .navigationTitle("Custom Range")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Show") {
            period = .custom(min(start, end)...max(start, end))
            dismiss()
          }
        }
      }
      .toolbarBackground(Brand.nightMiddle, for: .navigationBar)
      .environment(\.colorScheme, .dark)
      .tint(Brand.buy)
      .onAppear {
        if case .custom(let span) = period {
          start = span.lowerBound
          end = span.upperBound
        }
        start = max(start, earliest)
      }
    }
  }

  private func quickPick(_ title: String, start date: Date) -> some View {
    Button {
      period = .custom(max(date, earliest)...Date.now)
      dismiss()
    } label: {
      Text(title)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }
  }
}
