import Foundation
import SwiftData

@MainActor
final class BudgetFixture {
    let container: ModelContainer
    let context: ModelContext
    let calendar: Calendar
    let settings: PlanSettings
    let office: BudgetTemplate
    let home: BudgetTemplate
    let off: BudgetTemplate
    var officeLunch: TemplateCategory!
    var officeCoffee: TemplateCategory!
    var homeLunch: TemplateCategory!
    var offFun: TemplateCategory!

    init(firstWeekday: Int = 2) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        calendar.firstWeekday = firstWeekday
        self.calendar = calendar

        let configuration = ModelConfiguration(schema: AppGroup.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: AppGroup.schema, configurations: [configuration])
        context = ModelContext(container)

        office = BudgetTemplate(name: "Office", iconName: "building.2.fill")
        home = BudgetTemplate(name: "Home", iconName: "house.fill")
        off = BudgetTemplate(name: "Off", iconName: "sofa.fill")
        settings = PlanSettings()
        context.insert(office)
        context.insert(home)
        context.insert(off)
        context.insert(settings)

        officeLunch = addCategory("Lunch", amount: 10, to: office)
        officeCoffee = addCategory("Coffee", amount: 5, to: office)
        homeLunch = addCategory("Lunch", amount: 8, to: home)
        offFun = addCategory("Fun", amount: 20, to: off)

        settings.setTemplateUUID(off.uuid, forWeekday: 1)
        for weekday in 2...6 {
            settings.setTemplateUUID(office.uuid, forWeekday: weekday)
        }
        settings.setTemplateUUID(off.uuid, forWeekday: 7)
        try context.save()
    }

    @discardableResult
    func addCategory(_ name: String, amount: Decimal, to template: BudgetTemplate) -> TemplateCategory {
        let category = TemplateCategory(
            name: name,
            amount: amount,
            sortOrder: template.categories?.count ?? 0
        )
        category.template = template
        context.insert(category)
        return category
    }

    func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    @discardableResult
    func spend(_ amount: Decimal, on day: Date, category: String = "Lunch", scope: SpendScope = .day, at timestamp: Date? = nil) -> SpendEntry {
        let entry = SpendEntry(dayKey: day, categoryName: category, amount: amount, scope: scope)
        if let timestamp { entry.timestamp = timestamp }
        context.insert(entry)
        return entry
    }

    @discardableResult
    func spend(_ amount: Decimal, on day: Date, to category: TemplateCategory) -> SpendEntry {
        let entry = SpendEntry(dayKey: day, categoryName: category.name, categoryID: category.uuid, amount: amount)
        context.insert(entry)
        return entry
    }

    func override(_ day: Date, with template: BudgetTemplate) {
        context.insert(DayOverride(dayKey: day, template: template))
    }

    func engine() throws -> BudgetEngine {
        try context.save()
        return BudgetEngine(
            templates: try context.fetch(FetchDescriptor<BudgetTemplate>()),
            overrides: try context.fetch(FetchDescriptor<DayOverride>()),
            entries: try context.fetch(FetchDescriptor<SpendEntry>()),
            settings: try context.fetch(FetchDescriptor<PlanSettings>()).first,
            calendar: calendar
        )
    }
}
