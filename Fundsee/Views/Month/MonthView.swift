import Charts
import SwiftData
import SwiftUI

struct MonthView: View {
    @Query private var templates: [BudgetTemplate]
    @Query private var overrides: [DayOverride]
    @Query private var entries: [SpendEntry]
    @Query private var allSettings: [PlanSettings]

    @Environment(\.colorScheme) private var colorScheme

    @State private var monthOffset = 0
    @State private var selectedWeekStart: Date?
    @State private var spendTarget: SpendTarget?
    @Namespace private var weekSelection
    @Namespace private var cardZoom

    private static let selectionID = "MonthView.weekSelection"

    private var engine: BudgetEngine {
        BudgetEngine(templates: templates, overrides: overrides, entries: entries, settings: allSettings.first)
    }

    private var referenceDate: Date {
        Calendar.current.date(byAdding: .month, value: monthOffset, to: .now) ?? .now
    }

    private var entryDate: Date {
        let month = engine.monthInterval(containing: referenceDate)
        let today = Calendar.current.startOfDay(for: .now)
        return month.contains(today) && today < month.end ? today : month.start
    }

    private func monthExtraArcs(engine: BudgetEngine, month: DateInterval) -> [ExtraArc] {
        var arcs: [ExtraArc] = []
        if engine.monthlyExtra > 0 {
            arcs.append(ExtraArc(used: engine.spent(in: month, scope: .month), budget: engine.monthlyExtra))
        }
        if engine.weeklyExtra > 0 {
            let weeks = engine.weekStarts(in: month).count
            arcs.append(
                ExtraArc(
                    used: engine.weeklyExtraSpent(in: month),
                    budget: engine.weeklyExtra * Decimal(weeks),
                    color: .accentColor.opacity(0.6)
                )
            )
        }
        return arcs
    }

    private var shownWeek: DateInterval {
        let engine = self.engine
        let weeks = engine.weeks(inMonthContaining: referenceDate)
        if let start = selectedWeekStart,
           let match = weeks.first(where: { $0.start == start }) {
            return match
        }
        let today = Calendar.current.startOfDay(for: .now)
        return weeks.first { Self.week($0, contains: today) } ?? weeks.first
            ?? engine.weekInterval(containing: referenceDate)
    }

