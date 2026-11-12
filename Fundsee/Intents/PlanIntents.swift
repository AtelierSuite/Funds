import AppIntents
import SwiftData

struct GetDayPlanIntent: AppIntent {
    static let title: LocalizedStringResource = "Intent.GetDayPlan.Title"
    static let description = IntentDescription("Intent.GetDayPlan.Description")

    @Parameter(title: "Intent.Parameter.Date", kind: .date)
    var date: Date?

    static var parameterSummary: some ParameterSummary {
        Summary("Intent.GetDayPlan.Summary \(\.$date)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<PlanEntity?> & ProvidesDialog {
        let day = date ?? .now
        let engine = IntentData.engine(around: day)
        let dayText = IntentData.dayLabel(day)
        guard let template = engine.template(for: day) else {
            return .result(value: nil, dialog: IntentDialog(text: String(
                localized: "Intent.GetDayPlan.Dialog.None",
                defaultValue: "\(dayText) has no plan."
            )))
        }
        let name = template.name
        let budget = engine.effectiveBudget(for: day).currencyString
        return .result(value: PlanEntity(template), dialog: IntentDialog(text: String(
            localized: "Intent.GetDayPlan.Dialog",
            defaultValue: "\(dayText) uses \(name), with a budget of \(budget)."
        )))
    }
}

struct SetDayPlanIntent: AppIntent {
    static let title: LocalizedStringResource = "Intent.SetDayPlan.Title"
    static let description = IntentDescription("Intent.SetDayPlan.Description")

    @Parameter(title: "Intent.Parameter.Plan")
    var plan: PlanEntity

    @Parameter(title: "Intent.Parameter.Date", kind: .date)
    var date: Date?

    static var parameterSummary: some ParameterSummary {
        Summary("Intent.SetDayPlan.Summary \(\.$plan) \(\.$date)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let day = date ?? .now
        let template = try IntentData.template(for: plan)
        IntentData.removeOverride(on: day)
        IntentData.context.insert(DayOverride(dayKey: day, template: template))
        try await IntentData.commit()
        let dayText = IntentData.dayLabel(day)
        let name = template.name
        let budget = IntentData.engine(around: day).effectiveBudget(for: day).currencyString
        return .result(dialog: IntentDialog(text: String(
            localized: "Intent.SetDayPlan.Dialog",
            defaultValue: "\(dayText) now uses \(name), with a budget of \(budget)."
        )))
    }
}

struct SetPlanForDatesIntent: AppIntent {
    static let title: LocalizedStringResource = "Intent.SetPlanForDates.Title"
    static let description = IntentDescription("Intent.SetPlanForDates.Description")

    @Parameter(title: "Intent.Parameter.Plan")
    var plan: PlanEntity

    @Parameter(title: "Intent.Parameter.StartDate", kind: .date)
    var start: Date

    @Parameter(title: "Intent.Parameter.EndDate", kind: .date)
    var end: Date

    static var parameterSummary: some ParameterSummary {
        Summary("Intent.SetPlanForDates.Summary \(\.$plan) \(\.$start) \(\.$end)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let interval = IntentData.days(from: start, through: end)
        let template = try IntentData.template(for: plan)
        let days = IntentData.engine(around: interval.start).days(in: interval).filter { $0 >= interval.start && $0 < interval.end }
        guard days.count <= 366 else { throw IntentDataError.rangeTooLong }
        IntentData.removeOverrides(in: interval)
        for day in days {
            IntentData.context.insert(DayOverride(dayKey: day, template: template))
        }
        try await IntentData.commit()
        let name = template.name
        let range = IntentData.rangeLabel(interval)
        return .result(dialog: IntentDialog(text: String(
            localized: "Intent.SetPlanForDates.Dialog",
            defaultValue: "\(range) now uses \(name)."
        )))
    }
}

struct ResetDayPlanIntent: AppIntent {
    static let title: LocalizedStringResource = "Intent.ResetDayPlan.Title"
    static let description = IntentDescription("Intent.ResetDayPlan.Description")

    @Parameter(title: "Intent.Parameter.Date", kind: .date)
    var date: Date?

    @Parameter(title: "Intent.Parameter.EndDate", kind: .date)
    var end: Date?

