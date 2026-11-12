import AppIntents
import CoreSpotlight
import SwiftData

@MainActor
enum SpotlightIndex {
    static func refresh() async {
        var seen: Set<String> = []
        let plans = IntentData.templates().filter { seen.insert($0.uuid).inserted }.map(PlanEntity.init)
        let since = Calendar.current.date(byAdding: .year, value: -1, to: Calendar.current.startOfDay(for: .now)) ?? .distantPast
        let entries = (try? IntentData.context.fetch(FetchDescriptor<SpendEntry>(predicate: #Predicate { $0.dayKey >= since }))) ?? []
        let names = IntentData.categoryNames()
        let records = entries.map { SpendRecordEntity($0, categoryNames: names) }
        let index = CSSearchableIndex.default()
        do {
            try await index.deleteAppEntities(ofType: PlanEntity.self)
            try await index.deleteAppEntities(ofType: SpendRecordEntity.self)
            try await index.indexAppEntities(plans)
            try await index.indexAppEntities(records)
        } catch {
            return
        }
    }
}
