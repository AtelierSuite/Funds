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
            ? IntentDialog(stringLiteral: String(
                localized: "Intent.Remaining.Dialog.Left",
                defaultValue: "You have \(remaining.currencyString) left today."
            ))
            : IntentDialog(stringLiteral: String(
                localized: "Intent.Remaining.Dialog.Over",
                defaultValue: "You're \((-remaining).currencyString) over today's budget."
            ))
        return .result(value: remaining.doubleValue, dialog: dialog)
    }
}