    static var parameterSummary: some ParameterSummary {
        Summary("Intent.ResetDayPlan.Summary \(\.$date)") {
            \.$end
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let day = date ?? .now
        if let end {
            let interval = IntentData.days(from: day, through: end)
            IntentData.removeOverrides(in: interval)
            try await IntentData.commit()
            let range = IntentData.rangeLabel(interval)
            return .result(dialog: IntentDialog(text: String(
                localized: "Intent.ResetDayPlan.Dialog.Range",
                defaultValue: "\(range) is back to the weekly plan."
            )))
        }
        IntentData.removeOverride(on: day)
        try await IntentData.commit()
        let dayText = IntentData.dayLabel(day)
        guard let template = IntentData.engine(around: day).template(for: day) else {
            return .result(dialog: IntentDialog(text: String(
                localized: "Intent.ResetDayPlan.Dialog.None",
                defaultValue: "\(dayText) is back to its weekly plan, which has no plan assigned."
            )))
        }
        let name = template.name
        return .result(dialog: IntentDialog(text: String(
            localized: "Intent.ResetDayPlan.Dialog",
            defaultValue: "\(dayText) is back to its weekly plan, \(name)."
        )))
    }
}

struct GetWeekdayPlanIntent: AppIntent {
    static let title: LocalizedStringResource = "Intent.GetWeekdayPlan.Title"
    static let description = IntentDescription("Intent.GetWeekdayPlan.Description")

    @Parameter(title: "Intent.Parameter.Weekday")
    var weekday: WeekdayOption

    static var parameterSummary: some ParameterSummary {
        Summary("Intent.GetWeekdayPlan.Summary \(\.$weekday)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<PlanEntity?> & ProvidesDialog {
        let uuid = IntentData.settings().templateUUID(forWeekday: weekday.rawValue)
        let day = weekday.name
        guard let uuid, let template = IntentData.templates().first(where: { $0.uuid == uuid }) else {
            return .result(value: nil, dialog: IntentDialog(text: String(
                localized: "Intent.GetWeekdayPlan.Dialog.None",
                defaultValue: "\(day) has no plan."
            )))
        }
        let name = template.name
        return .result(value: PlanEntity(template), dialog: IntentDialog(text: String(
            localized: "Intent.GetWeekdayPlan.Dialog",
            defaultValue: "Every \(day) uses \(name)."
        )))
    }
}

struct SetWeekdayPlanIntent: AppIntent {
    static let title: LocalizedStringResource = "Intent.SetWeekdayPlan.Title"
    static let description = IntentDescription("Intent.SetWeekdayPlan.Description")

    @Parameter(title: "Intent.Parameter.Weekday")
    var weekday: WeekdayOption

    @Parameter(title: "Intent.Parameter.Plan")
    var plan: PlanEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Intent.SetWeekdayPlan.Summary \(\.$weekday) \(\.$plan)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let template = try plan.map(IntentData.template(for:))
        IntentData.settings().setTemplateUUID(template?.uuid, forWeekday: weekday.rawValue)
        try await IntentData.commit()
        let day = weekday.name
        guard let template else {
            return .result(dialog: IntentDialog(text: String(
                localized: "Intent.SetWeekdayPlan.Dialog.None",
                defaultValue: "\(day) no longer has a plan."
            )))
        }
        let name = template.name
        return .result(dialog: IntentDialog(text: String(
            localized: "Intent.SetWeekdayPlan.Dialog",
            defaultValue: "Every \(day) now uses \(name)."
        )))
    }
}

struct CreatePlanIntent: AppIntent {
    static let title: LocalizedStringResource = "Intent.CreatePlan.Title"
    static let description = IntentDescription("Intent.CreatePlan.Description")

    @Parameter(title: "Intent.Property.Name")
    var name: String

    static var parameterSummary: some ParameterSummary {
        Summary("Intent.CreatePlan.Summary \(\.$name)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<PlanEntity> & ProvidesDialog {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw $name.needsValueError() }
        let context = IntentData.context
        let template = BudgetTemplate(name: trimmed, iconName: AppSymbol.budgetTemplate)
        context.insert(template)
        for (index, categoryName) in DefaultData.categoryNames.enumerated() {
            let category = TemplateCategory(name: categoryName, amount: 0, sortOrder: index, iconName: DefaultData.categoryIcons[index])
            category.template = template
            context.insert(category)
        }
        try await IntentData.commit()
        return .result(value: PlanEntity(template), dialog: IntentDialog(text: String(
            localized: "Intent.CreatePlan.Dialog",
            defaultValue: "Created \(trimmed). Set each category's budget to start using it."
        )))
    }
}

struct RenamePlanIntent: AppIntent {
    static let title: LocalizedStringResource = "Intent.RenamePlan.Title"
    static let description = IntentDescription("Intent.RenamePlan.Description")

