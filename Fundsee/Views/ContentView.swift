import SwiftData
import SwiftUI
import WidgetKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(BudgetStore.self) private var store

    @State private var navigation = AppNavigation.shared
    @State private var openedRecord: SpendEntry?

    var body: some View {
        TabView(selection: $navigation.selectedTab) {
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
        .sheet(item: $openedRecord) { entry in
            NavigationStack {
                SpendEntryEditorView(entry: entry)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(role: .cancel) { openedRecord = nil }
                        }
                    }
            }
        }
        .onChange(of: navigation.recordID, initial: true) { _, id in
            guard let id else { return }
            navigation.recordID = nil
            guard let persistentID = SpendRecordEntity.persistentID(from: id) else { return }
            var descriptor = FetchDescriptor<SpendEntry>(predicate: #Predicate { $0.persistentModelID == persistentID })
            descriptor.fetchLimit = 1
            openedRecord = (try? modelContext.fetch(descriptor))?.first
        }
        .task {
            DefaultData.seedIfNeeded(context: modelContext)
            DefaultData.seedSampleDataIfRequested(context: modelContext)
            FundsShortcuts.updateAppShortcutParameters()
        }
        .task(id: store.revision) {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            await NotificationService.reschedule(engine: store.engine())
            await SpotlightIndex.refresh()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.refresh()
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
