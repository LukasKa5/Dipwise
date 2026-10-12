import Foundation

/// Plain-language explanations behind the "?" buttons.
enum HelpTopic: Identifiable, Hashable {
  case zones
  case crowdZone
  case medianAverage
  case odds
  case conviction
  case planHealth
  case signals
  case trackRecord
  case dipJournal
  case streak
  case buyingPower
  case dividends
  case allocation
  case radar
  case flock
  case category(AlertCategory)
  case alert(AlertKind)

  var id: String {
    switch self {
    case .category(let category): "category-\(category.rawValue)"
    case .alert(let kind): "alert-\(kind.rawValue)"
    default: String(describing: self)
    }
  }

  var title: String {
    switch self {
    case .zones: "Buy and sell zones"
    case .crowdZone: "The crowd zone"
    case .medianAverage: "Median vs. average"
    case .odds: "Alert odds"
    case .conviction: "Crowd conviction"
    case .planHealth: "Plan health"
    case .signals: "Signals right now"
    case .trackRecord: "Track record"
    case .dipJournal: "Dip Journal"
    case .streak: "Streaks and XP"
    case .buyingPower: "Buying power"
    case .dividends: "Dividend income"
    case .allocation: "Allocation"
    case .radar: "Dip Radar"
    case .flock: "The flock"
    case .category(let category): category.title
    case .alert(let kind): kind.title
    }
  }

  var systemImage: String {
    switch self {
    case .zones: "arrow.up.and.down"
    case .crowdZone, .conviction, .radar, .flock: "person.3.fill"
    case .medianAverage: "equal.circle"
    case .odds: "dice.fill"
    case .planHealth: "heart.text.square.fill"
    case .signals: "dot.radiowaves.left.and.right"
    case .trackRecord: "checkmark.seal.fill"
    case .dipJournal: "book.closed.fill"
    case .streak: "flame.fill"
    case .buyingPower: "banknote.fill"
    case .dividends: "leaf.fill"
    case .allocation: "chart.pie.fill"
    case .category: "sparkles"
    case .alert(let kind): kind.systemImage
    }
  }

  var body: String {
    switch self {
    case .zones:
      "A buy zone (green) is the price range where you'd happily buy more. A sell zone (red) is where you'd take profit. Zones work better than single prices because nobody catches the exact bottom or top. Each stock has one buy zone and one sell zone, and you can add smart alerts on top."
    case .crowdZone:
      "The orange crowd zone is where most Dipwise investors placed their own alerts on this stock. It's the middle half of everyone's targets, so it ignores extreme guesses. Prices often react around levels many people are watching."
    case .medianAverage:
      "The median is the middle target: half of investors chose a higher price, half a lower one. The average adds every target and divides by the count, so a few extreme guesses can pull it up or down. When the two are close, the crowd agrees. When they're far apart, a few investors have very different views."
    case .odds:
      "Odds estimate how likely an alert is to fire within 30 or 90 days. Dippy looks at how much this stock has moved day to day over the past year and asks: how often would a move this big happen? They're estimates from past behavior, not predictions."
    case .conviction:
      "Crowd conviction is a 0–100 score combining three things: how many alerts are buy-side, whether interest is growing this week, and how many alerts sit close to today's price. High means the crowd is eager to buy; low means it's leaning toward selling."
    case .planHealth:
      "Plan health checks whether each of your stocks has a buy zone, a sell zone, and some protection like a stop loss or trailing stop. A score near 100 means you know what you'll do in any market."
    case .signals:
      "Signals are what the technical indicators say about your stocks today, even if you haven't set an alert. For example, an RSI below 30 often means a stock has been sold heavily. Tap a signal to turn it into an alert."
    case .trackRecord:
      "When an alert fires, Dippy remembers the price. Later, it compares that price with today's, so you can see whether your buy alerts led to gains and whether your sell alerts saved you from drops."
    case .dipJournal:
      "When an alert fires, note what you did: bought, sold, held, or skipped. Over time the journal shows how your real decisions worked out. It's the fastest way to learn your own habits."
    case .streak:
      "Doing the one-minute Daily Brief keeps your streak alive and earns XP. Setting alerts, voting, and journaling earn XP too. Levels and achievements celebrate steady, calm habits."
    case .buyingPower:
      "Buying power compares the cash you keep ready with the budgets on your buy zones. If your zones need more than you have, you'll know before the dip arrives."
    case .dividends:
      "Expected income is based on what each stock paid over the last twelve months, times your shares. Yield on cost compares that income with what you originally paid."
    case .allocation:
      "Allocation shows how your money is spread across stocks, asset types, and currencies. If one position is a large share of the total, a bad day for it is a bad day for you."
    case .flock:
      "The flock is every Dipwise investor. When someone sets an alert, its price level is shared anonymously (never names, holdings, or notes). Dippy combines thousands of them to show where the crowd plans to buy (green) and sell (red), how strong its conviction is, and how past dip-buys worked out. Vote each week to add your view."
    case .radar:
      "Dip Radar lists popular stocks that are trading inside, or just above, the range where most Dipwise investors plan to buy."
    case .category(let category):
      switch category {
      case .zones: "Your buy and sell plan for a stock."
      case .moves: "Alerts for unusual price moves: sharp drops, big daily swings, opening gaps, and fresh 52-week highs or lows."
      case .trend: "Alerts based on moving averages, which smooth out daily noise to show the bigger trend. Crossovers often mark a change in direction."
      case .momentum: "Alerts based on momentum indicators like RSI, MACD, and Bollinger Bands, which help spot when a move may be overdone."
      case .position: "Alerts based on what you paid: protect yourself with a stop loss, lock in gains with a profit target, or know when you're back to even."
      case .income: "Alerts about dividends, so you know when a payout is coming."
      }
    case .alert(let kind):
      kind.explanation
    }
  }

  /// The alerts a category covers, each explained in the help sheet.
  var alertKinds: [AlertKind] {
    guard case .category(let category) = self, category != .zones else { return [] }
    return AlertKind.allCases.filter { $0.category == category }
  }

  var example: String? {
    switch self {
    case .zones: "NVDA is $182. Buy zone $165–175, sell zone $210–225."
    case .medianAverage: "Targets $90, $95, $96, $98, $150: median $96, average $106."
    case .odds: "A stock that often moves 3% a day is far more likely to drop 10% within a month than one that moves 1%."
    case .alert(.rsiOversold): "RSI ranges from 0 to 100. Below 30 is usually called oversold."
    case .alert(.goldenCross): "When the 50-day average rises above the 200-day, many investors see a new uptrend."
    case .alert(.trailingStop): "Set 8% while a stock is $100. It rises to $150, so the stop moves up to $138."
    case .alert(.bollingerLow): "Price usually stays inside its bands. A touch of the lower band often comes before a bounce."
    default: nil
    }
  }
}
