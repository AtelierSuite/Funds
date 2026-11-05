import SwiftUI

struct CategorySnapshot: Identifiable {
    let id: String
    let name: String
    let iconName: String
    let used: Decimal
    let amount: Decimal

    var iconColor: Color { CategoryIconPalette.color(for: iconName) }
}

extension CategorySnapshot {
    init(_ category: TemplateCategory, used: Decimal) {
        self.init(
            id: category.uuid.isEmpty ? category.name : category.uuid,
            name: category.name,
            iconName: category.iconName,
            used: used,
            amount: category.amount
        )
    }
}
