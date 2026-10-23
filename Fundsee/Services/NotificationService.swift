import Foundation
import UserNotifications

@MainActor
enum NotificationService {
    static let dailyID = "fundsee.report.daily"
    static let weeklyID = "fundsee.report.weekly"
    static let monthlyID = "fundsee.report.monthly"

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
    }

    static func reschedule(engine: BudgetEngine) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [dailyID, weeklyID, monthlyID])
        let defaults = UserDefaults.standard

        guard await center.notificationSettings().authorizationStatus == .authorized else { return }

        if defaults.bool(forKey: "notifyDaily") {
            let hour = defaults.object(forKey: "notifyDailyHour") as? Int ?? 21
            var components = DateComponents()
            components.hour = hour
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Notification.Daily.Title", defaultValue: "Daily Report")
            let remaining = engine.remaining(for: .now)
            content.body = remaining >= 0
                ? String(localized: "Notification.Daily.Body.Left", defaultValue: "You have \(remaining.currencyString) left today. Tap to review your day.")
                : String(localized: "Notification.Daily.Body.Over", defaultValue: "You're \((-remaining).currencyString) over today's budget. Tap to review your day.")
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            try? await center.add(UNNotificationRequest(identifier: dailyID, content: content, trigger: trigger))
        }

        if defaults.bool(forKey: "notifyWeekly") {
            var components = DateComponents()
            components.weekday = 1
            components.hour = 20
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Notification.Weekly.Title", defaultValue: "Weekly Report")
            let week = engine.weekInterval(containing: .now)
            let budget = engine.weekBudget(containing: .now)
            let used = engine.weekSpent(in: week)
            content.body = String(localized: "Notification.Weekly.Body", defaultValue: "This week: \(used.currencyString) of \(budget.currencyString) used. Tap for the full picture.")
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            try? await center.add(UNNotificationRequest(identifier: weeklyID, content: content, trigger: trigger))
        }

        if defaults.bool(forKey: "notifyMonthly") {
            var components = DateComponents()
            components.day = 1
            components.hour = 9
            let content = UNMutableNotificationContent()
            content.title = String(localized: "Notification.Monthly.Title", defaultValue: "Monthly Report")
            content.body = String(localized: "Notification.Monthly.Body", defaultValue: "A new month begins. See how last month went and what's budgeted ahead.")
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            try? await center.add(UNNotificationRequest(identifier: monthlyID, content: content, trigger: trigger))
        }
    }
}
