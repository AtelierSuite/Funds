import AppIntents
import SwiftData

struct AddPlanReminderIntent: AppIntent {
    static let title: LocalizedStringResource = "Intent.AddReminder.Title"
    static let description = IntentDescription("Intent.AddReminder.Description")

    @Parameter(title: "Intent.Parameter.Plan")
    var plan: PlanEntity

    @Parameter(title: "Intent.Parameter.Time", kind: .time)
    var time: Date

    @Parameter(title: "Intent.Parameter.Message")
    var message: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Intent.AddReminder.Summary \(\.$time) \(\.$plan)") {
            \.$message
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let template = try IntentData.template(for: plan)
        guard template.sortedReminders.count < TemplateReminder.limitPerPlan else {
            throw IntentDataError.reminderLimit(plan: template.name)
        }
        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let reminder = TemplateReminder(
            hour: components.hour ?? 20,
            minute: components.minute ?? 0,
            message: message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        )
        reminder.template = template
        IntentData.context.insert(reminder)
        _ = await NotificationService.requestAuthorization()
        try await IntentData.commit()
        let timeText = time.formatted(date: .omitted, time: .shortened)
        let name = template.name
        return .result(dialog: IntentDialog(text: String(
            localized: "Intent.AddReminder.Dialog",
            defaultValue: "You'll be reminded at \(timeText) on days using \(name)."
        )))
    }
}

struct ClearPlanRemindersIntent: AppIntent {
    static let title: LocalizedStringResource = "Intent.ClearReminders.Title"
    static let description = IntentDescription("Intent.ClearReminders.Description")

    @Parameter(title: "Intent.Parameter.Plan")
    var plan: PlanEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Intent.ClearReminders.Summary \(\.$plan)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let template = try IntentData.template(for: plan)
        for reminder in template.sortedReminders {
            IntentData.context.delete(reminder)
        }
        try await IntentData.commit()
        let name = template.name
        return .result(dialog: IntentDialog(text: String(
            localized: "Intent.ClearReminders.Dialog",
            defaultValue: "Removed all reminders from \(name)."
        )))
    }
}

struct SetOverallBudgetIntent: AppIntent {
    static let title: LocalizedStringResource = "Intent.SetOverallBudget.Title"
    static let description = IntentDescription("Intent.SetOverallBudget.Description")

    @Parameter(title: "Intent.Parameter.OverallBudget")
    var budget: OverallBudgetKind

    @Parameter(title: "Common.Amount", inclusiveRange: (0, 1_000_000_000))
    var amount: Double

    static var parameterSummary: some ParameterSummary {
        Summary("Intent.SetOverallBudget.Summary \(\.$budget) \(\.$amount)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let value = IntentData.amount(amount), value >= 0 else { throw $amount.needsValueError() }
        let settings = IntentData.settings()
        switch budget {
        case .weekly: settings.weeklyOverallBudget = value
        case .monthly: settings.monthlyOverallBudget = value
        }
        try await IntentData.commit()
        let label = budget.label
        return .result(dialog: IntentDialog(text: String(
            localized: "Intent.SetOverallBudget.Dialog",
            defaultValue: "Your \(label) is now \(value.currencyString)."
        )))
    }
}

struct SetCarryoverIntent: AppIntent {
    static let title: LocalizedStringResource = "Intent.SetCarryover.Title"
    static let description = IntentDescription("Intent.SetCarryover.Description")

    @Parameter(title: "Intent.Parameter.Carryover")
    var behavior: CarryoverOption

    static var parameterSummary: some ParameterSummary {
        Summary("Intent.SetCarryover.Summary \(\.$behavior)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        IntentData.settings().carryover = behavior.behavior
        try await IntentData.commit()
        return .result(dialog: IntentDialog(text: behavior.behavior.subtitle))
    }
}

struct OpenTabIntent: AppIntent {
    static let title: LocalizedStringResource = "Intent.OpenTab.Title"
    static let description = IntentDescription("Intent.OpenTab.Description")
    static let supportedModes: IntentModes = .foreground(.immediate)

    @Parameter(title: "Intent.Parameter.Tab")
    var tab: AppTabOption

    static var parameterSummary: some ParameterSummary {
        Summary("Intent.OpenTab.Summary \(\.$tab)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        AppNavigation.shared.selectedTab = tab.rawValue
        return .result()
    }
}
