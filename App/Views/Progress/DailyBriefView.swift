import SwiftData
import SwiftUI

/// A one-minute morning routine, ready before the US open: how your stocks did in the last session, your closest plans, how you feel about the market (shared
/// anonymously with the flock, which answers back with everyone's mood), a flock question, a lesson, and your streak.
struct DailyBriefView: View {
  @Query(sort: \Holding.addedAt) private var holdings: [Holding]
  @Environment(\.dismiss) private var dismiss
  @Environment(QuoteStore.self) private var quotes
  @Environment(FlockService.self) private var flock
  @Environment(ProgressStore.self) private var progress
  @State private var step = 0
  @State private var celebration = 0
  @State private var vote: Bool?
  @State private var didRecord = false
  @State private var feeling: FlockFeeling?
  @State private var action: FlockAction?
  @State private var didCheckIn = false

  private enum Step {
    case movers, plans, mood, question, lesson, finish
  }

  /// The mood check-in appears once the flock is live, since its answer is the flock's own mood.
  private var stepList: [Step] {
    flock.isAvailable ? [.movers, .plans, .mood, .question, .lesson, .finish] : [.movers, .plans, .question, .lesson, .finish]
  }

  private var steps: Int { stepList.count }
  private var current: Step { stepList[min(step, stepList.count - 1)] }

  private var summary: PortfolioSummary {
    PortfolioSummary(holdings: holdings, quotes: quotes.quotes, baseCurrency: quotes.baseCurrency, convert: quotes.toBase)
  }

  private var voteSymbol: String {
    holdings.first?.symbol ?? flock.overview.trending.first?.symbol ?? "AAPL"
  }

