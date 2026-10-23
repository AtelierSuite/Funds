import Foundation
import SwiftData

enum DefaultData {
    static var categoryNames: [String] {
        [
            String(localized: "Seed.Category.Breakfast", defaultValue: "Breakfast"),
            String(localized: "Seed.Category.Lunch", defaultValue: "Lunch"),
            String(localized: "Seed.Category.Dinner", defaultValue: "Dinner"),
            String(localized: "Seed.Category.Beverages", defaultValue: "Beverages"),
            String(localized: "Seed.Category.Entertainment", defaultValue: "Entertainment"),
        ]
    }

    private static let originalCategoryNames = ["Breakfast", "Lunch", "Dinner", "Beverages", "Entertainment"]

    static let categoryIcons = ["sunrise.fill", "takeoutbag.and.cup.and.straw.fill", "fork.knife", "cup.and.saucer.fill", "gamecontroller.fill"]

    struct TemplateSeed {
        let name: String
        let iconName: String
    }

    static var templates: [TemplateSeed] {
        [
            TemplateSeed(name: String(localized: "Seed.Template.Office", defaultValue: "Working from Office"), iconName: "building.2.fill"),
            TemplateSeed(name: String(localized: "Seed.Template.Home", defaultValue: "Working from Home"), iconName: "house.fill"),
            TemplateSeed(name: String(localized: "Seed.Template.NotWorking", defaultValue: "Not Working"), iconName: "sofa.fill"),
        ]
    }

    private enum Seed: Int {
        case office = 0, home = 1, notWorking = 2
    }

    @MainActor
    static func seedIfNeeded(context: ModelContext) {
        let templateCount = (try? context.fetchCount(FetchDescriptor<BudgetTemplate>())) ?? 0
        var seeded: [BudgetTemplate] = []
        if templateCount == 0 {
            let names = categoryNames
            for seed in templates {
                let template = BudgetTemplate(name: seed.name, iconName: seed.iconName)
                context.insert(template)
                for (index, name) in names.enumerated() {
                    let category = TemplateCategory(name: name, amount: 0, sortOrder: index, iconName: categoryIcons[index])
                    category.template = template
                    context.insert(category)
                }
                seeded.append(template)
            }
        }

        let defaultIcons = Dictionary(uniqueKeysWithValues: zip(originalCategoryNames, categoryIcons))
        let allCategories = (try? context.fetch(FetchDescriptor<TemplateCategory>())) ?? []
        for category in allCategories where category.iconName == "tag.fill" {
            if let icon = defaultIcons[category.name] {
                category.iconName = icon
            }
        }

        backfillCategoryIDs(context: context)

        let settingsCount = (try? context.fetchCount(FetchDescriptor<PlanSettings>())) ?? 0
        if settingsCount == 0 {
            let settings = PlanSettings()
            if seeded.indices.contains(Seed.notWorking.rawValue) {
                let office = seeded[Seed.office.rawValue]
                let off = seeded[Seed.notWorking.rawValue]
                settings.setTemplateUUID(off.uuid, forWeekday: 1)
                for weekday in 2...6 {
                    settings.setTemplateUUID(office.uuid, forWeekday: weekday)
                }
                settings.setTemplateUUID(off.uuid, forWeekday: 7)
            }
            context.insert(settings)
        }
        try? context.save()
    }

    static func legacyCategoryID(templateUUID: String, sortOrder: Int, name: String) -> String {
        "\(templateUUID)/\(sortOrder)/\(name)"
    }

    @MainActor
    static func backfillCategoryIDs(context: ModelContext) {
        let unidentified = (try? context.fetch(FetchDescriptor<TemplateCategory>(predicate: #Predicate { $0.uuid == "" }))) ?? []
        for category in unidentified {
            category.uuid = legacyCategoryID(
                templateUUID: category.template?.uuid ?? "",
                sortOrder: category.sortOrder,
                name: category.name
            )
        }

        let dayScope = SpendScope.day.rawValue
        let unlinked = FetchDescriptor<SpendEntry>(predicate: #Predicate { $0.categoryID == "" && $0.scopeRaw == dayScope })
        let entries = (try? context.fetch(unlinked)) ?? []
        guard !entries.isEmpty else { return }

        let templates = (try? context.fetch(FetchDescriptor<BudgetTemplate>(sortBy: [SortDescriptor(\.createdAt), SortDescriptor(\.uuid)]))) ?? []
        let engine = BudgetEngine(
            templates: templates,
            overrides: (try? context.fetch(FetchDescriptor<DayOverride>())) ?? [],
            entries: [],
            settings: (try? context.fetch(FetchDescriptor<PlanSettings>()))?.first
        )
        for entry in entries {
            let candidates = (engine.template(for: entry.dayKey).map { [$0] } ?? []) + templates
            let match = candidates.lazy
                .flatMap(\.sortedCategories)
                .first { $0.name == entry.categoryName }
            if let match {
                entry.categoryID = match.uuid
            }
        }
    }

    private static let sampleAmounts: [String: [Decimal]] = [
        "building.2.fill": [8, 15, 20, 6, 5],
        "house.fill": [6, 8, 18, 4, 5],
        "sofa.fill": [7, 12, 22, 5, 15],
    ]

    @MainActor
    static func seedSampleDataIfRequested(context: ModelContext) {
        guard UserDefaults.standard.bool(forKey: "seedSampleData") else { return }
        let existingEntries = (try? context.fetch(FetchDescriptor<SpendEntry>())) ?? []

        let templates = (try? context.fetch(FetchDescriptor<BudgetTemplate>())) ?? []

        for template in templates {
            guard let amounts = sampleAmounts[template.iconName] else { continue }
            for category in template.sortedCategories where category.amount == 0 {
                guard category.sortOrder < amounts.count else { continue }
                category.amount = amounts[category.sortOrder]
            }
        }

        let settings = (try? context.fetch(FetchDescriptor<PlanSettings>()))?.first
        let engine = BudgetEngine(templates: templates, overrides: [], entries: [], settings: settings)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let daysWithData = Set(existingEntries.map { calendar.startOfDay(for: $0.dayKey) })
        guard let start = calendar.date(byAdding: .month, value: -4, to: today) else { return }

        var day = start
        while day < today {
            if daysWithData.contains(day) {
                guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
                continue
            }
            if let template = engine.template(for: day) {
                for category in template.sortedCategories {
                    if Int.random(in: 0..<10) == 0 { continue }
                    let factor = Double.random(in: 0.55...1.3)
                    let base = category.amount > 0 ? category.amount.doubleValue : 10
                    let total = (base * factor).rounded()
                    guard total > 0 else { continue }
                    let entry = SpendEntry(dayKey: day, categoryName: category.name, categoryID: category.uuid, amount: Decimal(total))
                    let hour = 8 + category.sortOrder * 3
                    entry.timestamp = calendar.date(bySettingHour: min(hour, 21), minute: Int.random(in: 0..<60), second: 0, of: day) ?? day
                    context.insert(entry)
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        try? context.save()
    }
}
