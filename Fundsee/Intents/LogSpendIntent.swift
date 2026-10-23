import AppIntents
import SwiftData

struct LogSpendIntent: AppIntent {
    static let title: LocalizedStringResource = "Intent.LogSpend.Title"
    static let description = IntentDescription("Intent.LogSpend.Description")

    @Parameter(title: "Intent.Parameter.Category")
    var category: CategoryEntity

    @Parameter(title: "Common.Amount", inclusiveRange: (0.01, 1_000_000_000))
    var amount: Double

    static var parameterSummary: some ParameterSummary {
        Summary("Intent.LogSpend.Summary \(\.$amount) \(\.$category)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let value = Decimal(string: String(amount)), value > 0 else {
            throw $amount.needsValueError()
        }
        let context = SharedModelContainer.current.mainContext
        let today = Date.now
        let engine = BudgetStore.loadEngine(context: context, around: today)
        let category = engine.template(for: today)?.sortedCategories.first { $0.uuid == self.category.id }
            ?? engine.template(for: today)?.sortedCategories.first { $0.name == self.category.name }
        context.insert(SpendEntry(
            dayKey: today,
            categoryName: category?.name ?? self.category.name,
            categoryID: category?.uuid ?? self.category.id,
            amount: value
        ))
        try context.save()

        let remaining = BudgetStore.loadEngine(context: context, around: today).remaining(for: today)
        let logged = value.currencyString
        let name = category?.name ?? self.category.name
        if remaining >= 0 {
            return .result(dialog: IntentDialog(stringLiteral: String(
                localized: "Intent.LogSpend.Dialog.Left",
                defaultValue: "Logged \(logged) for \(name). \(remaining.currencyString) left today."
            )))
        }
        return .result(dialog: IntentDialog(stringLiteral: String(
            localized: "Intent.LogSpend.Dialog.Over",
            defaultValue: "Logged \(logged) for \(name). You're \((-remaining).currencyString) over today."
        )))
    }
}
