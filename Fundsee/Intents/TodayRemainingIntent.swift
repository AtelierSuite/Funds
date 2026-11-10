import AppIntents
import SwiftData

struct TodayRemainingIntent: AppIntent {
    static let title: LocalizedStringResource = "Intent.Remaining.Title"
    static let description = IntentDescription("Intent.Remaining.Description")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Double> & ProvidesDialog {
        let context = SharedModelContainer.current.mainContext
        let remaining = BudgetStore.loadEngine(context: context, around: .now).remaining(for: .now)
        let dialog = remaining >= 0
            ? IntentDialog(text: String(
                localized: "Intent.Remaining.Dialog.Left",
                defaultValue: "You have \(remaining.currencyString) left today."
            ))
            : IntentDialog(text: String(
                localized: "Intent.Remaining.Dialog.Over",
                defaultValue: "You're \((-remaining).currencyString) over today's budget."
            ))
        return .result(value: remaining.doubleValue, dialog: dialog)
    }
}

struct GetBudgetStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Intent.BudgetStatus.Title"
    static let description = IntentDescription("Intent.BudgetStatus.Description")

    @Parameter(title: "Intent.Parameter.Period", default: .today)
    var period: BudgetPeriod

    static var parameterSummary: some ParameterSummary {
        Summary("Intent.BudgetStatus.Summary \(\.$period)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Double> & ProvidesDialog {
        let now = Date.now
        let engine = IntentData.engine(around: now)
        let budget: Decimal
        let used: Decimal
        switch period {
        case .today:
            budget = engine.effectiveBudget(for: now)
            used = engine.spent(on: now)
        case .week:
            budget = engine.weekBudget(containing: now)
            used = engine.weekSpent(in: engine.weekInterval(containing: now))
        case .month:
            budget = engine.monthBudget(containing: now)
            used = engine.spent(in: engine.monthInterval(containing: now))
        case .year:
            let year = Calendar.current.dateInterval(of: .year, for: now) ?? engine.monthInterval(containing: now)
            let months = engine.days(in: year).filter { Calendar.current.component(.day, from: $0) == 1 }
            budget = months.reduce(Decimal(0)) { $0 + engine.monthBudget(containing: $1) }
            used = engine.spent(in: year)
        }
        let remaining = budget - used
        let label = String(localized: BudgetPeriod.caseDisplayRepresentations[period]?.title ?? "")
        let dialog = remaining >= 0
            ? String(localized: "Intent.BudgetStatus.Dialog.Left", defaultValue: "\(label): \(used.currencyString) of \(budget.currencyString) used, \(remaining.currencyString) left.")
            : String(localized: "Intent.BudgetStatus.Dialog.Over", defaultValue: "\(label): \(used.currencyString) of \(budget.currencyString) used, \((-remaining).currencyString) over.")
        return .result(value: remaining.doubleValue, dialog: IntentDialog(text: dialog))
    }
}

struct GetCategoryRemainingIntent: AppIntent {
    static let title: LocalizedStringResource = "Intent.CategoryRemaining.Title"
    static let description = IntentDescription("Intent.CategoryRemaining.Description")

    @Parameter(title: "Intent.Parameter.Category")
    var category: CategoryEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Intent.CategoryRemaining.Summary \(\.$category)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Double> & ProvidesDialog {
        let now = Date.now
        let engine = IntentData.engine(around: now)
        let categories = engine.template(for: now)?.sortedCategories ?? []
        guard let match = categories.first(where: { $0.uuid == category.id }) ?? categories.first(where: { $0.name == category.name }) else {
            let name = category.name
            return .result(value: 0, dialog: IntentDialog(text: String(
                localized: "Intent.CategoryRemaining.Dialog.NotToday",
                defaultValue: "\(name) isn't part of today's plan."
            )))
        }
        let spent = engine.spent(on: now, category: match)
        let remaining = match.amount - spent
        let name = match.name
        let dialog = remaining >= 0
            ? String(localized: "Intent.CategoryRemaining.Dialog.Left", defaultValue: "\(remaining.currencyString) left for \(name) today, out of \(match.amount.currencyString).")
            : String(localized: "Intent.CategoryRemaining.Dialog.Over", defaultValue: "You're \((-remaining).currencyString) over on \(name) today.")
        return .result(value: remaining.doubleValue, dialog: IntentDialog(text: dialog))
    }
}
