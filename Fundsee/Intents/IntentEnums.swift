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

enum PlanIconOption: String, AppEnum {
    case office = "building.2.fill"
    case home = "house.fill"
    case relaxing = "sofa.fill"
    case celebration = "party.popper.fill"
    case travel = "airplane"
    case outing = "figure.walk"
    case shopping = "cart.fill"
    case star = "star.fill"

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Intent.Parameter.Icon")
    static let caseDisplayRepresentations: [PlanIconOption: DisplayRepresentation] = [
        .office: DisplayRepresentation(title: "Icon.Plan.Office", image: .init(systemName: "building.2.fill")),
        .home: DisplayRepresentation(title: "Icon.Plan.Home", image: .init(systemName: "house.fill")),
        .relaxing: DisplayRepresentation(title: "Icon.Plan.Relaxing", image: .init(systemName: "sofa.fill")),
        .celebration: DisplayRepresentation(title: "Icon.Plan.Celebration", image: .init(systemName: "party.popper.fill")),
        .travel: DisplayRepresentation(title: "Icon.Plan.Travel", image: .init(systemName: "airplane")),
        .outing: DisplayRepresentation(title: "Icon.Plan.Outing", image: .init(systemName: "figure.walk")),
        .shopping: DisplayRepresentation(title: "Icon.Plan.Shopping", image: .init(systemName: "cart.fill")),
        .star: DisplayRepresentation(title: "Icon.Plan.Star", image: .init(systemName: "star.fill")),
    ]
}

enum CategoryIconOption: String, AppEnum {
    case morning = "sunrise.fill"
    case takeout = "takeoutbag.and.cup.and.straw.fill"
    case dining = "fork.knife"
    case coffee = "cup.and.saucer.fill"
    case games = "gamecontroller.fill"
    case cart = "cart.fill"
    case car = "car.fill"
    case transit = "tram.fill"
    case bag = "bag.fill"
    case gifts = "gift.fill"
    case books = "book.fill"
    case heart = "heart.fill"
    case pets = "pawprint.fill"
    case firstAid = "cross.case.fill"
    case medicine = "pills.fill"
    case doctor = "stethoscope"
    case electricity = "bolt.fill"
    case water = "drop.fill"
    case gas = "flame.fill"
    case internet = "wifi"
    case card = "creditcard.fill"
    case subscriptions = "arrow.triangle.2.circlepath"
    case home = "house.fill"
    case education = "graduationcap.fill"
    case tag = "tag.fill"

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Intent.Parameter.Icon")
    static let caseDisplayRepresentations: [CategoryIconOption: DisplayRepresentation] = [
        .morning: DisplayRepresentation(title: "Icon.Category.Morning", image: .init(systemName: "sunrise.fill")),
        .takeout: DisplayRepresentation(title: "Icon.Category.Takeout", image: .init(systemName: "takeoutbag.and.cup.and.straw.fill")),
        .dining: DisplayRepresentation(title: "Icon.Category.Dining", image: .init(systemName: "fork.knife")),
        .coffee: DisplayRepresentation(title: "Icon.Category.Coffee", image: .init(systemName: "cup.and.saucer.fill")),
        .games: DisplayRepresentation(title: "Icon.Category.Games", image: .init(systemName: "gamecontroller.fill")),
        .cart: DisplayRepresentation(title: "Icon.Category.Cart", image: .init(systemName: "cart.fill")),
        .car: DisplayRepresentation(title: "Icon.Category.Car", image: .init(systemName: "car.fill")),
        .transit: DisplayRepresentation(title: "Icon.Category.Transit", image: .init(systemName: "tram.fill")),
        .bag: DisplayRepresentation(title: "Icon.Category.Bag", image: .init(systemName: "bag.fill")),
        .gifts: DisplayRepresentation(title: "Icon.Category.Gifts", image: .init(systemName: "gift.fill")),
        .books: DisplayRepresentation(title: "Icon.Category.Books", image: .init(systemName: "book.fill")),
        .heart: DisplayRepresentation(title: "Icon.Category.Heart", image: .init(systemName: "heart.fill")),
        .pets: DisplayRepresentation(title: "Icon.Category.Pets", image: .init(systemName: "pawprint.fill")),
        .firstAid: DisplayRepresentation(title: "Icon.Category.FirstAid", image: .init(systemName: "cross.case.fill")),
        .medicine: DisplayRepresentation(title: "Icon.Category.Medicine", image: .init(systemName: "pills.fill")),
        .doctor: DisplayRepresentation(title: "Icon.Category.Doctor", image: .init(systemName: "stethoscope")),
        .electricity: DisplayRepresentation(title: "Icon.Category.Electricity", image: .init(systemName: "bolt.fill")),
        .water: DisplayRepresentation(title: "Icon.Category.Water", image: .init(systemName: "drop.fill")),
        .gas: DisplayRepresentation(title: "Icon.Category.Gas", image: .init(systemName: "flame.fill")),
        .internet: DisplayRepresentation(title: "Icon.Category.Internet", image: .init(systemName: "wifi")),
        .card: DisplayRepresentation(title: "Icon.Category.Card", image: .init(systemName: "creditcard.fill")),
        .subscriptions: DisplayRepresentation(title: "Icon.Category.Subscriptions", image: .init(systemName: "arrow.triangle.2.circlepath")),
        .home: DisplayRepresentation(title: "Icon.Category.Home", image: .init(systemName: "house.fill")),
        .education: DisplayRepresentation(title: "Icon.Category.Education", image: .init(systemName: "graduationcap.fill")),
        .tag: DisplayRepresentation(title: "Icon.Category.Tag", image: .init(systemName: "tag.fill")),
    ]
}

enum ExportKind: String, AppEnum {
    case records, plans

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Intent.Parameter.ExportKind")
    static let caseDisplayRepresentations: [ExportKind: DisplayRepresentation] = [
        .records: "Intent.ExportKind.Records",
        .plans: "Intent.ExportKind.Plans",
    ]
}
