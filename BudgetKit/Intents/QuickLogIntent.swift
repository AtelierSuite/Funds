import AppIntents

struct QuickLogIntent: AppIntent {
    static let title: LocalizedStringResource = "Intent.QuickLog.Title"
    static let description = IntentDescription("Intent.QuickLog.Description")
    static let supportedModes: IntentModes = .foreground(.immediate)
    static let isDiscoverable = false

    @Parameter(title: "Intent.Parameter.Category")
    var categoryID: String?

    init() {}

    init(categoryID: String?) {
        self.categoryID = categoryID
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        AppNavigation.shared.selectedTab = "today"
        AppNavigation.shared.quickLog = QuickLogRequest(categoryID: categoryID)
        return .result()
    }
}
