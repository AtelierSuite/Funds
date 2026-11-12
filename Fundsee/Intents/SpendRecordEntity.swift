import AppIntents
import CoreSpotlight
import SwiftData

struct SpendRecordEntity: IndexedEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Intent.Parameter.Record")
    static let defaultQuery = SpendRecordEntityQuery()
    static let activityType = "com.tsubuzaki.Fundsee.record"

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

    var attributeSet: CSSearchableItemAttributeSet {
        let attributes = defaultAttributeSet
        attributes.keywords = [categoryName, note].filter { !$0.isEmpty }
        attributes.contentCreationDate = date
        return attributes
    }

    var persistentID: PersistentIdentifier? {
        Self.persistentID(from: id)
    }

    static func id(for entry: SpendEntry) -> String {
        (try? JSONEncoder().encode(entry.persistentModelID).base64EncodedString()) ?? ""
    }

    static func persistentID(from id: String) -> PersistentIdentifier? {
        guard let data = Data(base64Encoded: id) else { return nil }
        return try? JSONDecoder().decode(PersistentIdentifier.self, from: data)
    }

    init(_ entry: SpendEntry, categoryNames: [String: String]) {
        id = Self.id(for: entry)
        self.amount = entry.amount.doubleValue
        self.date = Calendar.current.isDate(entry.timestamp, inSameDayAs: entry.dayKey) ? entry.timestamp : entry.dayKey
        self.note = entry.note
        switch entry.scope {
        case .day:
            self.categoryName = categoryNames[entry.categoryID] ?? entry.categoryName
        case .week:
            self.categoryName = OverallBudgetKind.weekly.label
        case .month:
            self.categoryName = OverallBudgetKind.monthly.label
        }
    }

    @MainActor
    init(_ entry: SpendEntry) {
        self.init(entry, categoryNames: IntentData.categoryNames())
    }
}

struct SpendRecordFilter {
    var earliestDay: Date?
    var latestDay: Date?
    let matches: (SpendRecordEntity) -> Bool

    static func date(after date: Date) -> SpendRecordFilter {
        SpendRecordFilter(earliestDay: Calendar.current.startOfDay(for: date)) { $0.date > date }
    }

    static func date(before date: Date) -> SpendRecordFilter {
        SpendRecordFilter(latestDay: date) { $0.date < date }
    }

    static func date(between start: Date, and end: Date) -> SpendRecordFilter {
        let lower = min(start, end)
        let upper = max(start, end)
        return SpendRecordFilter(earliestDay: Calendar.current.startOfDay(for: lower), latestDay: upper) {
            $0.date >= lower && $0.date <= upper
        }
    }

    static func text(_ keyPath: KeyPath<SpendRecordEntity, String>, contains value: String) -> SpendRecordFilter {
        SpendRecordFilter { $0[keyPath: keyPath].localizedStandardContains(value) }
    }

    static func text(_ keyPath: KeyPath<SpendRecordEntity, String>, equals value: String) -> SpendRecordFilter {
        SpendRecordFilter { $0[keyPath: keyPath].localizedCaseInsensitiveCompare(value) == .orderedSame }
    }
}

struct SpendRecordEntityQuery: EntityPropertyQuery {
    static let properties = QueryProperties {
        Property(\SpendRecordEntity.$date) {
            IsBetweenComparator { SpendRecordFilter.date(between: $0, and: $1) }
            GreaterThanComparator { SpendRecordFilter.date(after: $0) }
            LessThanComparator { SpendRecordFilter.date(before: $0) }
        }
        Property(\SpendRecordEntity.$amount) {
            EqualToComparator { value in SpendRecordFilter { abs($0.amount - value) < 0.005 } }
            GreaterThanComparator { value in SpendRecordFilter { $0.amount > value } }
            LessThanComparator { value in SpendRecordFilter { $0.amount < value } }
        }
        Property(\SpendRecordEntity.$categoryName) {
            EqualToComparator { SpendRecordFilter.text(\.categoryName, equals: $0) }
            ContainsComparator { SpendRecordFilter.text(\.categoryName, contains: $0) }
        }
        Property(\SpendRecordEntity.$note) {
            EqualToComparator { SpendRecordFilter.text(\.note, equals: $0) }
            ContainsComparator { SpendRecordFilter.text(\.note, contains: $0) }
        }
    }

    static let sortingOptions = SortingOptions {
        SortableBy(\SpendRecordEntity.$date)
        SortableBy(\SpendRecordEntity.$amount)
    }

    static let findIntentDescription: IntentDescription? = IntentDescription("Intent.FindRecords.Description")

    @MainActor
    func entities(for identifiers: [SpendRecordEntity.ID]) async throws -> [SpendRecordEntity] {
        let names = IntentData.categoryNames()
        return identifiers.compactMap { identifier in
            guard let id = SpendRecordEntity.persistentID(from: identifier) else { return nil }
            var descriptor = FetchDescriptor<SpendEntry>(predicate: #Predicate { $0.persistentModelID == id })
            descriptor.fetchLimit = 1
            guard let entry = (try? IntentData.context.fetch(descriptor))?.first else { return nil }
            return SpendRecordEntity(entry, categoryNames: names)
        }
    }

    @MainActor
    func suggestedEntities() async throws -> [SpendRecordEntity] {
        var descriptor = FetchDescriptor<SpendEntry>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        descriptor.fetchLimit = 20
        let entries = (try? IntentData.context.fetch(descriptor)) ?? []
        let names = IntentData.categoryNames()
        return entries.map { SpendRecordEntity($0, categoryNames: names) }
    }

    @MainActor
    func entities(
        matching comparators: [SpendRecordFilter],
        mode: ComparatorMode,
        sortedBy: [Sort<SpendRecordEntity>],
        limit: Int?
    ) async throws -> [SpendRecordEntity] {
        var earliest: Date?
        var latest: Date?
        if mode == .and {
            earliest = comparators.compactMap(\.earliestDay).max()
            latest = comparators.compactMap(\.latestDay).min()
        }
        let descriptor: FetchDescriptor<SpendEntry>
        switch (earliest, latest) {
        case let (start?, end?):
            descriptor = FetchDescriptor(predicate: #Predicate { $0.dayKey >= start && $0.dayKey <= end })
        case let (start?, nil):
            descriptor = FetchDescriptor(predicate: #Predicate { $0.dayKey >= start })
        case let (nil, end?):
            descriptor = FetchDescriptor(predicate: #Predicate { $0.dayKey <= end })
        case (nil, nil):
            descriptor = FetchDescriptor()
        }
        let names = IntentData.categoryNames()
        var records = ((try? IntentData.context.fetch(descriptor)) ?? []).map { SpendRecordEntity($0, categoryNames: names) }
        if !comparators.isEmpty {
            records = records.filter { record in
                mode == .and
                    ? comparators.allSatisfy { $0.matches(record) }
                    : comparators.contains { $0.matches(record) }
            }
        }
        records.sort { lhs, rhs in
            for sort in sortedBy {
                let ascending = sort.order == .ascending
                switch sort.by {
                case \.$amount where lhs.amount != rhs.amount:
                    return ascending ? lhs.amount < rhs.amount : lhs.amount > rhs.amount
                case \.$date where lhs.date != rhs.date:
                    return ascending ? lhs.date < rhs.date : lhs.date > rhs.date
                default:
                    continue
                }
            }
            return lhs.date > rhs.date
        }
        if let limit {
            records = Array(records.prefix(limit))
        }
        return records
    }
}
