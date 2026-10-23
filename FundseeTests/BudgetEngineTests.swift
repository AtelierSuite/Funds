import Foundation
import Testing

@MainActor
struct DateHelperTests {
    @Test func weekFollowsCalendarFirstWeekday() throws {
        let monday = try BudgetFixture(firstWeekday: 2)
        let mondayWeek = try monday.engine().weekInterval(containing: monday.date(2026, 6, 3))
        #expect(mondayWeek.start == monday.date(2026, 6, 1))
        #expect(mondayWeek.end == monday.date(2026, 6, 8))

        let sunday = try BudgetFixture(firstWeekday: 1)
        let sundayWeek = try sunday.engine().weekInterval(containing: sunday.date(2026, 6, 3))
        #expect(sundayWeek.start == sunday.date(2026, 5, 31))
        #expect(sundayWeek.end == sunday.date(2026, 6, 7))
    }

    @Test func daysInWeekAreHalfOpen() throws {
        let fixture = try BudgetFixture()
        let engine = try fixture.engine()
        let days = engine.days(in: engine.weekInterval(containing: fixture.date(2026, 6, 3)))
        #expect(days.count == 7)
        #expect(days.first == fixture.date(2026, 6, 1))
        #expect(days.last == fixture.date(2026, 6, 7))
    }

    @Test func weeksInMonthCoverEveryDay() throws {
        let fixture = try BudgetFixture()
        let engine = try fixture.engine()
        let weeks = engine.weeks(inMonthContaining: fixture.date(2026, 6, 15))
        #expect(weeks.map(\.start) == [1, 8, 15, 22, 29].map { fixture.date(2026, 6, $0) })

        let month = engine.monthInterval(containing: fixture.date(2026, 6, 15))
        #expect(engine.weekStarts(in: month).count == 5)

        let july = engine.monthInterval(containing: fixture.date(2026, 7, 1))
        #expect(engine.weekStarts(in: july).map { fixture.calendar.component(.day, from: $0) } == [6, 13, 20, 27])
        #expect(engine.weeks(inMonthContaining: fixture.date(2026, 7, 1)).first?.start == fixture.date(2026, 6, 29))
    }
}

@MainActor
struct TemplateResolutionTests {
    @Test func weekdayPlanPicksTemplate() throws {
        let fixture = try BudgetFixture()
        let engine = try fixture.engine()
        #expect(engine.template(for: fixture.date(2026, 6, 1)) === fixture.office)
        #expect(engine.template(for: fixture.date(2026, 6, 6)) === fixture.off)
        #expect(engine.template(for: fixture.date(2026, 6, 7)) === fixture.off)
        #expect(engine.baseBudget(for: fixture.date(2026, 6, 1)) == 15)
        #expect(engine.baseBudget(for: fixture.date(2026, 6, 7)) == 20)
    }

    @Test func overrideWinsOverWeekdayPlan() throws {
        let fixture = try BudgetFixture()
        fixture.override(fixture.date(2026, 6, 2), with: fixture.home)
        let engine = try fixture.engine()
        #expect(engine.template(for: fixture.date(2026, 6, 2, hour: 15)) === fixture.home)
        #expect(engine.baseBudget(for: fixture.date(2026, 6, 2)) == 8)
        #expect(engine.template(for: fixture.date(2026, 6, 3)) === fixture.office)
    }

    @Test func unassignedWeekdayHasNoBudget() throws {
        let fixture = try BudgetFixture()
        fixture.settings.setTemplateUUID(nil, forWeekday: 4)
        let engine = try fixture.engine()
        #expect(engine.template(for: fixture.date(2026, 6, 3)) == nil)
        #expect(engine.baseBudget(for: fixture.date(2026, 6, 3)) == 0)
    }

    @Test func missingSettingsMeansNoBudget() throws {
        let fixture = try BudgetFixture()
        var engine = try fixture.engine()
        engine = BudgetEngine(templates: engine.templates, overrides: [], entries: [], settings: nil, calendar: fixture.calendar)
        #expect(engine.baseBudget(for: fixture.date(2026, 6, 1)) == 0)
        #expect(engine.carryover == .leaveAsIs)
        #expect(engine.weekBudget(containing: fixture.date(2026, 6, 1)) == 0)
    }
}

