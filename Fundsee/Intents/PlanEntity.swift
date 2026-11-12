import AppIntents
import SwiftData

struct PlanEntity: IndexedEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Intent.Parameter.Plan")
    static let defaultQuery = PlanEntityQuery()
    static let activityType = "com.tsubuzaki.Fundsee.plan"

    let id: String

    @Property(title: "Intent.Property.Name")
    var name: String

    @Property(title: "Intent.Property.DailyBudget")
    var dailyBudget: Double

    let iconName: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: LocalizedStringResource("Intent.Verbatim", defaultValue: "\(name)"),
            subtitle: LocalizedStringResource("Intent.Plan.Subtitle", defaultValue: "\(Decimal(dailyBudget).currencyString) a day"),
            image: .init(systemName: iconName)
        )
    }

    init(_ template: BudgetTemplate) {
        id = template.uuid
        iconName = template.iconName
        self.name = template.name
        self.dailyBudget = template.total.doubleValue
    }
}

struct PlanEntityQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [PlanEntity.ID]) async throws -> [PlanEntity] {
        let ids = Set(identifiers)
        return uniqueTemplates().filter { ids.contains($0.uuid) }.map(PlanEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [PlanEntity] {
        uniqueTemplates().filter { $0.name.localizedStandardContains(string) }.map(PlanEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [PlanEntity] {
        uniqueTemplates().map(PlanEntity.init)
    }

    @MainActor
    private func uniqueTemplates() -> [BudgetTemplate] {
        var seen: Set<String> = []
        return IntentData.templates().filter { seen.insert($0.uuid).inserted }
    }
}
