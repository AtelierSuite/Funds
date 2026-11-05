import Foundation
import SwiftData
import Testing

@MainActor
struct ReminderTests {
    let fixture: BudgetFixture

    init() throws {
        fixture = try BudgetFixture()
    }

    @discardableResult
    private func addReminder(
        to template: BudgetTemplate,
        hour: Int = 20,
        minute: Int = 0,
        message: String = "",
        createdAt: Date = .now
    ) -> TemplateReminder {
        let reminder = TemplateReminder(hour: hour, minute: minute, message: message)
        reminder.createdAt = createdAt
        reminder.template = template
        fixture.context.insert(reminder)
        return reminder
    }

    private func days(of occurrences: [ReminderOccurrence]) -> [Int] {
        occurrences.compactMap(\.dateComponents.day)
    }

    @Test func firesOnlyOnDaysUsingThePlan() throws {
        addReminder(to: fixture.off, hour: 9, minute: 30, message: "Check the weekend budget")
        let monday = fixture.date(2026, 6, 1, hour: 8)
        let occurrences = try fixture.engine().reminderOccurrences(from: monday)
        #expect(days(of: occurrences) == [6, 7, 13, 14])
        let first = try #require(occurrences.first)
        #expect(first.planName == "Off")
        #expect(first.message == "Check the weekend budget")
        #expect(first.dateComponents.hour == 9)
        #expect(first.dateComponents.minute == 30)
    }

    @Test func overrideMovesRemindersToTheOverridingPlan() throws {
        addReminder(to: fixture.office)
        addReminder(to: fixture.home, message: "Home day")
        fixture.override(fixture.date(2026, 6, 2), with: fixture.home)
        let occurrences = try fixture.engine().reminderOccurrences(from: fixture.date(2026, 6, 1, hour: 8))
        let tuesday = occurrences.filter { $0.dateComponents.day == 2 }
        #expect(tuesday.map(\.planName) == ["Home"])
    }

    @Test func skipsTimesAlreadyPassedToday() throws {
        addReminder(to: fixture.office, hour: 9)
        addReminder(to: fixture.office, hour: 20)
        let occurrences = try fixture.engine().reminderOccurrences(from: fixture.date(2026, 6, 1, hour: 12))
        let today = occurrences.filter { $0.dateComponents.day == 1 }
        #expect(today.compactMap(\.dateComponents.hour) == [20])
    }

    @Test func windowStaysUnderThePendingLimit() throws {
        for template in [fixture.office, fixture.off] {
            for hour in 1...TemplateReminder.limitPerPlan {
                addReminder(to: template, hour: hour)
            }
        }
        let occurrences = try fixture.engine().reminderOccurrences(from: fixture.date(2026, 6, 1))
        #expect(occurrences.count == BudgetEngine.reminderHorizonDays * TemplateReminder.limitPerPlan)
        #expect(Set(occurrences.map(\.identifier)).count == occurrences.count)
        #expect(occurrences.count + 3 <= 64)
    }

    @Test func blankMessageIsEmpty() throws {
        addReminder(to: fixture.office, message: "  \n ")
        let occurrences = try fixture.engine().reminderOccurrences(from: fixture.date(2026, 6, 1))
        #expect(occurrences.first?.message == "")
    }

    @Test func deletingAPlanDeletesItsReminders() throws {
        addReminder(to: fixture.home)
        try fixture.context.save()
        fixture.context.delete(fixture.home)
        try fixture.context.save()
        #expect(try fixture.context.fetchCount(FetchDescriptor<TemplateReminder>()) == 0)
    }

    @Test func syncTrimsToTheOldestReminders() throws {
        for offset in 0..<5 {
            addReminder(to: fixture.office, hour: offset, createdAt: Date(timeIntervalSince1970: Double(offset)))
        }
        try fixture.context.save()
        #expect(SyncDeduplication.mergeDuplicates(context: fixture.context))
        #expect(fixture.office.sortedReminders.map(\.hour) == [0, 1, 2])
    }

    @Test func mergingDuplicatePlansKeepsReminders() throws {
        let duplicate = BudgetTemplate(name: "Office", iconName: "building.2.fill")
        duplicate.uuid = fixture.office.uuid
        duplicate.createdAt = fixture.office.createdAt.addingTimeInterval(60)
        fixture.context.insert(duplicate)
        addReminder(to: fixture.office, hour: 8, createdAt: Date(timeIntervalSince1970: 1))
        addReminder(to: duplicate, hour: 9, createdAt: Date(timeIntervalSince1970: 2))
        try fixture.context.save()
        SyncDeduplication.mergeDuplicates(context: fixture.context)
        #expect(fixture.office.sortedReminders.map(\.hour) == [8, 9])
    }
}