@MainActor
struct SpendingTests {
    @Test func daySpendingOnlyCountsDayScope() throws {
        let fixture = try BudgetFixture()
        let day = fixture.date(2026, 6, 2)
        fixture.spend(4, on: day)
        fixture.spend(3.5, on: day, category: "Coffee")
        fixture.spend(30, on: day, category: "Weekly", scope: .week)
        fixture.spend(40, on: day, category: "Monthly", scope: .month)
        let engine = try fixture.engine()
        #expect(engine.spent(on: day) == 7.5)
        #expect(engine.spent(on: day, category: "Lunch") == 4)
        #expect(engine.spent(on: day, category: "Coffee") == 3.5)
        #expect(engine.remaining(for: day) == 7.5)
    }

    @Test func intervalSpendingExcludesTheNextWeekStart() throws {
        let fixture = try BudgetFixture()
        fixture.spend(5, on: fixture.date(2026, 5, 31))
        fixture.spend(6, on: fixture.date(2026, 6, 1))
        fixture.spend(7, on: fixture.date(2026, 6, 7))
        fixture.spend(100, on: fixture.date(2026, 6, 8))
        let engine = try fixture.engine()
        let week = engine.weekInterval(containing: fixture.date(2026, 6, 3))
        #expect(engine.spent(in: week) == 13)
    }

    @Test func spendingByScopeAndCategory() throws {
        let fixture = try BudgetFixture()
        let day = fixture.date(2026, 6, 2)
        fixture.spend(4, on: day)
        fixture.spend(6, on: fixture.date(2026, 6, 3))
        fixture.spend(2, on: day, category: "Coffee")
        fixture.spend(30, on: day, category: "Weekly", scope: .week)
        let engine = try fixture.engine()
        let week = engine.weekInterval(containing: day)
        #expect(engine.spent(in: week, scope: .day) == 12)
        #expect(engine.spent(in: week, scope: .week) == 30)
        #expect(engine.spent(in: week, category: "Lunch") == 10)
        let breakdown = engine.spentByCategory(in: week, scope: .day)
        #expect(breakdown.map(\.name) == ["Lunch", "Coffee"])
        #expect(breakdown.map(\.amount) == [10, 2])
    }

    @Test func breakdownTiesSortByName() throws {
        let fixture = try BudgetFixture()
        let day = fixture.date(2026, 6, 2)
        fixture.spend(5, on: day, category: "Lunch")
        fixture.spend(5, on: day, category: "Coffee")
        let engine = try fixture.engine()
        #expect(engine.spentByCategory(on: day).map(\.name) == ["Coffee", "Lunch"])
    }

    @Test func recentAmountsAreDistinctAndNewestFirst() throws {
        let fixture = try BudgetFixture()
        let day = fixture.date(2026, 6, 2)
        fixture.spend(4, on: day, at: fixture.date(2026, 6, 2, hour: 8))
        fixture.spend(6, on: day, at: fixture.date(2026, 6, 2, hour: 9))
        fixture.spend(4, on: day, at: fixture.date(2026, 6, 2, hour: 10))
        fixture.spend(9, on: day, at: fixture.date(2026, 6, 2, hour: 11))
        fixture.spend(1, on: day, at: fixture.date(2026, 6, 2, hour: 7))
        fixture.spend(50, on: day, category: "Coffee", at: fixture.date(2026, 6, 2, hour: 12))
        let lunch = try fixture.engine().entries.filter { $0.categoryName == "Lunch" }
        #expect(BudgetEngine.recentAmounts(in: lunch) == [9, 4, 6])
        #expect(BudgetEngine.recentAmounts(in: lunch, limit: 0) == [])
    }
}

@MainActor
struct CarryoverTests {
    @Test func leaveAsIsKeepsEachDayIndependent() throws {
        let fixture = try BudgetFixture()
        fixture.spend(1, on: fixture.date(2026, 6, 1))
        let engine = try fixture.engine()
        #expect(engine.effectiveBudget(for: fixture.date(2026, 6, 2)) == 15)
    }

