import SwiftData
import SwiftUI

struct NotificationSettingsView: View {
    var isEmbedded = false

    @AppStorage("notifyDaily") private var notifyDaily = false
    @AppStorage("notifyDailyHour") private var notifyDailyHour = 21
    @AppStorage("notifyWeekly") private var notifyWeekly = false
    @AppStorage("notifyMonthly") private var notifyMonthly = false

    @Environment(BudgetStore.self) private var store

    var body: some View {
        List {
            Section {
                Toggle("Notifications.Daily", isOn: $notifyDaily)
                if notifyDaily {
                    Picker("Notifications.Time", selection: $notifyDailyHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(String(format: "%02d:00", hour)).tag(hour)
                        }
                    }
                }
            } footer: {
                Text("Notifications.Daily.Footer")
            }
            Section {
                Toggle("Notifications.Weekly", isOn: $notifyWeekly)
            } footer: {
                Text("Notifications.Weekly.Footer")
            }
            Section {
                Toggle("Notifications.Monthly", isOn: $notifyMonthly)
            } footer: {
                Text("Notifications.Monthly.Footer")
            }
        }
        .navigationTitle(isEmbedded ? Text(verbatim: "") : Text("More.Notifications"))
        .toolbarTitleDisplayMode(.inline)
        .onChange(of: [notifyDaily, notifyWeekly, notifyMonthly]) {
            reschedule()
        }
        .onChange(of: notifyDailyHour) {
            reschedule()
        }
    }

    private func reschedule() {
        let engine = store.engine()
        Task {
            if notifyDaily || notifyWeekly || notifyMonthly {
                _ = await NotificationService.requestAuthorization()
            }
            await NotificationService.reschedule(engine: engine)
        }
    }
}
