import Foundation

struct ReminderOccurrence: Equatable {
    let identifier: String
    let dateComponents: DateComponents
    let planName: String
    let message: String
}

extension BudgetEngine {
    static let reminderHorizonDays = 14

    func reminderOccurrences(from now: Date) -> [ReminderOccurrence] {
        (0..<Self.reminderHorizonDays).flatMap { offset -> [ReminderOccurrence] in
            guard let date = calendar.date(byAdding: .day, value: offset, to: day(now)),
                  let template = template(for: date) else { return [] }
            return template.sortedReminders.compactMap { occurrence(of: $0, on: date, in: template, after: now) }
        }
    }

    private func occurrence(
        of reminder: TemplateReminder,
        on date: Date,
        in template: BudgetTemplate,
        after now: Date
    ) -> ReminderOccurrence? {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = reminder.hour
        components.minute = reminder.minute
        guard let fireDate = calendar.date(from: components), fireDate > now else { return nil }
        let dayID = "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
        return ReminderOccurrence(
            identifier: "fundsee.reminder.\(reminder.uuid).\(dayID)",
            dateComponents: components,
            planName: template.name,
            message: reminder.message.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
