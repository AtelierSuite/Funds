import WidgetKit

struct TodayBudgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> BudgetEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (BudgetEntry) -> Void) {
        completion(makeTodayBudgetEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BudgetEntry>) -> Void) {
        let now = Date.now
        let calendar = Calendar.current
        let refresh = calendar.date(byAdding: .minute, value: 30, to: now) ?? now.addingTimeInterval(1800)
        var entries = [makeTodayBudgetEntry(at: now)]
        if let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) {
            entries.append(makeTodayBudgetEntry(at: midnight))
        }
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }
}
