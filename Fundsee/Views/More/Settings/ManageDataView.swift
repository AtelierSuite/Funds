import SwiftData
import SwiftUI
import UserNotifications
import WidgetKit

struct ManageDataView: View {
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = true
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @Environment(\.modelContext) private var modelContext

    @State private var isConfirmingDeletion = false

    var body: some View {
        List {
            Section {
                Button("ManageData.DeleteAll", role: .destructive) {
                    isConfirmingDeletion = true
                }
            }
        }
        .navigationTitle("More.ManageData")
        .toolbarTitleDisplayMode(.inline)
        .alert("ManageData.DeleteAll.Alert.Title", isPresented: $isConfirmingDeletion) {
            Button(role: .cancel) {}
            Button("ManageData.DeleteAll.Alert.Delete", role: .destructive) {
                deleteAllData()
            }
        } message: {
            Text(iCloudSyncEnabled ? "ManageData.DeleteAll.Alert.Message.ICloud" : "ManageData.DeleteAll.Alert.Message")
        }
    }

    private func deleteAllData() {
        deleteAll(SpendEntry.self)
        deleteAll(DayOverride.self)
        deleteAll(TemplateCategory.self)
        deleteAll(BudgetTemplate.self)
        deleteAll(PlanSettings.self)
        try? modelContext.save()

        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [NotificationService.dailyID, NotificationService.weeklyID, NotificationService.monthlyID]
        )
        WidgetCenter.shared.reloadAllTimelines()
        hasCompletedOnboarding = false
    }

    private func deleteAll<Model: PersistentModel>(_ type: Model.Type) {
        for model in (try? modelContext.fetch(FetchDescriptor<Model>())) ?? [] {
            modelContext.delete(model)
        }
    }
}
