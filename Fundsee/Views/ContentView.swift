import SwiftData
import SwiftUI
import WidgetKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(BudgetStore.self) private var store

    @State private var selectedTab = UserDefaults.standard.string(forKey: "initialTab") ?? "today"

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Tab.Today", systemImage: "sun.max.fill", value: "today") {
                TodayView()
            }
            Tab("Tab.Week", systemImage: "calendar.day.timeline.left", value: "week") {
                WeekView()
            }
            Tab("Tab.Month", systemImage: "calendar", value: "month") {
                MonthView()
            }
            Tab("Tab.Year", systemImage: "chart.bar.xaxis", value: "year") {
                YearView()
            }
            Tab("Tab.More", systemImage: "ellipsis", value: "more") {
                MoreView()
            }
        }
        .task {
            DefaultData.seedIfNeeded(context: modelContext)
            DefaultData.seedSampleDataIfRequested(context: modelContext)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.refresh()
                let engine = store.engine()
                Task { await NotificationService.reschedule(engine: engine) }
            } else {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: AppGroup.schema,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
    )
    ContentView()
        .modelContainer(container)
        .environment(BudgetStore(context: container.mainContext))
}
