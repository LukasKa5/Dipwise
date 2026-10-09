import Foundation
import SwiftData

@Model
final class PriceAlert {
  var id: UUID = UUID()
  var kindRaw: String = TargetKind.buyBelow.rawValue
  var targetPrice: Double = 0
  var priceAtCreation: Double = 0
  var note: String = ""
  var createdAt: Date = Date.now
  var isActive: Bool = true
  var triggeredAt: Date?
  var triggeredPrice: Double?
  var headsUpSentAt: Date?
  /// The anonymous flock record mirroring this alert, when shared.
  var flockRecordName: String?
  var holding: Holding?

  init(kind: TargetKind, targetPrice: Double, priceAtCreation: Double, note: String = "") {
    self.kindRaw = kind.rawValue
    self.targetPrice = targetPrice
    self.priceAtCreation = priceAtCreation
    self.note = note
  }

  var kind: TargetKind {
    get { TargetKind(rawValue: kindRaw) ?? .buyBelow }
    set { kindRaw = newValue.rawValue }
  }

  var symbol: String { holding?.symbol ?? "" }

  func distance(from price: Double) -> Double {
    kind.distance(from: price, to: targetPrice)
  }

  func progress(from price: Double) -> Double {
    kind.progress(from: price, to: targetPrice)
  }

  /// Re-arms a triggered alert so it watches again.
  func rearm(currentPrice: Double) {
    isActive = true
    triggeredAt = nil
    triggeredPrice = nil
    headsUpSentAt = nil
    priceAtCreation = currentPrice
  }

  var watchedTarget: WatchedTarget {
    WatchedTarget(id: id, symbol: symbol, name: holding?.name ?? symbol, kind: kind, target: targetPrice)
  }
}
