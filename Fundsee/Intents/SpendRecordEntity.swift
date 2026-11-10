import AppIntents
import SwiftData

struct SpendRecordEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Intent.Parameter.Record")
    static let defaultQuery = SpendRecordEntityQuery()

    let id: String

    @Property(title: "Common.Amount")
    var amount: Double

    @Property(title: "Intent.Parameter.Category")
    var categoryName: String

    @Property(title: "Intent.Parameter.Date")
    var date: Date

    @Property(title: "Intent.Parameter.Note")
    var note: String

    var displayRepresentation: DisplayRepresentation {
        let amountText = Decimal(amount).currencyString
        let dateText = date.formatted(date: .abbreviated, time: .shortened)
        return DisplayRepresentation(
            title: LocalizedStringResource("Intent.Record.Title", defaultValue: "\(amountText) for \(categoryName)"),
            subtitle: note.isEmpty
                ? LocalizedStringResource("Intent.Verbatim", defaultValue: "\(dateText)")
                : LocalizedStringResource("Intent.Record.Subtitle", defaultValue: "\(dateText), \(note)")
        )
    }

    var persistentID: PersistentIdentifier? {
        guard let data = Data(base64Encoded: id) else { return nil }
        return try? JSONDecoder().decode(PersistentIdentifier.self, from: data)
    }

    init(_ entry: SpendEntry, engine: BudgetEngine) {
        id = (try? JSONEncoder().encode(entry.persistentModelID).base64EncodedString()) ?? ""
        self.amount = entry.amount.doubleValue
        self.date = Calendar.current.isDate(entry.timestamp, inSameDayAs: entry.dayKey) ? entry.timestamp : entry.dayKey
        self.note = entry.note
        switch entry.scope {
        case .day:
            self.categoryName = engine.categoryName(for: entry)
        case .week:
            self.categoryName = OverallBudgetKind.weekly.label
        case .month:
            self.categoryName = OverallBudgetKind.monthly.label
        }
    }
}

struct SpendRecordEntityQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [SpendRecordEntity.ID]) async throws -> [SpendRecordEntity] {
        identifiers.compactMap { identifier in
            guard let data = Data(base64Encoded: identifier),
                  let id = try? JSONDecoder().decode(PersistentIdentifier.self, from: data) else { return nil }
            var descriptor = FetchDescriptor<SpendEntry>(predicate: #Predicate { $0.persistentModelID == id })
            descriptor.fetchLimit = 1
            guard let entry = (try? IntentData.context.fetch(descriptor))?.first else { return nil }
            return SpendRecordEntity(entry, engine: IntentData.engine(around: entry.dayKey))
        }
    }

    @MainActor
    func suggestedEntities() async throws -> [SpendRecordEntity] {
        var descriptor = FetchDescriptor<SpendEntry>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        descriptor.fetchLimit = 20
        let entries = (try? IntentData.context.fetch(descriptor)) ?? []
        let engine = IntentData.engine()
        return entries.map { SpendRecordEntity($0, engine: engine) }
    }
}
