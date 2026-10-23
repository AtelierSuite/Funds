import Foundation

struct CategorySpend {
    let name: String
    let iconName: String?
    let amount: Decimal
}

struct BudgetEngine {
    var templates: [BudgetTemplate]
    var overrides: [DayOverride]
    var entries: [SpendEntry]
    var settings: PlanSettings?
    var calendar: Calendar = .current
    private var entriesByDay: [Date: [SpendEntry]]
    private var totalsByDay: [Date: ScopeTotals]
    private var overridesByDay: [Date: DayOverride]
    private var templatesByUUID: [String: BudgetTemplate]
    private var templateTotals: [ObjectIdentifier: Decimal]
    private var iconsByCategoryName: [String: String]
    private var categoriesByUUID: [String: TemplateCategory]
    private var categoryIDsByTemplate: [ObjectIdentifier: Set<String>]

    private struct ScopeTotals {
        var day: Decimal = 0
        var week: Decimal = 0
        var month: Decimal = 0

        var all: Decimal { day + week + month }

        subscript(scope: SpendScope) -> Decimal {
            switch scope {
            case .day: day
            case .week: week
            case .month: month
            }
        }

        mutating func add(_ amount: Decimal, scope: SpendScope) {
            switch scope {
            case .day: day += amount
            case .week: week += amount
            case .month: month += amount
            }
        }
    }

