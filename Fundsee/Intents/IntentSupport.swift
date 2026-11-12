import AppIntents
import Foundation
import SwiftData
import WidgetKit

@MainActor
enum IntentData {
    static var context: ModelContext { SharedModelContainer.current.mainContext }

    static func engine(around date: Date = .now) -> BudgetEngine {
        BudgetStore.loadEngine(context: context, around: date)
    }

    static func templates() -> [BudgetTemplate] {
        (try? context.fetch(FetchDescriptor<BudgetTemplate>(sortBy: [SortDescriptor(\.createdAt), SortDescriptor(\.uuid)]))) ?? []
    }

    static func template(for entity: PlanEntity) throws -> BudgetTemplate {
        guard let template = templates().first(where: { $0.uuid == entity.id }) else {
            throw IntentDataError.planNotFound
        }
        return template
    }

    static func category(_ entity: CategoryEntity, in template: BudgetTemplate) throws -> TemplateCategory {
        let categories = template.sortedCategories
        guard let match = categories.first(where: { $0.uuid == entity.id }) ?? categories.first(where: { $0.name == entity.name }) else {
            throw IntentDataError.categoryNotInPlan(category: entity.name, plan: template.name)
        }
        return match
    }

    static func settings() -> PlanSettings {
        if let existing = ((try? context.fetch(FetchDescriptor<PlanSettings>())) ?? []).primary {
            return existing
        }
        return DefaultData.insertDefaultSettings(context: context, seeded: false)
    }

    static func entry(for entity: SpendRecordEntity) throws -> SpendEntry {
        guard let id = entity.persistentID else { throw IntentDataError.recordNotFound }
        var descriptor = FetchDescriptor<SpendEntry>(predicate: #Predicate { $0.persistentModelID == id })
        descriptor.fetchLimit = 1
        guard let entry = try context.fetch(descriptor).first else { throw IntentDataError.recordNotFound }
        return entry
    }

    static func latestEntry() -> SpendEntry? {
        var descriptor = FetchDescriptor<SpendEntry>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    static func categoryNames() -> [String: String] {
        let categories = (try? context.fetch(FetchDescriptor<TemplateCategory>())) ?? []
        var names: [String: String] = [:]
        for category in categories where !category.uuid.isEmpty {
            names[category.uuid] = category.name
        }
        return names
    }

    static func days(from start: Date, through end: Date) -> DateInterval {
        let calendar = Calendar.current
        let first = calendar.startOfDay(for: min(start, end))
        let last = calendar.startOfDay(for: max(start, end))
        let next = calendar.date(byAdding: .day, value: 1, to: last) ?? last
        return DateInterval(start: first, end: next)
    }

    static func rangeLabel(_ interval: DateInterval) -> String {
        let calendar = Calendar.current
        let last = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.start
        if calendar.isDate(interval.start, inSameDayAs: last) {
            return dayLabel(interval.start)
        }
        return (interval.start..<last).formatted(.interval.month(.abbreviated).day().year())
    }

    static func removeOverride(on date: Date) {
        removeOverrides(in: days(from: date, through: date))
    }

    static func removeOverrides(in interval: DateInterval) {
        let start = interval.start
        let end = interval.end
        let descriptor = FetchDescriptor<DayOverride>(predicate: #Predicate { $0.dayKey >= start && $0.dayKey < end })
        for override in (try? context.fetch(descriptor)) ?? [] {
            context.delete(override)
        }
    }

    static func status(for period: BudgetPeriod, at date: Date = .now) -> (budget: Decimal, used: Decimal) {
        let engine = engine(around: date)
        switch period {
        case .today:
            return (engine.effectiveBudget(for: date), engine.spent(on: date))
        case .week:
            return (engine.weekBudget(containing: date), engine.weekSpent(in: engine.weekInterval(containing: date)))
        case .month:
            return (engine.monthBudget(containing: date), engine.spent(in: engine.monthInterval(containing: date)))
        case .year:
            let year = Calendar.current.dateInterval(of: .year, for: date) ?? engine.monthInterval(containing: date)
            let months = engine.days(in: year).filter { Calendar.current.component(.day, from: $0) == 1 }
            let budget = months.reduce(Decimal(0)) { $0 + engine.monthBudget(containing: $1) }
            return (budget, engine.spent(in: year))
        }
    }

    static func commit() async throws {
        try context.save()
        WidgetCenter.shared.reloadAllTimelines()
        FundsShortcuts.updateAppShortcutParameters()
        await NotificationService.reschedule(engine: engine())
        await SpotlightIndex.refresh()
    }

    static func amount(_ value: Double) -> Decimal? {
        guard value.isFinite else { return nil }
        return Decimal(string: String(value))
    }

    static func dayLabel(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return String(localized: "Intent.Day.Today", defaultValue: "Today")
        }
        if Calendar.current.isDateInTomorrow(date) {
            return String(localized: "Intent.Day.Tomorrow", defaultValue: "Tomorrow")
        }
        if Calendar.current.isDateInYesterday(date) {
            return String(localized: "Intent.Day.Yesterday", defaultValue: "Yesterday")
        }
        return date.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }
}

enum IntentDataError: Error, CustomLocalizedStringResourceConvertible {
    case planNotFound
    case recordNotFound
    case noRecords
    case categoryNotInPlan(category: String, plan: String)
    case reminderLimit(plan: String)
    case reminderNotFound
    case rangeTooLong
    case currencyMismatch(code: String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .planNotFound:
            LocalizedStringResource("Intent.Error.PlanNotFound", defaultValue: "That plan no longer exists.")
        case .recordNotFound:
            LocalizedStringResource("Intent.Error.RecordNotFound", defaultValue: "That record no longer exists.")
        case .noRecords:
            LocalizedStringResource("Intent.Error.NoRecords", defaultValue: "There's no spending recorded yet.")
        case .categoryNotInPlan(let category, let plan):
            LocalizedStringResource("Intent.Error.CategoryNotInPlan", defaultValue: "\(plan) has no category named \(category).")
        case .reminderLimit(let plan):
            LocalizedStringResource("Intent.Error.ReminderLimit", defaultValue: "\(plan) already has \(String(TemplateReminder.limitPerPlan)) reminders, the most a plan can have.")
        case .reminderNotFound:
            LocalizedStringResource("Intent.Error.ReminderNotFound", defaultValue: "That reminder no longer exists.")
        case .rangeTooLong:
            LocalizedStringResource("Intent.Error.RangeTooLong", defaultValue: "Choose a range of a year or less.")
        case .currencyMismatch(let code):
            LocalizedStringResource("Intent.Error.CurrencyMismatch", defaultValue: "This payment is in \(code), which is not the currency Funds uses. Log it by hand in your currency.")
        }
    }
}

extension IntentDialog {
    init(text: String) {
        self.init(stringLiteral: text)
    }
}
