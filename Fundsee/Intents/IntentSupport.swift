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

    static func removeOverride(on date: Date) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        let descriptor = FetchDescriptor<DayOverride>(predicate: #Predicate { $0.dayKey >= start && $0.dayKey < end })
        for override in (try? context.fetch(descriptor)) ?? [] {
            context.delete(override)
        }
    }

    static func commit() async throws {
        try context.save()
        WidgetCenter.shared.reloadAllTimelines()
        FundsShortcuts.updateAppShortcutParameters()
        await NotificationService.reschedule(engine: engine())
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
        }
    }
}

extension IntentDialog {
    init(text: String) {
        self.init(stringLiteral: text)
    }
}