    @Test func nextDayCarriesLeftoverForward() throws {
        let fixture = try BudgetFixture()
        fixture.settings.carryover = .nextDay
        fixture.spend(10, on: fixture.date(2026, 6, 1))
        fixture.spend(20, on: fixture.date(2026, 6, 2))
        let engine = try fixture.engine()
        #expect(engine.effectiveBudget(for: fixture.date(2026, 6, 1)) == 15)
        #expect(engine.effectiveBudget(for: fixture.date(2026, 6, 2)) == 20)
        #expect(engine.remaining(for: fixture.date(2026, 6, 2)) == 0)
        #expect(engine.effectiveBudget(for: fixture.date(2026, 6, 3)) == 15)
    }

    @Test func nextDayCarriesOverspendForward() throws {
        let fixture = try BudgetFixture()
        fixture.settings.carryover = .nextDay
        fixture.spend(25, on: fixture.date(2026, 6, 1))
        let engine = try fixture.engine()
        #expect(engine.effectiveBudget(for: fixture.date(2026, 6, 2)) == 5)
    }

    @Test func nextDayIgnoresWeekAndMonthScopedSpending() throws {
        let fixture = try BudgetFixture()
        fixture.settings.carryover = .nextDay
        fixture.spend(50, on: fixture.date(2026, 6, 1), category: "Weekly", scope: .week)
        fixture.spend(50, on: fixture.date(2026, 6, 1), category: "Monthly", scope: .month)
        let engine = try fixture.engine()
        #expect(engine.effectiveBudget(for: fixture.date(2026, 6, 2)) == 30)
    }

    @Test func nextDayResetsAtWeekBoundary() throws {
        let fixture = try BudgetFixture()
        fixture.settings.carryover = .nextDay
        fixture.spend(0.5, on: fixture.date(2026, 6, 6))
        let engine = try fixture.engine()
        #expect(engine.effectiveBudget(for: fixture.date(2026, 6, 7)) > 20)
        #expect(engine.effectiveBudget(for: fixture.date(2026, 6, 8)) == 15)
    }

    @Test func weekBudgetSumsDaysAndWeeklyExtra() throws {
        let fixture = try BudgetFixture()
        fixture.settings.weeklyOverallBudget = 30
        let engine = try fixture.engine()
        #expect(engine.weekBudget(containing: fixture.date(2026, 6, 3)) == 145)
    }

    @Test func nextWeekCarriesLastWeeksLeftover() throws {
        let fixture = try BudgetFixture()
        fixture.settings.carryover = .nextWeek
        fixture.spend(100, on: fixture.date(2026, 6, 2))
        let engine = try fixture.engine()
        let next = fixture.date(2026, 6, 10)
        #expect(engine.weekBudget(containing: next) == 130)
        #expect(engine.weekBudget(containing: next, includeCarry: false) == 115)
    }

    @Test func nextWeekCarriesLastWeeksOverspend() throws {
        let fixture = try BudgetFixture()
        fixture.settings.carryover = .nextWeek
        fixture.settings.weeklyOverallBudget = 10
        fixture.spend(120, on: fixture.date(2026, 6, 2))
        fixture.spend(20, on: fixture.date(2026, 6, 3), category: "Weekly", scope: .week)
        let engine = try fixture.engine()
        #expect(engine.weekBudget(containing: fixture.date(2026, 6, 10)) == 110)
    }

    @Test func monthScopedSpendingDoesNotEatIntoNextWeek() throws {
        let fixture = try BudgetFixture()
        fixture.settings.carryover = .nextWeek
        fixture.settings.monthlyOverallBudget = 200
        fixture.spend(100, on: fixture.date(2026, 6, 2))
        fixture.spend(150, on: fixture.date(2026, 6, 3), category: "Monthly", scope: .month)
        let engine = try fixture.engine()
        #expect(engine.weekBudget(containing: fixture.date(2026, 6, 10)) == 130)
    }

