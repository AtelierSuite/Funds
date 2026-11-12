import AppIntents
import SwiftData

struct TodayRemainingIntent: AppIntent {
    static let title: LocalizedStringResource = "Intent.Remaining.Title"
    static let description = IntentDescription("Intent.Remaining.Description")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Double> & ProvidesDialog & ShowsSnippetIntent {
        let remaining = IntentData.engine().remaining(for: .now)
        let dialog = remaining >= 0
            ? IntentDialog(text: String(
                localized: "Intent.Remaining.Dialog.Left",
                defaultValue: "You have \(remaining.currencyString) left today."
            ))
            : IntentDialog(text: String(
                localized: "Intent.Remaining.Dialog.Over",
                defaultValue: "You're \((-remaining).currencyString) over today's budget."
            ))
        return .result(value: remaining.doubleValue, dialog: dialog, snippetIntent: TodaySnippetIntent())
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
        let (budget, used) = IntentData.status(for: period)
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

struct IsOverBudgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Intent.IsOverBudget.Title"
    static let description = IntentDescription("Intent.IsOverBudget.Description")

    @Parameter(title: "Intent.Parameter.Period", default: .today)
    var period: BudgetPeriod

    static var parameterSummary: some ParameterSummary {
        Summary("Intent.IsOverBudget.Summary \(\.$period)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> & ProvidesDialog {
        let (budget, used) = IntentData.status(for: period)
        let remaining = budget - used
        let label = String(localized: BudgetPeriod.caseDisplayRepresentations[period]?.title ?? "")
        let dialog = remaining < 0
            ? String(localized: "Intent.IsOverBudget.Dialog.Yes", defaultValue: "\(label): over budget by \((-remaining).currencyString).")
            : String(localized: "Intent.IsOverBudget.Dialog.No", defaultValue: "\(label): within budget, with \(remaining.currencyString) left.")
        return .result(value: remaining < 0, dialog: IntentDialog(text: dialog))
    }
}

struct GetTotalSpentIntent: AppIntent {
    static let title: LocalizedStringResource = "Intent.TotalSpent.Title"
    static let description = IntentDescription("Intent.TotalSpent.Description")

    @Parameter(title: "Intent.Parameter.StartDate", kind: .date)
    var start: Date?

    @Parameter(title: "Intent.Parameter.EndDate", kind: .date)
    var end: Date?

    @Parameter(title: "Intent.Parameter.Category")
    var category: CategoryEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Intent.TotalSpent.Summary \(\.$start) \(\.$end)") {
            \.$category
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Double> & ProvidesDialog {
        let calendar = Calendar.current
        let now = Date.now
        let first = start ?? calendar.dateInterval(of: .month, for: now)?.start ?? now
        let interval = IntentData.days(from: first, through: end ?? now)
        var total: Decimal = 0
        var cursor = interval.start
        while cursor < interval.end {
            let year = calendar.dateInterval(of: .year, for: cursor) ?? interval
            let slice = DateInterval(start: cursor, end: min(year.end, interval.end))
            let engine = IntentData.engine(around: cursor)
            var entries = engine.entries(in: slice)
            if let category {
                entries = entries.filter { $0.scope == .day && engine.entry($0, belongsTo: category.id, named: category.name) }
            }
            total += entries.reduce(Decimal(0)) { $0 + $1.amount }
            cursor = slice.end
        }
        let range = IntentData.rangeLabel(interval)
        let amount = total.currencyString
        let dialog: String
        if let category {
            let name = category.name
            dialog = String(localized: "Intent.TotalSpent.Dialog.Category", defaultValue: "\(range): you spent \(amount) on \(name).")
        } else {
            dialog = String(localized: "Intent.TotalSpent.Dialog", defaultValue: "\(range): you spent \(amount).")
        }
        return .result(value: total.doubleValue, dialog: IntentDialog(text: dialog))
    }
}
