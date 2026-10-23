import CoreData
import Foundation
import Observation
import SwiftData
import WidgetKit

@MainActor
@Observable
final class BudgetStore {
    let context: ModelContext
    private(set) var revision = 0

    @ObservationIgnored private var engines: [Date: BudgetEngine] = [:]

    private static let windowPadding = 14

    init(context: ModelContext) {
        self.context = context
        Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: ModelContext.didSave) {
                guard let self else { return }
                self.invalidate()
            }
        }
        Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .NSPersistentStoreRemoteChange) {
                guard let self else { return }
                self.refresh()
            }
        }
    }

    func refresh() {
        SyncDeduplication.mergeDuplicates(context: context)
        invalidate()
    }

    func invalidate() {
        engines.removeAll()
        revision += 1
        WidgetCenter.shared.reloadAllTimelines()
    }

    func engine(around date: Date = .now) -> BudgetEngine {
        _ = revision
        let calendar = Calendar.current
        let year = calendar.dateInterval(of: .year, for: date)
            ?? DateInterval(start: calendar.startOfDay(for: date), duration: 366 * 86_400)
        if let cached = engines[year.start] { return cached }
        let engine = Self.loadEngine(context: context, year: year, calendar: calendar)
        engines[year.start] = engine
        return engine
    }

    func recentAmounts(categoryID: String?, name: String, scope: SpendScope = .day, limit: Int = 3) -> [Decimal] {
        let scopeRaw = scope.rawValue
        let id = categoryID ?? ""
        let predicate: Predicate<SpendEntry>
        if scope != .day {
            predicate = #Predicate<SpendEntry> { $0.scopeRaw == scopeRaw }
        } else if id.isEmpty {
            predicate = #Predicate<SpendEntry> { $0.scopeRaw == scopeRaw && $0.categoryName == name }
        } else {
            predicate = #Predicate<SpendEntry> { $0.scopeRaw == scopeRaw && ($0.categoryID == id || $0.categoryName == name) }
        }
        var descriptor = FetchDescriptor<SpendEntry>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 50
        let entries = (try? context.fetch(descriptor)) ?? []
        return BudgetEngine.recentAmounts(in: entries, limit: limit)
    }

    static func loadEngine(context: ModelContext, around date: Date) -> BudgetEngine {
        let calendar = Calendar.current
        let year = calendar.dateInterval(of: .year, for: date)
            ?? DateInterval(start: calendar.startOfDay(for: date), duration: 366 * 86_400)
        return loadEngine(context: context, year: year, calendar: calendar)
    }

    private static func loadEngine(context: ModelContext, year: DateInterval, calendar: Calendar) -> BudgetEngine {
        let start = calendar.date(byAdding: .day, value: -windowPadding, to: year.start) ?? year.start
        let end = calendar.date(byAdding: .day, value: windowPadding, to: year.end) ?? year.end
        let entries = FetchDescriptor<SpendEntry>(predicate: #Predicate { $0.dayKey >= start && $0.dayKey < end })
        let overrides = FetchDescriptor<DayOverride>(predicate: #Predicate { $0.dayKey >= start && $0.dayKey < end })
        return BudgetEngine(
            templates: (try? context.fetch(FetchDescriptor<BudgetTemplate>())) ?? [],
            overrides: (try? context.fetch(overrides)) ?? [],
            entries: (try? context.fetch(entries)) ?? [],
            settings: ((try? context.fetch(FetchDescriptor<PlanSettings>())) ?? []).primary,
            calendar: calendar
        )
    }
}
