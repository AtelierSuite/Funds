import Foundation
import SwiftData

@Model
final class BudgetTemplate {
    var uuid: String = UUID().uuidString
    var name: String = ""
    var iconName: String = AppSymbol.budgetTemplate
    var createdAt: Date = Date.now
    @Relationship(deleteRule: .cascade, inverse: \TemplateCategory.template)
    var categories: [TemplateCategory]? = []
    @Relationship(deleteRule: .cascade, inverse: \DayOverride.template)
    var overrides: [DayOverride]? = []

    init(name: String, iconName: String) {
        self.uuid = UUID().uuidString
        self.name = name
        self.iconName = iconName
        self.createdAt = .now
    }

    var sortedCategories: [TemplateCategory] {
        (categories ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    var total: Decimal {
        (categories ?? []).reduce(0) { $0 + $1.amount }
    }
}
