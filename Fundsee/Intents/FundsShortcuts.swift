import AppIntents

struct FundsShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogSpendIntent(),
            phrases: [
                "Log spending in \(.applicationName)",
                "Add an expense in \(.applicationName)",
            ],
            shortTitle: "Intent.LogSpend.Title",
            systemImageName: "plus.circle.fill"
        )
        AppShortcut(
            intent: TodayRemainingIntent(),
            phrases: [
                "How much is left in \(.applicationName)",
                "Check my budget in \(.applicationName)",
            ],
            shortTitle: "Intent.Remaining.Title",
            systemImageName: "chart.pie.fill"
        )
        AppShortcut(
            intent: GetBudgetStatusIntent(),
            phrases: [
                "How am I doing \(\.$period) in \(.applicationName)",
                "Show my spending \(\.$period) in \(.applicationName)",
                "Budget summary in \(.applicationName)",
            ],
            shortTitle: "Intent.BudgetStatus.Title",
            systemImageName: "chart.bar.fill"
        )
        AppShortcut(
            intent: GetCategoryRemainingIntent(),
            phrases: [
                "How much is left for \(\.$category) in \(.applicationName)",
                "Check a category in \(.applicationName)",
            ],
            shortTitle: "Intent.CategoryRemaining.Title",
            systemImageName: "square.grid.2x2.fill"
        )
        AppShortcut(
            intent: UndoLastSpendIntent(),
            phrases: [
                "Undo my last expense in \(.applicationName)",
                "Delete my last expense in \(.applicationName)",
            ],
            shortTitle: "Intent.UndoLast.Title",
            systemImageName: "arrow.uturn.backward.circle.fill"
        )
        AppShortcut(
            intent: GetSpendRecordsIntent(),
            phrases: [
                "What did I spend today in \(.applicationName)",
                "Show today's expenses in \(.applicationName)",
            ],
            shortTitle: "Intent.GetRecords.Title",
            systemImageName: "list.bullet.rectangle.fill"
        )
        AppShortcut(
            intent: GetDayPlanIntent(),
            phrases: [
                "What's my plan today in \(.applicationName)",
                "Which plan is today in \(.applicationName)",
            ],
            shortTitle: "Intent.GetDayPlan.Title",
            systemImageName: "calendar.badge.clock"
        )
        AppShortcut(
            intent: SetDayPlanIntent(),
            phrases: [
                "Switch to \(\.$plan) in \(.applicationName)",
                "Use \(\.$plan) today in \(.applicationName)",
                "Change today's plan in \(.applicationName)",
            ],
            shortTitle: "Intent.SetDayPlan.Title",
            systemImageName: "square.grid.2x2.fill"
        )
        AppShortcut(
            intent: OpenTabIntent(),
            phrases: [
                "Open \(\.$tab) in \(.applicationName)",
                "Show \(\.$tab) in \(.applicationName)",
            ],
            shortTitle: "Intent.OpenTab.Title",
            systemImageName: "rectangle.portrait.on.rectangle.portrait.angled.fill"
        )
    }
}
