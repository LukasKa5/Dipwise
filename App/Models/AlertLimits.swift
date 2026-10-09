import Foundation
import SwiftData

enum AlertLimits {
  static func activeAlertCount(in context: ModelContext) -> Int {
    (try? context.fetchCount(FetchDescriptor<PriceAlert>(predicate: #Predicate { $0.isActive }))) ?? 0
  }

  /// Whether the user can add or re-arm another alert on their current plan.
  static func canAddAlert(in context: ModelContext, isPro: Bool) -> Bool {
    isPro || activeAlertCount(in: context) < FreeTier.maxActiveAlerts
  }
}