    init(templates: [BudgetTemplate], overrides: [DayOverride], entries: [SpendEntry], settings: PlanSettings?, calendar: Calendar = .current) {
        self.templates = templates
        self.overrides = overrides
        self.entries = entries
        self.settings = settings
        self.calendar = calendar

        var entriesByDay: [Date: [SpendEntry]] = [:]
        var totalsByDay: [Date: ScopeTotals] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.dayKey)
            entriesByDay[day, default: []].append(entry)
            totalsByDay[day, default: ScopeTotals()].add(entry.amount, scope: entry.scope)
        }
        self.entriesByDay = entriesByDay
        self.totalsByDay = totalsByDay

        var overridesByDay: [Date: DayOverride] = [:]
        for override in overrides {
            overridesByDay[calendar.startOfDay(for: override.dayKey)] = override
        }
        self.overridesByDay = overridesByDay

        var templatesByUUID: [String: BudgetTemplate] = [:]
        var templateTotals: [ObjectIdentifier: Decimal] = [:]
        var iconsByCategoryName: [String: String] = [:]
        var categoriesByUUID: [String: TemplateCategory] = [:]
        var categoryIDsByTemplate: [ObjectIdentifier: Set<String>] = [:]
        for template in templates {
            if templatesByUUID[template.uuid] == nil {
                templatesByUUID[template.uuid] = template
            }
            let categories = template.sortedCategories
            templateTotals[ObjectIdentifier(template)] = categories.reduce(0) { $0 + $1.amount }
            categoryIDsByTemplate[ObjectIdentifier(template)] = Set(categories.map(\.uuid).filter { !$0.isEmpty })
            for category in categories {
                if iconsByCategoryName[category.name] == nil {
                    iconsByCategoryName[category.name] = category.iconName
                }
                if !category.uuid.isEmpty, categoriesByUUID[category.uuid] == nil {
                    categoriesByUUID[category.uuid] = category
                }
            }
        }
        self.templatesByUUID = templatesByUUID
        self.templateTotals = templateTotals
        self.iconsByCategoryName = iconsByCategoryName
        self.categoriesByUUID = categoriesByUUID
        self.categoryIDsByTemplate = categoryIDsByTemplate
    }

    var carryover: CarryoverBehavior { settings?.carryover ?? .leaveAsIs }
    var weeklyExtra: Decimal { settings?.weeklyOverallBudget ?? 0 }
    var monthlyExtra: Decimal { settings?.monthlyOverallBudget ?? 0 }

    // MARK: - Date helpers

    func day(_ date: Date) -> Date { calendar.startOfDay(for: date) }

    func weekInterval(containing date: Date) -> DateInterval {
        calendar.dateInterval(of: .weekOfYear, for: date)
            ?? DateInterval(start: day(date), duration: 7 * 86_400)
    }

    func monthInterval(containing date: Date) -> DateInterval {
        calendar.dateInterval(of: .month, for: date)
            ?? DateInterval(start: day(date), duration: 30 * 86_400)
    }

    func days(in interval: DateInterval) -> [Date] {
        var result: [Date] = []
        var current = calendar.startOfDay(for: interval.start)
        while current < interval.end {
            result.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return result
    }

    // MARK: - Template resolution

    func override(for date: Date) -> DayOverride? {
        overridesByDay[day(date)]
    }

    func template(for date: Date) -> BudgetTemplate? {
        if let override = override(for: date), let template = override.template {
            return template
        }
        let weekday = calendar.component(.weekday, from: date)
        guard let uuid = settings?.templateUUID(forWeekday: weekday) else { return nil }
        return templatesByUUID[uuid]
    }

    // MARK: - Spending

    func entries(on date: Date) -> [SpendEntry] {
        (entriesByDay[day(date)] ?? []).filter { $0.scope == .day }
    }

    func entries(in interval: DateInterval) -> [SpendEntry] {
        days(within: interval).flatMap { entriesByDay[$0] ?? [] }
    }

    private func days(within interval: DateInterval) -> [Date] {
        days(in: interval).filter { $0 >= interval.start }
    }

    private func total(in interval: DateInterval, _ amount: (ScopeTotals) -> Decimal) -> Decimal {
        days(within: interval).reduce(0) { sum, day in
            guard let totals = totalsByDay[day] else { return sum }
            return sum + amount(totals)
        }
    }

    func spent(on date: Date) -> Decimal {
        totalsByDay[day(date)]?.day ?? 0
    }

    func entry(_ entry: SpendEntry, belongsTo categoryID: String, named name: String) -> Bool {
        if !categoryID.isEmpty, entry.categoryID == categoryID { return true }
        guard entry.categoryName == name else { return false }
        guard !entry.categoryID.isEmpty, let template = template(for: entry.dayKey) else { return true }
        return !(categoryIDsByTemplate[ObjectIdentifier(template)] ?? []).contains(entry.categoryID)
    }

    func spent(on date: Date, category: TemplateCategory) -> Decimal {
        entries(on: date)
            .filter { entry($0, belongsTo: category.uuid, named: category.name) }
            .reduce(0) { $0 + $1.amount }
    }

    func categoryName(for entry: SpendEntry) -> String {
        categoriesByUUID[entry.categoryID]?.name ?? entry.categoryName
    }

    func spent(in interval: DateInterval) -> Decimal {
        total(in: interval) { $0.all }
    }

    func spent(in interval: DateInterval, scope: SpendScope) -> Decimal {
        total(in: interval) { $0[scope] }
    }

    func weekSpent(in week: DateInterval) -> Decimal {
        total(in: week) { $0.day + $0.week }
    }

    func spentByCategory(in interval: DateInterval, scope: SpendScope) -> [CategorySpend] {
        breakdown(of: entries(in: interval).filter { $0.scope == scope })
    }

    func spentByCategory(on date: Date) -> [CategorySpend] {
        breakdown(of: entries(on: date))
    }

    private func breakdown(of entries: [SpendEntry]) -> [CategorySpend] {
        var totals: [String: CategorySpend] = [:]
        for entry in entries {
            let category = categoriesByUUID[entry.categoryID]
            let name = category?.name ?? entry.categoryName
            let key = category?.uuid ?? "name:" + name
            let previous = totals[key]?.amount ?? 0
            totals[key] = CategorySpend(
                name: name,
                iconName: category?.iconName ?? iconsByCategoryName[name],
                amount: previous + entry.amount
            )
        }
        return totals.values.sorted { ($0.amount, $1.name) > ($1.amount, $0.name) }
    }

    static func recentAmounts(in entries: [SpendEntry], limit: Int = 3) -> [Decimal] {
        guard limit > 0 else { return [] }
        var seen: [Decimal] = []
        for entry in entries.sorted(by: { $0.timestamp > $1.timestamp }) where !seen.contains(entry.amount) {
            seen.append(entry.amount)
            if seen.count == limit { break }
        }
        return seen
    }

    // MARK: - Budgets

    func baseBudget(for date: Date) -> Decimal {
        guard let template = template(for: date) else { return 0 }
        return templateTotals[ObjectIdentifier(template)] ?? template.total
    }

    func effectiveBudget(for date: Date) -> Decimal {
        let target = day(date)
        guard carryover == .nextDay else { return baseBudget(for: target) }
        let week = weekInterval(containing: target)
        var budgetSum: Decimal = 0
        var spentSum: Decimal = 0
        for d in days(in: week) where d <= target {
            budgetSum += baseBudget(for: d)
            if d < target { spentSum += spent(on: d) }
        }
        return budgetSum - spentSum
    }

    func remaining(for date: Date) -> Decimal {
        effectiveBudget(for: date) - spent(on: date)
    }

    func weekBudget(containing date: Date, includeCarry: Bool = true) -> Decimal {
        let week = weekInterval(containing: date)
        let base = days(in: week).reduce(Decimal(0)) { $0 + baseBudget(for: $1) } + weeklyExtra
        guard includeCarry, carryover == .nextWeek,
              let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: week.start) else {
            return base
        }
        let previousWeek = weekInterval(containing: previous)
        let previousBase = days(in: previousWeek).reduce(Decimal(0)) { $0 + baseBudget(for: $1) } + weeklyExtra
        return base + (previousBase - weekSpent(in: previousWeek))
    }

    func monthBudget(containing date: Date) -> Decimal {
        let month = monthInterval(containing: date)
        let base = days(in: month).reduce(Decimal(0)) { $0 + baseBudget(for: $1) }
        return base + monthlyExtra + weeklyExtra * Decimal(weekStarts(in: month).count)
    }

    func weekStarts(in month: DateInterval) -> [Date] {
        days(in: month).filter { weekInterval(containing: $0).start == $0 }
    }

    func weeklyExtraSpent(in month: DateInterval) -> Decimal {
        weekStarts(in: month).reduce(Decimal(0)) { $0 + spent(in: weekInterval(containing: $1), scope: .week) }
    }

    func monthBudgetToDate(containing date: Date, asOf reference: Date) -> Decimal {
        let month = monthInterval(containing: date)
        let cutoff = day(reference)
        let elapsed = days(in: month).filter { $0 <= cutoff }
        let base = elapsed.reduce(Decimal(0)) { $0 + baseBudget(for: $1) }
        let elapsedWeekStarts = weekStarts(in: month).filter { $0 <= cutoff }
        return base + monthlyExtra + weeklyExtra * Decimal(elapsedWeekStarts.count)
    }

    func weeks(inMonthContaining date: Date) -> [DateInterval] {
        let month = monthInterval(containing: date)
        var result: [DateInterval] = []
        var cursor = weekInterval(containing: month.start)
        while cursor.start < month.end {
            result.append(cursor)
            guard let next = calendar.date(byAdding: .weekOfYear, value: 1, to: cursor.start) else { break }
            cursor = weekInterval(containing: next)
        }
        return result
    }
}
