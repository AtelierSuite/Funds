import SwiftUI

struct ReminderRow: View {
    @Bindable var reminder: TemplateReminder

    private var time: Binding<Date> {
        Binding {
            Calendar.current.date(
                bySettingHour: reminder.hour,
                minute: reminder.minute,
                second: 0,
                of: .now
            ) ?? .now
        } set: { date in
            let components = Calendar.current.dateComponents([.hour, .minute], from: date)
            reminder.hour = components.hour ?? reminder.hour
            reminder.minute = components.minute ?? reminder.minute
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            TextField("Notification.Reminder.Body", text: $reminder.message)
            DatePicker("Notifications.Time", selection: time, displayedComponents: .hourAndMinute)
                .labelsHidden()
        }
    }
}
