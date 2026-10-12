import Foundation

/// The S&P 500, used by alerts that compare a stock with the market.
enum Benchmark {
  static let symbol = "^GSPC"
  nonisolated(unsafe) static var quote: Quote? = TargetSnapshotStore.loadQuotes()[symbol]
}
