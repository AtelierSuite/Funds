import Foundation
import SwiftData

enum SpendScope: String, Hashable {
    case day, week, month
}

@Model
final class SpendEntry {
    var timestamp: Date = Date.now
    var dayKey: Date = Calendar.current.startOfDay(for: .now)
    var categoryName: String = ""
    var categoryID: String = ""
    var amount: Decimal = 0
    var scopeRaw: String = SpendScope.day.rawValue
    var note: String = ""

    init(dayKey: Date, categoryName: String, categoryID: String = "", amount: Decimal, scope: SpendScope = .day) {
        self.timestamp = .now
        self.dayKey = Calendar.current.startOfDay(for: dayKey)
        self.categoryName = categoryName
        self.categoryID = categoryID
        self.amount = amount
        self.scopeRaw = scope.rawValue
    }

    var scope: SpendScope {
        get { SpendScope(rawValue: scopeRaw) ?? .day }
        set { scopeRaw = newValue.rawValue }
    }
}
