import AppIntents

struct OpenRecordIntent: OpenIntent {
    static let title: LocalizedStringResource = "Intent.OpenRecord.Title"
    static let description = IntentDescription("Intent.OpenRecord.Description")

    @Parameter(title: "Intent.Parameter.Record")
    var target: SpendRecordEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        AppNavigation.shared.recordID = target.id
        return .result()
    }
}

struct OpenPlanIntent: OpenIntent {
    static let title: LocalizedStringResource = "Intent.OpenPlan.Title"
    static let description = IntentDescription("Intent.OpenPlan.Description")

    @Parameter(title: "Intent.Parameter.Plan")
    var target: PlanEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        AppNavigation.shared.selectedTab = "more"
        AppNavigation.shared.planID = target.id
        return .result()
    }
}
