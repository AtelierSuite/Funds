import Foundation
import SwiftData

enum SyncDeduplication {
    @MainActor
    @discardableResult
    static func mergeDuplicates(context: ModelContext) -> Bool {
        var changed = mergeTemplates(context: context)
        changed = mergeSettings(context: context) || changed
        changed = removeUnusedSeedTemplates(context: context) || changed
        if changed {
            try? context.save()
        }
        return changed
    }

    // MARK: - Templates

    @MainActor
    private static func mergeTemplates(context: ModelContext) -> Bool {
        let templates = (try? context.fetch(FetchDescriptor<BudgetTemplate>())) ?? []
        var changed = false
        for group in Dictionary(grouping: templates, by: \.uuid).values where group.count > 1 {
            let ordered = group.sorted(by: BudgetTemplate.precedes)
            let survivor = ordered[0]
            for duplicate in ordered.dropFirst() where BudgetTemplate.precedes(survivor, duplicate) {
                absorb(duplicate, into: survivor, context: context)
                changed = true
            }
        }
        return changed
    }

    @MainActor
    private static func absorb(_ duplicate: BudgetTemplate, into survivor: BudgetTemplate, context: ModelContext) {
        var nextSortOrder = (survivor.sortedCategories.last?.sortOrder ?? -1) + 1
        for category in duplicate.sortedCategories {
            if let match = survivor.sortedCategories.first(where: { !category.uuid.isEmpty && $0.uuid == category.uuid }) {
                if match.amount == 0, category.amount != 0 {
                    match.amount = category.amount
                }
                context.delete(category)
            } else {
                category.template = survivor
                category.sortOrder = nextSortOrder
                nextSortOrder += 1
            }
        }
        for override in duplicate.overrides ?? [] {
            override.template = survivor
        }
        context.delete(duplicate)
    }

    @MainActor
    private static func removeUnusedSeedTemplates(context: ModelContext) -> Bool {
        let templates = (try? context.fetch(FetchDescriptor<BudgetTemplate>())) ?? []
        let seedIDs = Set(DefaultData.templates.map(\.id))
        let legacyIcons = Set(templates.filter { !seedIDs.contains($0.uuid) }.map(\.iconName))
        guard !legacyIcons.isEmpty else { return false }
        let settings = (try? context.fetch(FetchDescriptor<PlanSettings>())) ?? []
        let planned = Set(settings.flatMap(\.weekdayTemplateUUIDs))
        var changed = false
        for template in templates where seedIDs.contains(template.uuid) && !planned.contains(template.uuid) {
            guard legacyIcons.contains(template.iconName) else { continue }
            let categories = template.categories ?? []
            guard categories.allSatisfy({ $0.amount == 0 }), (template.overrides ?? []).isEmpty else { continue }
            let ids = categories.map(\.uuid)
            let used = (try? context.fetchCount(FetchDescriptor<SpendEntry>(predicate: #Predicate { ids.contains($0.categoryID) }))) ?? 1
            guard used == 0 else { continue }
            context.delete(template)
            changed = true
        }
        return changed
    }

    // MARK: - Settings

    @MainActor
    private static func mergeSettings(context: ModelContext) -> Bool {
        let all = (try? context.fetch(FetchDescriptor<PlanSettings>())) ?? []
        guard all.count > 1 else { return false }
        let ordered = all.sorted(by: PlanSettings.precedes)
        let survivor = ordered[0]
        var changed = false
        for duplicate in ordered.dropFirst() where PlanSettings.precedes(survivor, duplicate) {
            for weekday in 1...7 where survivor.templateUUID(forWeekday: weekday) == nil {
                if let uuid = duplicate.templateUUID(forWeekday: weekday) {
                    survivor.setTemplateUUID(uuid, forWeekday: weekday)
                }
            }
            if survivor.weeklyOverallBudget == 0 {
                survivor.weeklyOverallBudget = duplicate.weeklyOverallBudget
            }
            if survivor.monthlyOverallBudget == 0 {
                survivor.monthlyOverallBudget = duplicate.monthlyOverallBudget
            }
            if survivor.carryover == .leaveAsIs {
                survivor.carryover = duplicate.carryover
            }
            context.delete(duplicate)
            changed = true
        }
        return changed
    }
}

extension BudgetTemplate {
    static func precedes(_ lhs: BudgetTemplate, _ rhs: BudgetTemplate) -> Bool {
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
        return lhs.contentKey < rhs.contentKey
    }

    private var contentKey: String {
        ([name, iconName] + sortedCategories.map { "\($0.uuid)=\($0.name):\($0.amount)" }).joined(separator: "|")
    }
}

extension PlanSettings {
    static func precedes(_ lhs: PlanSettings, _ rhs: PlanSettings) -> Bool {
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
        return lhs.contentKey < rhs.contentKey
    }

    private var contentKey: String {
        (weekdayTemplateUUIDs + ["\(weeklyOverallBudget)", "\(monthlyOverallBudget)", carryoverRaw]).joined(separator: "|")
    }
}

extension Array where Element == PlanSettings {
    var primary: PlanSettings? {
        self.min(by: PlanSettings.precedes)
    }
}
