import Foundation
import WidgetKit

struct BudgetEntry: TimelineEntry {
    let date: Date
    let spent: Decimal
    let budget: Decimal
    let categories: [CategorySnapshot]

    var remaining: Decimal { budget - spent }
    var overBudget: Bool { spent > budget }
    var fractionUsed: Double {
        budget > 0 ? min(1, spent.doubleValue / budget.doubleValue) : (spent > 0 ? 1 : 0)
    }

    static let placeholder = BudgetEntry(
        date: .now,
        spent: 12,
        budget: 40,
        categories: [
            CategorySnapshot(id: "Breakfast", name: "Breakfast", iconName: "sunrise.fill", used: 4, amount: 6),
            CategorySnapshot(id: "Lunch", name: "Lunch", iconName: "takeoutbag.and.cup.and.straw.fill", used: 8, amount: 14),
            CategorySnapshot(id: "Dinner", name: "Dinner", iconName: "fork.knife", used: 0, amount: 16),
        ]
    )
}
