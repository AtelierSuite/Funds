import AppIntents
import SwiftData

struct AddCategoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Intent.AddCategory.Title"
    static let description = IntentDescription("Intent.AddCategory.Description")

    @Parameter(title: "Intent.Parameter.Plan")
    var plan: PlanEntity

    @Parameter(title: "Intent.Property.Name")
    var name: String

    @Parameter(title: "Intent.Parameter.Budget", default: 0, inclusiveRange: (0, 1_000_000_000))
    var amount: Double

    static var parameterSummary: some ParameterSummary {
        Summary("Intent.AddCategory.Summary \(\.$name) \(\.$plan) \(\.$amount)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<CategoryEntity> & ProvidesDialog {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw $name.needsValueError() }
        guard let value = IntentData.amount(amount), value >= 0 else { throw $amount.needsValueError() }
        let template = try IntentData.template(for: plan)
        let category = TemplateCategory(
            name: trimmed,
            amount: value,
            sortOrder: (template.sortedCategories.last?.sortOrder ?? -1) + 1
        )
        category.template = template
        IntentData.context.insert(category)
        try await IntentData.commit()
        let planName = template.name
        return .result(value: CategoryEntity(category), dialog: IntentDialog(text: String(
            localized: "Intent.AddCategory.Dialog",
            defaultValue: "Added \(trimmed) to \(planName) with \(value.currencyString) a day."
        )))
    }
}

struct SetCategoryBudgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Intent.SetCategoryBudget.Title"
    static let description = IntentDescription("Intent.SetCategoryBudget.Description")

    @Parameter(title: "Intent.Parameter.Plan")
    var plan: PlanEntity

    @Parameter(title: "Intent.Parameter.Category")
    var category: CategoryEntity

    @Parameter(title: "Intent.Parameter.Budget", inclusiveRange: (0, 1_000_000_000))
    var amount: Double

    static var parameterSummary: some ParameterSummary {
        Summary("Intent.SetCategoryBudget.Summary \(\.$category) \(\.$plan) \(\.$amount)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let value = IntentData.amount(amount), value >= 0 else { throw $amount.needsValueError() }
        let template = try IntentData.template(for: plan)
        let match = try IntentData.category(category, in: template)
        match.amount = value
        try await IntentData.commit()
        let name = match.name
        let planName = template.name
        return .result(dialog: IntentDialog(text: String(
            localized: "Intent.SetCategoryBudget.Dialog",
            defaultValue: "\(name) in \(planName) is now \(value.currencyString) a day. The plan totals \(template.total.currencyString)."
        )))
    }
}

struct RenameCategoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Intent.RenameCategory.Title"
    static let description = IntentDescription("Intent.RenameCategory.Description")

    @Parameter(title: "Intent.Parameter.Plan")
    var plan: PlanEntity

    @Parameter(title: "Intent.Parameter.Category")
    var category: CategoryEntity

    @Parameter(title: "Intent.Property.Name")
    var name: String

    static var parameterSummary: some ParameterSummary {
        Summary("Intent.RenameCategory.Summary \(\.$category) \(\.$plan) \(\.$name)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw $name.needsValueError() }
        let template = try IntentData.template(for: plan)
        let match = try IntentData.category(category, in: template)
        let previous = match.name
        match.name = trimmed
        try await IntentData.commit()
        return .result(dialog: IntentDialog(text: String(
            localized: "Intent.RenameCategory.Dialog",
            defaultValue: "Renamed \(previous) to \(trimmed)."
        )))
    }
}

struct DeleteCategoryIntent: AppIntent {
    static let title: LocalizedStringResource = "Intent.DeleteCategory.Title"
    static let description = IntentDescription("Intent.DeleteCategory.Description")

    @Parameter(title: "Intent.Parameter.Plan")
    var plan: PlanEntity

    @Parameter(title: "Intent.Parameter.Category")
    var category: CategoryEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Intent.DeleteCategory.Summary \(\.$category) \(\.$plan)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let template = try IntentData.template(for: plan)
        let match = try IntentData.category(category, in: template)
        let name = match.name
        let planName = template.name
        try await requestConfirmation(dialog: IntentDialog(text: String(
            localized: "Intent.DeleteCategory.Confirm",
            defaultValue: "Remove \(name) from \(planName)? Spending already recorded is kept."
        )))
        IntentData.context.delete(match)
        try await IntentData.commit()
        return .result(dialog: IntentDialog(text: String(
            localized: "Intent.DeleteCategory.Dialog",
            defaultValue: "Removed \(name) from \(planName)."
        )))
    }
}
