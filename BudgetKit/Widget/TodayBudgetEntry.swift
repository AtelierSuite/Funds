import Foundation
import SwiftData

func makeTodayBudgetEntry() -> BudgetEntry {
    do {
        let container = try AppGroup.readOnlyContainer()
        let context = ModelContext(container)
        let today = Date.now
        let week = Calendar.current.dateInterval(of: .weekOfYear, for: today)
            ?? DateInterval(start: Calendar.current.startOfDay(for: today), duration: 7 * 86_400)
        let start = week.start
        let end = week.end
        let engine = BudgetEngine(
            templates: try context.fetch(FetchDescriptor<BudgetTemplate>()),
            overrides: try context.fetch(FetchDescriptor<DayOverride>(predicate: #Predicate { $0.dayKey >= start && $0.dayKey < end })),
            entries: try context.fetch(FetchDescriptor<SpendEntry>(predicate: #Predicate { $0.dayKey >= start && $0.dayKey < end })),
            settings: try context.fetch(FetchDescriptor<PlanSettings>()).first
        )
        let categories = (engine.template(for: today)?.sortedCategories ?? []).map {
            CategorySnapshot(
                id: $0.name,
                iconName: $0.iconName,
                used: engine.spent(on: today, category: $0.name),
                amount: $0.amount
            )
        }
        return BudgetEntry(
            date: today,
            spent: engine.spent(on: today),
            budget: engine.effectiveBudget(for: today),
            categories: categories
        )
    } catch {
        return .placeholder
    }
}
