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

struct ResetDayPlanIntent: AppIntent {
    static let title: LocalizedStringResource = "Intent.ResetDayPlan.Title"
    static let description = IntentDescription("Intent.ResetDayPlan.Description")

    @Parameter(title: "Intent.Parameter.Date", kind: .date)
    var date: Date?

    static var parameterSummary: some ParameterSummary {
        Summary("Intent.ResetDayPlan.Summary \(\.$date)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let day = date ?? .now
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
