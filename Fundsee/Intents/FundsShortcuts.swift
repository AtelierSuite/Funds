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
    }
}