  var body: some View {
    VStack(spacing: 0) {
      header
      ScrollView {
        Group {
          switch current {
          case .movers: movers
          case .plans: plans
          case .mood: mood
          case .question: question
          case .lesson: lesson
          case .finish: finish
          }
        }
        .id(step)
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
        .padding(20)
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
      }
      Button(action: next) {
        Text(step == steps - 1 ? "Done" : "Continue")
          .font(.headline)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 8)
      }
      .buttonStyle(.borderedProminent)
      .disabled((current == .question && vote == nil) || (current == .mood && !didCheckIn))
      .padding(20)
      .frame(maxWidth: 600)
    }
    .background(Palette.canvas)
    .overlay { Confetti(trigger: celebration) }
    .sensoryFeedback(.success, trigger: celebration)
    .sensoryFeedback(.selection, trigger: step)
  }

  // MARK: Header

  private var header: some View {
    HStack(spacing: 14) {
      Button("Close", systemImage: "xmark") { dismiss() }
        .labelStyle(.iconOnly)
        .font(.title3)
        .foregroundStyle(.secondary)
      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          Capsule().fill(.quaternary)
          Capsule().fill(Palette.buy)
            .frame(width: geometry.size.width * Double(step + 1) / Double(steps))
        }
      }
      .frame(height: 14)
      .animation(.snappy, value: step)
      .accessibilityElement()
      .accessibilityLabel("Step \(step + 1) of \(steps)")
      StreakChip(streak: progress.streak, isDoneToday: progress.isBriefDoneToday)
    }
    .padding(.horizontal, 20)
    .padding(.top, 20)
    .padding(.bottom, 8)
  }

  /// Before the open (or on a weekend) the brief recaps the last session; once the market is open, it's today's moves.
  static var sessionLine: String {
    let greeting = DayPeriod(date: .now).greeting
    switch MarketClock.phase() {
    case .open, .afterHours: return String(localized: "\(greeting)! Here's how your stocks are moving today.")
    default: return String(localized: "\(greeting)! Here's how your stocks closed in the last session.")
    }
  }

  // MARK: Steps

  private var movers: some View {
    VStack(alignment: .leading, spacing: 18) {
      OwlSays(text: LocalizedStringKey(Self.sessionLine))
      let movers = holdings.compactMap { holding in quotes[holding.symbol].map { (holding, $0) } }
        .sorted { abs($0.1.change) > abs($1.1.change) }
        .prefix(5)
      if movers.isEmpty {
        EmptyHint(systemImage: "binoculars", text: "Add a few stocks and the owl will report on them every day.")
      } else {
        if summary.hasPositions {
          HStack {
            Text("Your portfolio")
              .font(.headline)
            Spacer()
            ChangeBadge(change: summary.dayChange, caption: quotes.formatBase(summary.dayChangeAmount))
          }
          .padding(16)
          .cardStyle(cornerRadius: 20)
        }
        VStack(spacing: 0) {
          ForEach(Array(movers), id: \.0.id) { holding, quote in
            HStack(spacing: 12) {
              TickerBadge(symbol: holding.symbol, size: 38)
              VStack(alignment: .leading, spacing: 2) {
                Text(holding.symbol).font(.headline)
                Text(quote.formatted(quote.price))
                  .lineLimit(1)
                  .minimumScaleFactor(0.5)
                  .font(.subheadline.monospacedDigit())
                  .foregroundStyle(.secondary)
              }
              Spacer()
              ChangeBadge(change: quote.change)
                .font(.headline)
            }
            .padding(14)
            .accessibilityElement(children: .combine)
          }
        }
        .cardStyle()
      }
    }
  }

  private var plans: some View {
    VStack(alignment: .leading, spacing: 18) {
      let nearest = Array(summary.nearestAlerts.prefix(3))
      if let first = nearest.first, let quote = quotes[first.symbol], let distance = first.distance(for: quote) {
        OwlSays(text: distance == 0
                ? "\(first.symbol) is in your \(first.kind.title.lowercased()) right now. Time to check your plan."
                : "\(first.symbol) is \(distance.formatted(.percent.precision(.fractionLength(1)))) from your \(first.kind.title.lowercased()).")
        ForEach(nearest) { alert in
          AlertCard(alert: alert, quote: quotes[alert.symbol])
        }
      } else {
        OwlSays(text: "No plans yet. Set a buy zone on a stock and I'll track how close it gets every day.")
      }
    }
  }

  private var mood: some View {
    VStack(alignment: .leading, spacing: 18) {
      OwlSays(text: didCheckIn ? "Here's where the whole flock sees the market heading." : "Where do you see the market heading this week?")
      if !didCheckIn {
        HStack(spacing: 8) {
          ForEach(FlockFeeling.allCases) { option in
            Button {
              withAnimation(.snappy) { feeling = option }
            } label: {
              VStack(spacing: 6) {
                Image(systemName: option.systemImage)
                  .font(.title2)
                  .foregroundStyle(option.tint)
                  .frame(height: 30)
                Text(option.title)
                  .font(.caption.weight(.semibold))
                  .lineLimit(1)
                  .minimumScaleFactor(0.6)
              }
              .frame(maxWidth: .infinity)
              .padding(.vertical, 12)
              .background(feeling == option ? AnyShapeStyle(Palette.green.opacity(0.18)) : AnyShapeStyle(Palette.card), in: .rect(cornerRadius: 16))
              .overlay {
                RoundedRectangle(cornerRadius: 16).strokeBorder(feeling == option ? Palette.green : .clear, lineWidth: 2)
              }
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(feeling == option ? .isSelected : [])
          }
        }
        .sensoryFeedback(.selection, trigger: feeling)
        if feeling != nil {
          Text("And what are you doing this week?")
            .font(.headline)
            .transition(.opacity)
          FlowLayout(spacing: 8) {
            ForEach(FlockAction.allCases) { option in
              Button {
                action = option
                guard let feeling else { return }
                Task {
                  await flock.checkIn(feeling: feeling, action: option)
                  withAnimation(.smooth) { didCheckIn = true }
                }
              } label: {
                Label(option.title, systemImage: option.systemImage)
                  .font(.subheadline.weight(.semibold))
                  .padding(.horizontal, 14)
                  .padding(.vertical, 10)
                  .background(action == option ? AnyShapeStyle(Palette.green) : AnyShapeStyle(Palette.card), in: .capsule)
                  .foregroundStyle(action == option ? AnyShapeStyle(.white) : AnyShapeStyle(option.tint))
              }
              .buttonStyle(.plain)
            }
          }
          .transition(.opacity)
        }
        Label("Anonymous. Only your answer counts, never who you are.", systemImage: "lock.fill")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else if let sentiment = flock.sentiment {
        FlockSentimentCard(sentiment: sentiment, mine: flock.myCheckIn)
          .transition(.scale(scale: 0.95).combined(with: .opacity))
      }
    }
    .task {
      if let mine = flock.myCheckIn {
        feeling = mine.feeling
        action = mine.action
        didCheckIn = true
        await flock.loadSentiment()
      }
    }
  }

  private var question: some View {
    VStack(alignment: .leading, spacing: 18) {
      OwlSays(text: "Question of the day. What do you think?")
      VoteCard(symbol: voteSymbol, votes: flock.reports[voteSymbol]?.votes ?? FlockVotes(bullish: 0, bearish: 0), userVote: vote ?? flock.userVote(for: voteSymbol)) { bullish in
        let isFirst = vote == nil
        vote = bullish
        Task { await flock.vote(symbol: voteSymbol, bullish: bullish) }
        if isFirst { progress.record(.vote) }
      }
    }
    .task {
      vote = flock.userVote(for: voteSymbol)
      if let price = quotes[voteSymbol]?.price { await flock.load(symbol: voteSymbol, currentPrice: price) }
    }
  }

  private var lesson: some View {
    let tip = OwlTip.today
    return VStack(alignment: .leading, spacing: 18) {
      OwlSays(text: "Today's owl wisdom")
      VStack(alignment: .leading, spacing: 10) {
        Label(tip.title, systemImage: "lightbulb.fill")
          .font(.title3.bold())
          .foregroundStyle(Palette.amber)
        Text(tip.body)
          .font(.body)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(20)
      .frame(maxWidth: .infinity, alignment: .leading)
      .cardStyle()
    }
  }

  private var finish: some View {
    VStack(spacing: 22) {
      ZStack {
        Image(systemName: "flame.fill")
          .font(.system(size: 120))
          .foregroundStyle(Palette.amber.gradient)
          .symbolEffect(.bounce, value: celebration)
        Text("\(progress.streak)")
          .font(.system(size: 44, weight: .heavy, design: .rounded))
          .foregroundStyle(.white)
          .offset(y: 18)
          .contentTransition(.numericText())
      }
      .padding(.top, 20)
      VStack(spacing: 6) {
        Text(progress.streak == 1 ? "Streak started!" : "\(progress.streak)-day streak!")
          .font(.largeTitle.bold())
        Text("Come back tomorrow to keep it going.")
          .foregroundStyle(.secondary)
      }
      XPToast(points: ProgressStore.Event.brief.points)
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("Level \(progress.level) · \(progress.levelTitle)")
            .font(.headline)
          Spacer()
          Text("\(progress.pointsToNextLevel) XP to go")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        ProgressView(value: progress.levelProgress)
          .tint(Palette.amber)
      }
      .padding(18)
      .cardStyle()
    }
    .frame(maxWidth: .infinity)
  }

  private func next() {
    if step < steps - 1 {
      withAnimation(.smooth) { step += 1 }
      if step == steps - 1, !didRecord {
        didRecord = true
        if !progress.isBriefDoneToday {
          progress.record(.brief)
        }
        celebration += 1
      }
    } else {
      dismiss()
    }
  }
}

/// The owl with a speech bubble, used to narrate.
struct OwlSays: View {
  var text: LocalizedStringKey

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      LivelyOwl()
        .frame(width: 52, height: 60)
      Text(text)
        .font(.headline)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.card, in: .rect(cornerRadius: 18))
        .overlay {
          RoundedRectangle(cornerRadius: 18).strokeBorder(.quaternary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}