    @Parameter(title: "Intent.Parameter.Plan")
    var plan: PlanEntity

    @Parameter(title: "Intent.Property.Name")
    var name: String

    static var parameterSummary: some ParameterSummary {
        Summary("Intent.RenamePlan.Summary \(\.$plan) \(\.$name)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<PlanEntity> & ProvidesDialog {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw $name.needsValueError() }
        let template = try IntentData.template(for: plan)
        let previous = template.name
        template.name = trimmed
        try await IntentData.commit()
        return .result(value: PlanEntity(template), dialog: IntentDialog(text: String(
            localized: "Intent.RenamePlan.Dialog",
            defaultValue: "Renamed \(previous) to \(trimmed)."
        )))
    }
}

struct DeletePlanIntent: AppIntent {
    static let title: LocalizedStringResource = "Intent.DeletePlan.Title"
    static let description = IntentDescription("Intent.DeletePlan.Description")

    @Parameter(title: "Intent.Parameter.Plan")
    var plan: PlanEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Intent.DeletePlan.Summary \(\.$plan)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let template = try IntentData.template(for: plan)
        let name = template.name
        try await requestConfirmation(dialog: IntentDialog(text: String(
            localized: "Intent.DeletePlan.Confirm",
            defaultValue: "Delete \(name)? Days using it will have no budget until you assign another plan."
        )))
        IntentData.context.delete(template)
        try await IntentData.commit()
        return .result(dialog: IntentDialog(text: String(
            localized: "Intent.DeletePlan.Dialog",
            defaultValue: "Deleted \(name)."
        )))
    }
}

struct DuplicatePlanIntent: AppIntent {
    static let title: LocalizedStringResource = "Intent.DuplicatePlan.Title"
    static let description = IntentDescription("Intent.DuplicatePlan.Description")

    @Parameter(title: "Intent.Parameter.Plan")
    var plan: PlanEntity

    @Parameter(title: "Intent.Property.Name")
    var name: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Intent.DuplicatePlan.Summary \(\.$plan)") {
            \.$name
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<PlanEntity> & ProvidesDialog {
        let source = try IntentData.template(for: plan)
        let sourceName = source.name
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let copyName = trimmed.isEmpty
            ? String(localized: "Intent.DuplicatePlan.CopyName", defaultValue: "\(sourceName) Copy")
            : trimmed
        let context = IntentData.context
        let copy = BudgetTemplate(name: copyName, iconName: source.iconName)
        context.insert(copy)
        for category in source.sortedCategories {
            let duplicate = TemplateCategory(name: category.name, amount: category.amount, sortOrder: category.sortOrder, iconName: category.iconName)
            duplicate.template = copy
            context.insert(duplicate)
        }
        for reminder in source.sortedReminders {
            let duplicate = TemplateReminder(hour: reminder.hour, minute: reminder.minute, message: reminder.message)
            duplicate.template = copy
            context.insert(duplicate)
        }
        try await IntentData.commit()
        return .result(value: PlanEntity(copy), dialog: IntentDialog(text: String(
            localized: "Intent.DuplicatePlan.Dialog",
            defaultValue: "Created \(copyName) from \(sourceName)."
        )))
    }
}

struct SetPlanIconIntent: AppIntent {
    static let title: LocalizedStringResource = "Intent.SetPlanIcon.Title"
    static let description = IntentDescription("Intent.SetPlanIcon.Description")

    @Parameter(title: "Intent.Parameter.Plan")
    var plan: PlanEntity

    @Parameter(title: "Intent.Parameter.Icon")
    var icon: PlanIconOption

    static var parameterSummary: some ParameterSummary {
        Summary("Intent.SetPlanIcon.Summary \(\.$plan) \(\.$icon)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<PlanEntity> & ProvidesDialog {
        let template = try IntentData.template(for: plan)
        template.iconName = icon.rawValue
        try await IntentData.commit()
        let name = template.name
        return .result(value: PlanEntity(template), dialog: IntentDialog(text: String(
            localized: "Intent.SetPlanIcon.Dialog",
            defaultValue: "Changed the icon for \(name)."
        )))
    }
}
