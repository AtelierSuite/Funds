import Foundation
import SwiftData
import Testing

@MainActor
struct SyncDeduplicationTests {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        let configuration = ModelConfiguration(schema: AppGroup.schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: AppGroup.schema, configurations: [configuration])
        context = ModelContext(container)
    }

    private func seedDevice(at createdAt: Date) -> (templates: [BudgetTemplate], settings: PlanSettings) {
        let templates = DefaultData.insertSeedTemplates(context: context)
        for template in templates {
            template.createdAt = createdAt
        }
        let settings = DefaultData.insertDefaultSettings(context: context, seeded: true)
        settings.createdAt = createdAt
        return (templates, settings)
    }

    private func templates() throws -> [BudgetTemplate] {
        try context.fetch(FetchDescriptor<BudgetTemplate>())
    }

    private func settings() throws -> [PlanSettings] {
        try context.fetch(FetchDescriptor<PlanSettings>())
    }

    private func office(_ templates: [BudgetTemplate]) throws -> BudgetTemplate {
        try #require(templates.first { $0.uuid == DefaultData.officeSeedID })
    }

    @Test func seedingUsesFixedIDs() throws {
        DefaultData.seedIfNeeded(context: context)
        let templates = try templates()
        #expect(Set(templates.map(\.uuid)) == [DefaultData.officeSeedID, DefaultData.homeSeedID, DefaultData.notWorkingSeedID])
        let office = try office(templates)
        #expect(office.sortedCategories.map(\.uuid).first == DefaultData.seedCategoryID(templateID: DefaultData.officeSeedID, index: 0))
        let plan = try #require(try settings().primary)
        #expect(plan.templateUUID(forWeekday: 2) == DefaultData.officeSeedID)
        #expect(plan.templateUUID(forWeekday: 1) == DefaultData.notWorkingSeedID)
    }

    @Test func twoSeededDevicesMergeIntoOne() throws {
        let first = seedDevice(at: Date(timeIntervalSince1970: 1_000))
        let second = seedDevice(at: Date(timeIntervalSince1970: 2_000))
        let secondOffice = try office(second.templates)
        secondOffice.sortedCategories[1].amount = 12
        second.settings.weeklyOverallBudget = 40
        let day = Date(timeIntervalSince1970: 1_780_000_000)
        context.insert(DayOverride(dayKey: day, template: secondOffice))
        let lunch = secondOffice.sortedCategories[1]
        context.insert(SpendEntry(dayKey: day, categoryName: lunch.name, categoryID: lunch.uuid, amount: 9))
        try context.save()

        #expect(SyncDeduplication.mergeDuplicates(context: context))

        let templates = try templates()
        #expect(templates.count == 3)
        let survivor = try office(templates)
        #expect(survivor === (try office(first.templates)))
        #expect(survivor.sortedCategories.count == 5)
        #expect(survivor.sortedCategories[1].amount == 12)
        #expect(survivor.overrides?.count == 1)

        let plans = try settings()
        #expect(plans.count == 1)
        #expect(plans.first === first.settings)
        #expect(first.settings.weeklyOverallBudget == 40)

        let engine = BudgetEngine(
            templates: templates,
            overrides: try context.fetch(FetchDescriptor<DayOverride>()),
            entries: try context.fetch(FetchDescriptor<SpendEntry>()),
            settings: plans.primary
        )
        #expect(engine.template(for: day) === survivor)
        #expect(engine.spent(on: day, category: survivor.sortedCategories[1]) == 9)
        #expect(!SyncDeduplication.mergeDuplicates(context: context))
    }

    @Test func survivorKeepsItsOwnEdits() throws {
        let first = seedDevice(at: Date(timeIntervalSince1970: 1_000))
        let second = seedDevice(at: Date(timeIntervalSince1970: 2_000))
        try office(first.templates).sortedCategories[0].amount = 10
        try office(second.templates).sortedCategories[0].amount = 12
        first.settings.carryover = .nextDay
        second.settings.carryover = .nextWeek
        try context.save()

        SyncDeduplication.mergeDuplicates(context: context)

        #expect(try office(templates()).sortedCategories[0].amount == 10)
        #expect(try settings().primary?.carryover == .nextDay)
    }

    @Test func categoriesAddedOnTheOtherDeviceAreKept() throws {
        let first = seedDevice(at: Date(timeIntervalSince1970: 1_000))
        let second = seedDevice(at: Date(timeIntervalSince1970: 2_000))
        let extra = TemplateCategory(name: "Snacks", amount: 3, sortOrder: 5)
        extra.template = try office(second.templates)
        context.insert(extra)
        try context.save()

        SyncDeduplication.mergeDuplicates(context: context)

        let survivor = try office(templates())
        #expect(survivor === (try office(first.templates)))
        #expect(survivor.sortedCategories.map(\.name).last == "Snacks")
        #expect(survivor.sortedCategories.last?.uuid == extra.uuid)
    }

    @Test func legacySettingsWinOverFreshOnes() throws {
        let legacy = PlanSettings()
        legacy.createdAt = .distantPast
        legacy.setTemplateUUID("legacy-office", forWeekday: 2)
        context.insert(legacy)
        let fresh = seedDevice(at: .now).settings
        try context.save()

        SyncDeduplication.mergeDuplicates(context: context)

        let plans = try settings()
        #expect(plans.count == 1)
        #expect(plans.first === legacy)
        #expect(legacy.templateUUID(forWeekday: 2) == "legacy-office")
        #expect(legacy.templateUUID(forWeekday: 3) == DefaultData.officeSeedID)
        _ = fresh
    }

    @Test func identicalSettingsAreLeftAlone() throws {
        for _ in 0..<2 {
            let settings = PlanSettings()
            settings.createdAt = .distantPast
            context.insert(settings)
        }
        try context.save()
        #expect(!SyncDeduplication.mergeDuplicates(context: context))
        #expect(try settings().count == 2)
    }

    @Test func unusedSeedCopiesOfLegacyTemplatesAreRemoved() throws {
        var legacyOffice: BudgetTemplate?
        for (name, icon) in [("Office", "building.2.fill"), ("Home", "house.fill"), ("Off", "sofa.fill")] {
            let template = BudgetTemplate(name: name, iconName: icon)
            template.createdAt = .distantPast
            context.insert(template)
            legacyOffice = legacyOffice ?? template
        }
        let legacySettings = PlanSettings()
        legacySettings.createdAt = .distantPast
        for weekday in 1...7 {
            legacySettings.setTemplateUUID(legacyOffice?.uuid, forWeekday: weekday)
        }
        context.insert(legacySettings)
        let seeded = seedDevice(at: .now)
        legacySettings.setTemplateUUID(DefaultData.homeSeedID, forWeekday: 3)
        let notWorking = try #require(seeded.templates.first { $0.uuid == DefaultData.notWorkingSeedID })
        let fun = notWorking.sortedCategories[4]
        context.insert(SpendEntry(dayKey: .now, categoryName: fun.name, categoryID: fun.uuid, amount: 5))
        try context.save()

        SyncDeduplication.mergeDuplicates(context: context)

        let remaining = Set(try templates().map(\.uuid))
        #expect(remaining.contains(DefaultData.homeSeedID))
        #expect(remaining.contains(DefaultData.notWorkingSeedID))
        #expect(!remaining.contains(DefaultData.officeSeedID))
        #expect(remaining.count == 5)
    }

    @Test func seedTemplatesStayWithoutLegacyCopies() throws {
        let seeded = seedDevice(at: .now)
        let custom = BudgetTemplate(name: "Travel", iconName: "airplane")
        context.insert(custom)
        for weekday in 1...7 {
            seeded.settings.setTemplateUUID(custom.uuid, forWeekday: weekday)
        }
        try context.save()

        SyncDeduplication.mergeDuplicates(context: context)

        #expect(try templates().count == 4)
    }

    @Test func engineUsesTheEarliestDuplicate() throws {
        let first = seedDevice(at: Date(timeIntervalSince1970: 1_000))
        let second = seedDevice(at: Date(timeIntervalSince1970: 2_000))
        try context.save()
        let engine = BudgetEngine(
            templates: Array(try templates().reversed()),
            overrides: [],
            entries: [],
            settings: second.settings
        )
        let monday = try #require(Calendar.current.nextDate(after: .now, matching: DateComponents(weekday: 2), matchingPolicy: .nextTime))
        #expect(engine.template(for: monday) === (try office(first.templates)))
    }
}
