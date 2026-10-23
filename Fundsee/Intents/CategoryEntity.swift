import AppIntents
import SwiftData

struct CategoryEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Intent.Parameter.Category")
    static let defaultQuery = CategoryEntityQuery()

    let id: String
    let name: String
    let iconName: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", image: .init(systemName: iconName))
    }

    init(_ category: TemplateCategory) {
        id = category.uuid
        name = category.name
        iconName = category.iconName
    }
}

struct CategoryEntityQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [CategoryEntity.ID]) async throws -> [CategoryEntity] {
        let ids = Set(identifiers)
        return allCategories().filter { ids.contains($0.uuid) }.map(CategoryEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [CategoryEntity] {
        uniqueByName(allCategories().filter { $0.name.localizedStandardContains(string) })
    }

    @MainActor
    func suggestedEntities() async throws -> [CategoryEntity] {
        let context = SharedModelContainer.current.mainContext
        let today = BudgetStore.loadEngine(context: context, around: .now).template(for: .now)?.sortedCategories ?? []
        return uniqueByName(today + allCategories())
    }

    @MainActor
    private func allCategories() -> [TemplateCategory] {
        let context = SharedModelContainer.current.mainContext
        let templates = (try? context.fetch(FetchDescriptor<BudgetTemplate>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        return templates.flatMap(\.sortedCategories).filter { !$0.uuid.isEmpty }
    }

    private func uniqueByName(_ categories: [TemplateCategory]) -> [CategoryEntity] {
        var seen: Set<String> = []
        return categories.filter { seen.insert($0.name).inserted }.map(CategoryEntity.init)
    }
}
