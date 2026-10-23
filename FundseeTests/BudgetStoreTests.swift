import Foundation
import SwiftData
import Testing

@MainActor
struct BudgetStoreTests {
    @Test func engineOnlyLoadsTheYearAroundTheDate() throws {
        let fixture = try BudgetFixture()
        fixture.spend(1, on: fixture.date(2025, 6, 1))
        fixture.spend(2, on: fixture.date(2025, 12, 25))
        fixture.spend(3, on: fixture.date(2026, 3, 1))
        fixture.spend(4, on: fixture.date(2027, 1, 10))
        fixture.spend(5, on: fixture.date(2027, 2, 1))
        try fixture.context.save()
        let store = BudgetStore(context: fixture.context)
        let amounts = store.engine(around: fixture.date(2026, 6, 1)).entries.map(\.amount).sorted()
        #expect(amounts == [2, 3, 4])
    }

    @Test func engineIsCachedUntilInvalidated() throws {
        let fixture = try BudgetFixture()
        let day = fixture.date(2026, 6, 2)
        let store = BudgetStore(context: fixture.context)
        #expect(store.engine(around: day).spent(on: day) == 0)

        fixture.spend(7, on: day)
        #expect(store.engine(around: day).spent(on: day) == 0)

        let revision = store.revision
        store.invalidate()
        #expect(store.revision == revision + 1)
        #expect(store.engine(around: day).spent(on: day) == 7)
    }

    @Test func savingInvalidatesTheEngine() async throws {
        let fixture = try BudgetFixture()
        let day = fixture.date(2026, 6, 2)
        let store = BudgetStore(context: fixture.context)
        #expect(store.engine(around: day).spent(on: day) == 0)
        await Task.yield()

        let revision = store.revision
        fixture.spend(9, on: day)
        try fixture.context.save()
        for _ in 0..<50 where store.revision == revision {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(store.revision > revision)
        #expect(store.engine(around: day).spent(on: day) == 9)
    }

    @Test func recentAmountsReachBeyondTheCachedYear() throws {
        let fixture = try BudgetFixture()
        fixture.spend(12, on: fixture.date(2024, 1, 5))
        fixture.spend(6, on: fixture.date(2026, 6, 1))
        fixture.spend(6, on: fixture.date(2026, 6, 2))
        try fixture.context.save()
        let store = BudgetStore(context: fixture.context)
        #expect(store.recentAmounts(categoryID: nil, name: "Lunch") == [6, 12])
        #expect(store.recentAmounts(categoryID: nil, name: "Coffee") == [])
    }
}

@MainActor
struct BudgetStoreRecentAmountTests {
    @Test func recentAmountsFollowCategoryIDAndScope() throws {
        let fixture = try BudgetFixture()
        let day = fixture.date(2026, 6, 2)
        fixture.spend(3, on: day, to: fixture.officeLunch)
        fixture.officeLunch.name = "Team Lunch"
        fixture.spend(11, on: day, category: "Team Lunch")
        fixture.spend(30, on: day, category: "Weekly", scope: .week)
        fixture.spend(31, on: day, category: "週予算", scope: .week)
        try fixture.context.save()
        let store = BudgetStore(context: fixture.context)
        #expect(Set(store.recentAmounts(categoryID: fixture.officeLunch.uuid, name: "Team Lunch")) == [3, 11])
        #expect(store.recentAmounts(categoryID: fixture.officeCoffee.uuid, name: "Coffee") == [])
        #expect(Set(store.recentAmounts(categoryID: nil, name: "Ignored", scope: .week)) == [30, 31])
    }
}
