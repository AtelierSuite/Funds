import CoreData
import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class BudgetStore {
    let context: ModelContext
    private(set) var revision = 0

    @ObservationIgnored private var engines: [Date: BudgetEngine] = [:]

    private static let windowPadding = 14

    init(context: ModelContext) {
        self.context = context
        for name in [ModelContext.didSave, .NSPersistentStoreRemoteChange] {
            Task { [weak self] in
                for await _ in NotificationCenter.default.notifications(named: name) {
                    guard let self else { return }
                    self.invalidate()
                }
            }
        }
    }

    func invalidate() {
        engines.removeAll()
        revision += 1
    }

    func engine(around date: Date = .now) -> BudgetEngine {
        _ = revision
        let calendar = Calendar.current
        let year = calendar.dateInterval(of: .year, for: date)
            ?? DateInterval(start: calendar.startOfDay(for: date), duration: 366 * 86_400)
        if let cached = engines[year.start] { return cached }
        let engine = makeEngine(year: year, calendar: calendar)
        engines[year.start] = engine
        return engine
    }

    func recentAmounts(category: String, limit: Int = 3) -> [Decimal] {
        var descriptor = FetchDescriptor<SpendEntry>(
            predicate: #Predicate { $0.categoryName == category },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 50
        let entries = (try? context.fetch(descriptor)) ?? []
        return BudgetEngine.recentAmounts(in: entries, limit: limit)
    }

    private func makeEngine(year: DateInterval, calendar: Calendar) -> BudgetEngine {
        let start = calendar.date(byAdding: .day, value: -Self.windowPadding, to: year.start) ?? year.start
        let end = calendar.date(byAdding: .day, value: Self.windowPadding, to: year.end) ?? year.end
        let entries = FetchDescriptor<SpendEntry>(predicate: #Predicate { $0.dayKey >= start && $0.dayKey < end })
        let overrides = FetchDescriptor<DayOverride>(predicate: #Predicate { $0.dayKey >= start && $0.dayKey < end })
        return BudgetEngine(
            templates: (try? context.fetch(FetchDescriptor<BudgetTemplate>())) ?? [],
            overrides: (try? context.fetch(overrides)) ?? [],
            entries: (try? context.fetch(entries)) ?? [],
            settings: (try? context.fetch(FetchDescriptor<PlanSettings>()))?.first,
            calendar: calendar
        )
    }
}
