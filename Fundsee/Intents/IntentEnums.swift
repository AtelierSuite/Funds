import AppIntents

enum BudgetPeriod: String, AppEnum {
    case today, week, month, year

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Intent.Parameter.Period")
    static let caseDisplayRepresentations: [BudgetPeriod: DisplayRepresentation] = [
        .today: "Intent.Period.Today",
        .week: "Intent.Period.Week",
        .month: "Intent.Period.Month",
        .year: "Intent.Period.Year",
    ]
}

enum OverallBudgetKind: String, AppEnum {
    case weekly, monthly

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Intent.Parameter.OverallBudget")
    static let caseDisplayRepresentations: [OverallBudgetKind: DisplayRepresentation] = [
        .weekly: "OverallBudgets.Weekly.Header",
        .monthly: "OverallBudgets.Monthly.Header",
    ]

    var scope: SpendScope {
        switch self {
        case .weekly: .week
        case .monthly: .month
        }
    }

    var label: String {
        switch self {
        case .weekly: String(localized: "OverallBudgets.Weekly.Header", defaultValue: "Weekly Overall Budget")
        case .monthly: String(localized: "OverallBudgets.Monthly.Header", defaultValue: "Monthly Overall Budget")
        }
    }
}

enum CarryoverOption: String, AppEnum {
    case leaveAsIs, nextDay, nextWeek

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Intent.Parameter.Carryover")
    static let caseDisplayRepresentations: [CarryoverOption: DisplayRepresentation] = [
        .leaveAsIs: "Carryover.LeaveAsIs.Title",
        .nextDay: "Carryover.NextDay.Title",
        .nextWeek: "Carryover.NextWeek.Title",
    ]

    var behavior: CarryoverBehavior {
        CarryoverBehavior(rawValue: rawValue) ?? .leaveAsIs
    }
}

enum WeekdayOption: Int, AppEnum {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Intent.Parameter.Weekday")
    static let caseDisplayRepresentations: [WeekdayOption: DisplayRepresentation] = [
        .sunday: "Weekday.Sunday",
        .monday: "Weekday.Monday",
        .tuesday: "Weekday.Tuesday",
        .wednesday: "Weekday.Wednesday",
        .thursday: "Weekday.Thursday",
        .friday: "Weekday.Friday",
        .saturday: "Weekday.Saturday",
    ]

    var name: String {
        Calendar.current.weekdaySymbols[rawValue - 1]
    }
}

enum AppTabOption: String, AppEnum {
    case today, week, month, year, more

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Intent.Parameter.Tab")
    static let caseDisplayRepresentations: [AppTabOption: DisplayRepresentation] = [
        .today: "Tab.Today",
        .week: "Tab.Week",
        .month: "Tab.Month",
        .year: "Tab.Year",
        .more: "Tab.More",
    ]
}