    var body: some View {
        NavigationStack {
            List {
                summarySection
                calendarSection
                extraBudgetsSection
                selectedWeekSection
                chartSection
            }
            .listStyle(.plain)
            .navigationTitle(referenceDate.formatted(.dateTime.month(.wide).year()))
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Month.Previous", systemImage: "chevron.left") { monthOffset -= 1 }
                    Button("Month.Next", systemImage: "chevron.right") { monthOffset += 1 }
                }
            }
            .sheet(item: $spendTarget) { target in
                SpendInputSheet(
                    date: entryDate,
                    categoryName: target.name,
                    recentAmounts: engine.recentAmounts(category: target.name),
                    scope: target.scope,
                    period: target.period
                )
                .navigationTransition(.zoom(sourceID: target.name, in: cardZoom))
            }
        }
    }

    private var extraBudgetsSection: some View {
        Section {
            ExtraBudgetCards(
                engine: engine,
                date: entryDate,
                namespace: cardZoom,
                spendTarget: $spendTarget,
                kinds: [.monthly]
            )
            .padding(.horizontal, 16)
            .padding(.top, 10)
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
    }

    private var summarySection: some View {
        let engine = self.engine
        let month = engine.monthInterval(containing: referenceDate)
        let budget = engine.monthBudget(containing: referenceDate)
        let used = engine.spent(in: month)
        return Section {
            BudgetSummaryHeader(
                used: used,
                budget: budget,
                caption: String(localized: "Ring.Caption.OfThisMonth", defaultValue: "of \(budget.currencyString) this month"),
                spendPalette: engine.spendPalette(in: month),
                extraArcs: monthExtraArcs(engine: engine, month: month)
            )
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
    }

    private var calendarSection: some View {
        let engine = self.engine
        let calendar = Calendar.current
        let month = engine.monthInterval(containing: referenceDate)
        let weeks = engine.weeks(inMonthContaining: referenceDate)
        let symbols = orderedWeekdaySymbols(calendar)
        let today = calendar.startOfDay(for: .now)
        let shownWeekStart = shownWeek.start

        return Section {
            VStack(spacing: 0) {
                HStack(spacing: 4) {
                    ForEach(Array(symbols.enumerated()), id: \.offset) { _, symbol in
                        Text(symbol)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 2)

                ForEach(weeks, id: \.start) { week in
                    let isSelected = week.start == shownWeekStart
                    let days = engine.days(in: week)
                    VStack(spacing: 6) {
                        HStack(spacing: 4) {
                            ForEach(days, id: \.self) { day in
                                dayNumber(
                                    day,
                                    inMonth: Self.week(month, contains: day),
                                    isSelected: isSelected,
                                    today: today
                                )
                            }
                        }
                        .background {
                            GeometryReader { proxy in
                                let column = (proxy.size.width - 4 * 6) / 7
                                if isSelected {
                                    Capsule()
                                        .fill(Color.accentColor)
                                        .padding(.horizontal, max(0, (column - 36) / 2))
                                        .matchedGeometryEffect(id: Self.selectionID, in: weekSelection)
                                }
                            }
                        }
                        HStack(spacing: 4) {
                            ForEach(days, id: \.self) { day in
                                dayDot(
                                    day,
                                    inMonth: Self.week(month, contains: day),
                                    engine: engine,
                                    today: today
                                )
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(.rect)
                    .onTapGesture {
                        withAnimation(.standard) { selectedWeekStart = week.start }
                    }
                }
            }
            .padding(.vertical, 6)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
        }
    }

    @ViewBuilder
    private func dayNumber(_ day: Date, inMonth: Bool, isSelected: Bool, today: Date) -> some View {
        Group {
            if inMonth {
                Text(Calendar.current.component(.day, from: day), format: .number.grouping(.never))
                    .font(.callout.weight(day == today || isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected ? WeekDayPill.selectedForeground(colorScheme) : (day == today ? Color.accentColor : .primary))
            } else {
                Color.clear
            }
        }
        .frame(height: 36)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func dayDot(_ day: Date, inMonth: Bool, engine: BudgetEngine, today: Date) -> some View {
        Group {
            if inMonth {
                Circle()
                    .fill(
                        dayColor(
                            used: engine.spent(on: day),
                            budget: engine.effectiveBudget(for: day),
                            day: day,
                            today: today
                        )
                    )
                    .frame(width: 5, height: 5)
            } else {
                Color.clear
            }
        }
        .frame(height: 5)
        .frame(maxWidth: .infinity)
    }

    private var selectedWeekSection: some View {
        let engine = self.engine
        let week = shownWeek
        let budget = engine.weekBudget(containing: week.start, includeCarry: false)
        let used = engine.weekSpent(in: week)
        return Section {
            VStack(spacing: 10) {
                HStack {
                    Text(weekTitle(week))
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(verbatim: "\(used.currencyString) / \(budget.currencyString)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(used > budget ? .red : .primary)
                        .contentTransition(.numericText())
                }
                UsageBar(used: used, budget: budget)
            }
            .padding(.vertical, 6)
        }
    }

    private var chartSection: some View {
        let engine = self.engine
        let weeks = engine.weeks(inMonthContaining: referenceDate)
        let shownWeek = self.shownWeek
        return Section {
            Chart {
                ForEach(Array(weeks.enumerated()), id: \.offset) { index, week in
                    let budget = engine.weekBudget(containing: week.start, includeCarry: false)
                    let used = engine.weekSpent(in: week)
                    BarMark(
                        x: .value("Chart.Axis.Week", String(localized: "Month.Chart.WeekLabel", defaultValue: "W\(index + 1)")),
                        yStart: .value("Chart.Series.Budget", 0),
                        yEnd: .value("Chart.Series.Budget", budget.doubleValue),
                        width: .ratio(0.72)
                    )
                    .foregroundStyle(Color.gray.opacity(0.18))
                    .cornerRadius(5)
                    BarMark(
                        x: .value("Chart.Axis.Week", String(localized: "Month.Chart.WeekLabel", defaultValue: "W\(index + 1)")),
                        yStart: .value("Chart.Series.Spent", 0),
                        yEnd: .value("Chart.Series.Spent", used.doubleValue),
                        width: .ratio(0.45)
                    )
                    .foregroundStyle(
                        used > budget
                            ? Color.red
                            : (week == shownWeek ? Color.accentColor : Color.accentColor.opacity(0.45))
                    )
                    .cornerRadius(5)
                }
            }
            .frame(height: 160)
            .padding(.vertical, 6)
            .listRowSeparator(.hidden)
        }
    }

    private func weekTitle(_ week: DateInterval) -> String {
        let calendar = Calendar.current
        let lastDay = calendar.date(byAdding: .day, value: -1, to: week.end) ?? week.end
        return (week.start..<lastDay).formatted(.interval.month(.abbreviated).day())
    }

    private static func week(_ week: DateInterval, contains day: Date) -> Bool {
        day >= week.start && day < week.end
    }

    private func dayColor(used: Decimal, budget: Decimal, day: Date, today: Date) -> Color {
        if day > today { return .gray.opacity(0.2) }
        if budget <= 0 && used <= 0 { return .gray.opacity(0.3) }
        if used > budget { return .red }
        if used.doubleValue > budget.doubleValue * 0.85 { return .orange }
        return .green
    }

    private func orderedWeekdaySymbols(_ calendar: Calendar) -> [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }
}
