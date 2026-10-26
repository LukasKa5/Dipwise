import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Brings in an existing portfolio from a broker's CSV export, or pasted spreadsheet rows.
struct ImportPortfolioView: View {
  private enum Phase {
    case choose
    case checking(count: Int)
    case review
  }

  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Environment(QuoteStore.self) private var quotes
  @Query private var holdings: [Holding]
  @State private var phase: Phase = .choose
  @State private var positions: [ImportedPosition] = []
  @State private var errorMessage: String?
  @State private var showsFilePicker = false

  private var included: [ImportedPosition] { positions.filter { $0.isIncluded && $0.symbol != nil } }

  var body: some View {
    NavigationStack {
      Group {
        switch phase {
        case .choose: chooser
        case .checking(let count): checking(count)
        case .review: review
        }
      }
      .background(Palette.canvas)
      .navigationTitle("Import Portfolio")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        if case .review = phase {
          ToolbarItem(placement: .confirmationAction) {
            Button("Import", action: importSelected)
              .disabled(included.isEmpty)
          }
        }
      }
      .fileImporter(isPresented: $showsFilePicker, allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, .plainText, .text]) { result in
        switch result {
        case .success(let url): read(url)
        case .failure(let error): errorMessage = error.localizedDescription
        }
      }
    }
  }

  // MARK: Choose

  private var chooser: some View {
    Form {
      Group {
        Section {
          VStack(spacing: 14) {
            Image(systemName: "tray.and.arrow.down.fill")
              .font(.title.weight(.semibold))
              .foregroundStyle(Palette.buy)
              .frame(width: 72, height: 72)
              .background(Brand.nightMiddle, in: .circle)
            Text("Bring your portfolio in seconds")
              .font(.title3.bold())
              .multilineTextAlignment(.center)
            Text("Export your positions or trade history from your broker as a CSV file. Dippy finds the tickers, shares, and average cost for you.")
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
            Button {
              showsFilePicker = true
            } label: {
              Label("Choose CSV File", systemImage: "doc.badge.plus")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            PasteButton(payloadType: String.self) { strings in
              if let text = strings.first { Task { @MainActor in parse(text) } }
            }
            .buttonBorderShape(.capsule)
            if let errorMessage {
              Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(Palette.loss)
                .multilineTextAlignment(.leading)
            }
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 10)
        } footer: {
          Text("The file stays on your iPhone. Dipwise never connects to or trades in your brokerage account.")
        }

        Section("How to export from your broker") {
          ForEach(PortfolioImport.Broker.all) { broker in
            DisclosureGroup(broker.name) {
              Text(broker.steps)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
        }
      }
      .dipwiseRows()
    }
    .dipwiseListStyle()
  }

  private func checking(_ count: Int) -> some View {
    VStack(spacing: 18) {
      LivelyOwl(mood: .calm)
        .frame(width: 80, height: 92)
      ProgressView()
      Text("Checking \(count) \(count == 1 ? "ticker" : "tickers")…")
        .font(.headline)
      Text("Dippy is matching each position with live prices.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: Review

  private var review: some View {
    let found = positions.filter { $0.symbol != nil }
    let missing = positions.filter { $0.symbol == nil }
    return List {
      Group {
        Section {
          ForEach($positions) { $position in
            if position.symbol != nil {
              ImportRow(position: $position, isUpdate: holdings.contains { $0.symbol == position.symbol })
            }
          }
        } header: {
          Text("Found \(found.count) \(found.count == 1 ? "position" : "positions")")
        } footer: {
          Text("Stocks you already watch get their shares and average cost updated. Tap a row to leave it out.")
        }

        if !missing.isEmpty {
          Section {
            ForEach(missing) { position in
              HStack {
                VStack(alignment: .leading, spacing: 2) {
                  Text(position.rawSymbol)
                    .font(.headline)
                  if !position.name.isEmpty {
                    Text(position.name)
                      .font(.caption)
                      .foregroundStyle(.secondary)
                      .lineLimit(1)
                  }
                }
                Spacer()
                Text("Not found")
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(Palette.loss)
              }
            }
          } header: {
            Text("Couldn't match")
          } footer: {
            Text("You can add these later with Add Stock.")
          }
        }
      }
      .dipwiseRows()
    }
    .dipwiseListStyle()
    .safeAreaInset(edge: .bottom) {
      Button(action: importSelected) {
        Text("Import \(included.count) \(included.count == 1 ? "Position" : "Positions")")
          .font(.headline)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 8)
      }
      .buttonStyle(.borderedProminent)
      .disabled(included.isEmpty)
      .padding(.horizontal, 20)
      .padding(.vertical, 10)
      .frame(maxWidth: 560)
      .frame(maxWidth: .infinity)
      .background(Palette.canvas)
    }
  }

  // MARK: Actions

  private func read(_ url: URL) {
    let isScoped = url.startAccessingSecurityScopedResource()
    defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
    guard let data = try? Data(contentsOf: url), let text = PortfolioImport.text(from: data) else {
      errorMessage = "Couldn't read this file. Make sure it's a CSV export."
      return
    }
    parse(text)
  }

  private func parse(_ text: String) {
    errorMessage = nil
    do {
      let parsed = try PortfolioImport.parse(text)
      withAnimation(.smooth) { phase = .checking(count: parsed.count) }
      Task {
        let resolved = await PortfolioImport.resolve(parsed)
        positions = resolved
        withAnimation(.smooth) { phase = .review }
      }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  private func importSelected() {
    let selected = included
    guard !selected.isEmpty else { return }
    for position in selected {
      guard let symbol = position.symbol else { continue }
      if let existing = holdings.first(where: { $0.symbol == symbol }) {
        existing.shares = position.shares
        if position.averageCost > 0 { existing.averageCost = position.averageCost }
      } else {
        modelContext.insert(Holding(symbol: symbol, name: position.name.isEmpty ? symbol : position.name,
                                    shares: position.shares, averageCost: position.averageCost))
      }
    }
    try? modelContext.save()
    SnapshotPublisher.publish(context: modelContext)
    ToastCenter.shared.show("Imported \(selected.count) \(selected.count == 1 ? "position" : "positions")", systemImage: "tray.and.arrow.down.fill")
    let symbols = selected.compactMap(\.symbol)
    Task { await quotes.refresh(symbols: symbols) }
    dismiss()
  }
}

/// One found position, tappable to include or leave out.
private struct ImportRow: View {
  @Binding var position: ImportedPosition
  var isUpdate: Bool

  var body: some View {
    Button {
      withAnimation(.snappy) { position.isIncluded.toggle() }
    } label: {
      HStack(spacing: 12) {
        Image(systemName: position.isIncluded ? "checkmark.circle.fill" : "circle")
          .font(.title3)
          .foregroundStyle(position.isIncluded ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
        TickerBadge(symbol: position.symbol ?? position.rawSymbol, size: 38)
        VStack(alignment: .leading, spacing: 2) {
          HStack(spacing: 6) {
            Text(position.symbol ?? position.rawSymbol)
              .font(.headline)
              .lineLimit(1)
            if isUpdate {
              Text("Update")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Palette.amber)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Palette.amber.opacity(0.15), in: .capsule)
            }
          }
          if !position.name.isEmpty {
            Text(position.name)
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        }
        .layoutPriority(1)
        Spacer(minLength: 8)
        VStack(alignment: .trailing, spacing: 2) {
          Text("\(position.shares.formatted(.number.precision(.fractionLength(0...4)))) sh")
            .font(.subheadline.weight(.semibold).monospacedDigit())
          if position.averageCost > 0 {
            Text("avg \(position.averageCost.formatted(.number.precision(.fractionLength(2))))")
              .font(.caption.monospacedDigit())
              .foregroundStyle(.secondary)
          }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .fixedSize()
      }
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(position.isIncluded ? .isSelected : [])
  }
}