    @Test func weekSpentLeavesOutMonthScope() throws {
        let fixture = try BudgetFixture()
        let day = fixture.date(2026, 6, 2)
        fixture.spend(10, on: day)
        fixture.spend(20, on: day, category: "Weekly", scope: .week)
        fixture.spend(40, on: day, category: "Monthly", scope: .month)
        fixture.spend(80, on: fixture.date(2026, 6, 8))
        let engine = try fixture.engine()
        let week = engine.weekInterval(containing: day)
        #expect(engine.weekSpent(in: week) == 30)
        #expect(engine.spent(in: week) == 70)
    }

    @Test func nextWeekReachesBackExactlyOneWeek() throws {
        let fixture = try BudgetFixture()
        fixture.settings.carryover = .nextWeek
        fixture.spend(15, on: fixture.date(2026, 6, 1))
        fixture.spend(115, on: fixture.date(2026, 6, 8))
        let engine = try fixture.engine()
        #expect(engine.weekBudget(containing: fixture.date(2026, 6, 15)) == 115)
    }

    @Test func nextWeekLooksAtThePreviousCalendarWeek() throws {
        let fixture = try BudgetFixture()
        fixture.settings.carryover = .nextWeek
        fixture.spend(15, on: fixture.date(2026, 6, 7))
        fixture.spend(15, on: fixture.date(2026, 6, 8))
        let engine = try fixture.engine()
        #expect(engine.weekBudget(containing: fixture.date(2026, 6, 14)) == 215)
    }
}

@MainActor
struct MonthBudgetTests {
    @Test func monthBudgetAddsExtras() throws {
        let fixture = try BudgetFixture()
        let engine = try fixture.engine()
        #expect(engine.monthBudget(containing: fixture.date(2026, 6, 15)) == 490)

        fixture.settings.weeklyOverallBudget = 10
        fixture.settings.monthlyOverallBudget = 50
        let withExtras = try fixture.engine()
        #expect(withExtras.monthBudget(containing: fixture.date(2026, 6, 15)) == 590)
    }

    @Test func monthBudgetFollowsOverrides() throws {
        let fixture = try BudgetFixture()
        fixture.override(fixture.date(2026, 6, 2), with: fixture.home)
        fixture.override(fixture.date(2026, 6, 6), with: fixture.office)
        let engine = try fixture.engine()
        #expect(engine.monthBudget(containing: fixture.date(2026, 6, 1)) == 478)
    }

    @Test func monthBudgetToDateCountsElapsedDaysAndWeekStarts() throws {
        let fixture = try BudgetFixture()
        fixture.settings.weeklyOverallBudget = 10
        fixture.settings.monthlyOverallBudget = 50
        let engine = try fixture.engine()
        let budget = engine.monthBudgetToDate(containing: fixture.date(2026, 6, 1), asOf: fixture.date(2026, 6, 9, hour: 18))
        #expect(budget == 215)
    }

    @Test func monthSpendingIncludesEveryScope() throws {
        let fixture = try BudgetFixture()
        fixture.spend(5, on: fixture.date(2026, 5, 31))
        fixture.spend(10, on: fixture.date(2026, 6, 1))
        fixture.spend(20, on: fixture.date(2026, 6, 15), category: "Weekly", scope: .week)
        fixture.spend(30, on: fixture.date(2026, 6, 30), category: "Monthly", scope: .month)
        fixture.spend(40, on: fixture.date(2026, 7, 1))
        let engine = try fixture.engine()
        let month = engine.monthInterval(containing: fixture.date(2026, 6, 1))
        #expect(engine.spent(in: month) == 60)
        #expect(engine.spent(in: month, scope: .month) == 30)
    }

    @Test func weeklyExtraSpentOnlyCountsWeeksStartingInMonth() throws {
        let fixture = try BudgetFixture()
        fixture.spend(7, on: fixture.date(2026, 6, 30), category: "Weekly", scope: .week)
        fixture.spend(9, on: fixture.date(2026, 7, 2), category: "Weekly", scope: .week)
        fixture.spend(3, on: fixture.date(2026, 7, 7), category: "Weekly", scope: .week)
        let engine = try fixture.engine()
        #expect(engine.weeklyExtraSpent(in: engine.monthInterval(containing: fixture.date(2026, 6, 1))) == 16)
        #expect(engine.weeklyExtraSpent(in: engine.monthInterval(containing: fixture.date(2026, 7, 1))) == 3)
    }
}
