import Foundation
import SwiftData
import Testing

@MainActor
struct CategoryIdentityTests {
    @Test func renamingKeepsSpendingAttached() throws {
        let fixture = try BudgetFixture()
        let day = fixture.date(2026, 6, 2)
        fixture.spend(6, on: day, to: fixture.officeLunch)
        fixture.officeLunch.name = "Team Lunch"
        let engine = try fixture.engine()
        #expect(engine.spent(on: day, category: fixture.officeLunch) == 6)
        #expect(engine.spentByCategory(on: day).map(\.name) == ["Team Lunch"])
    }

    @Test func sameNameInAnotherTemplateIsSeparate() throws {
        let fixture = try BudgetFixture()
        let day = fixture.date(2026, 6, 2)
        fixture.addCategory("Lunch", amount: 3, to: fixture.office)
        fixture.spend(6, on: day, to: fixture.officeLunch)
        let engine = try fixture.engine()
        let duplicate = try #require(fixture.office.sortedCategories.last)
        #expect(engine.spent(on: day, category: fixture.officeLunch) == 6)
        #expect(engine.spent(on: day, category: duplicate) == 0)
    }

    @Test func switchingPlanCarriesSpendingByName() throws {
        let fixture = try BudgetFixture()
        let day = fixture.date(2026, 6, 2)
        fixture.spend(6, on: day, to: fixture.officeLunch)
        fixture.spend(2, on: day, to: fixture.officeCoffee)
        fixture.override(day, with: fixture.home)
        let engine = try fixture.engine()
        #expect(engine.spent(on: day, category: fixture.homeLunch) == 6)
        #expect(engine.spent(on: day) == 8)
    }

    @Test func legacyEntriesMatchByName() throws {
        let fixture = try BudgetFixture()
        let day = fixture.date(2026, 6, 2)
        fixture.spend(5, on: day)
        let engine = try fixture.engine()
        #expect(engine.spent(on: day, category: fixture.officeLunch) == 5)
        #expect(engine.spent(on: day, category: fixture.officeCoffee) == 0)
    }

    @Test func breakdownUsesCurrentIcon() throws {
        let fixture = try BudgetFixture()
        let day = fixture.date(2026, 6, 2)
        fixture.officeLunch.iconName = "fork.knife"
        fixture.homeLunch.iconName = "house.fill"
        fixture.override(day, with: fixture.home)
        fixture.spend(5, on: day, to: fixture.homeLunch)
        let engine = try fixture.engine()
        #expect(engine.spentByCategory(on: day).map(\.iconName) == ["house.fill"])
    }

    @Test func backfillGivesLegacyRowsDeterministicIDs() throws {
        let fixture = try BudgetFixture()
        for category in [fixture.officeLunch, fixture.officeCoffee, fixture.homeLunch, fixture.offFun] {
            category?.uuid = ""
        }
        let tuesday = fixture.date(2026, 6, 2)
        let saturday = fixture.date(2026, 6, 6)
        let overridden = fixture.date(2026, 6, 3)
        fixture.override(overridden, with: fixture.home)
        let officeEntry = fixture.spend(4, on: tuesday)
        let homeEntry = fixture.spend(5, on: overridden)
        let offDayLunch = fixture.spend(6, on: saturday)
        let unknown = fixture.spend(7, on: tuesday, category: "Gone")
        let weekly = fixture.spend(8, on: tuesday, category: "Weekly", scope: .week)
        try fixture.context.save()

        DefaultData.backfillCategoryIDs(context: fixture.context)

        let expected = DefaultData.legacyCategoryID(templateUUID: fixture.office.uuid, sortOrder: 0, name: "Lunch")
        #expect(fixture.officeLunch.uuid == expected)
        #expect(fixture.homeLunch.uuid != fixture.officeLunch.uuid)
        #expect(officeEntry.categoryID == fixture.officeLunch.uuid)
        #expect(homeEntry.categoryID == fixture.homeLunch.uuid)
        #expect(offDayLunch.categoryID == fixture.officeLunch.uuid)
        #expect(unknown.categoryID == "")
        #expect(weekly.categoryID == "")
    }

    @Test func backfillLeavesLinkedRowsAlone() throws {
        let fixture = try BudgetFixture()
        let original = fixture.officeLunch.uuid
        let entry = fixture.spend(4, on: fixture.date(2026, 6, 2), to: fixture.homeLunch)
        try fixture.context.save()
        DefaultData.backfillCategoryIDs(context: fixture.context)
        #expect(fixture.officeLunch.uuid == original)
        #expect(entry.categoryID == fixture.homeLunch.uuid)
    }
}
