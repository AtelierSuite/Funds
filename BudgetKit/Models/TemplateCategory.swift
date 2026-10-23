import Foundation
import SwiftData

@Model
final class TemplateCategory {
    var uuid: String = ""
    var name: String = ""
    var amount: Decimal = 0
    var sortOrder: Int = 0
    var iconName: String = "tag.fill"
    var template: BudgetTemplate?

    init(name: String, amount: Decimal, sortOrder: Int, iconName: String = "tag.fill") {
        self.uuid = UUID().uuidString
        self.name = name
        self.amount = amount
        self.sortOrder = sortOrder
        self.iconName = iconName
    }
}
