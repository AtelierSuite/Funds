import Charts
import SwiftData
import SwiftUI

struct WeekView: View {
    @Environment(BudgetStore.self) private var store

    @State private var weekOffset = 0
    @State private var stripDay: Date?
    @State private var spendTarget: SpendTarget?
    @Namespace private var cardZoom
    @Namespace private var daySelection

    private var engine: BudgetEngine { store.engine(around: referenceDate) }

    private var referenceDate: Date {
        Calendar.current.date(byAdding: .weekOfYear, value: weekOffset, to: .now) ?? .now
    }

    private var shownDay: Date {
        let engine = self.engine
        let days = engine.days(in: engine.weekInterval(containing: referenceDate))
        let fallback = days.first(where: \.isToday) ?? days.first ?? referenceDate
        return stripDay.flatMap { days.contains($0) ? $0 : nil } ?? fallback
    }

    var body: some View {
        NavigationStack {
            List {
                summarySection
                weekCalendarSection
            }
            .listStyle(.plain)
            .navigationTitle(engine.weekInterval(containing: referenceDate).weekRangeLabel)
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Week.Previous", systemImage: "chevron.left") { weekOffset -= 1 }
                    Button("Week.Next", systemImage: "chevron.right") { weekOffset += 1 }
                }
            }
            .sheet(item: $spendTarget) { target in
                SpendInputSheet(
                    date: shownDay,
                    categoryName: target.name,
                    categoryID: target.categoryID,
                    scope: target.scope,
                    period: target.period
                )
                .navigationTransition(.zoom(sourceID: target.name, in: cardZoom))
            }
        }
    }

    private var summarySection: some View {
        let engine = self.engine
        let week = engine.weekInterval(containing: referenceDate)
        let budget = engine.weekBudget(containing: referenceDate)
        let used = engine.weekSpent(in: week)
        let carryover = budget - engine.weekBudget(containing: referenceDate, includeCarry: false)
        return Section {
            BudgetSummaryHeader(
                used: used,
                budget: budget,
                caption: String(localized: "Ring.Caption.OfThisWeek", defaultValue: "of \(budget.currencyString) this week"),
                carryover: carryover,
                spendPalette: engine.spendPalette(in: week),
                extraArcs: engine.weeklyExtra > 0
                    ? [ExtraArc(used: engine.spent(in: week, scope: .week), budget: engine.weeklyExtra)]
                    : []
            )
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
    }

    private var weekCalendarSection: some View {
        let engine = self.engine
        let week = engine.weekInterval(containing: referenceDate)
        let days = engine.days(in: week)
        let shown = shownDay
        let budget = engine.effectiveBudget(for: shown)
        let spent = engine.spent(on: shown)
        return Group {
            Section {
                HStack(spacing: 4) {
                    ForEach(days, id: \.self) { day in
                        Button {
                            withAnimation(.standard) { stripDay = day }
                        } label: {
                            WeekDayPill(
                                day: day,
                                isSelected: day == shown,
                                status: dayStatus(day, engine: engine),
                                selectionNamespace: daySelection
                            )
                        }
                        .buttonStyle(.borderless)
                        .tint(.primary)
                    }
                }
                .padding(.vertical, 6)
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())

            Section {
            VStack(spacing: 8) {
                HStack {
                    Label {
                        if let name = engine.template(for: shown)?.name {
                            Text(name)
                        } else {
                            Text("Common.NoTemplate")
                        }
                    } icon: {
                        Image(systemName: engine.template(for: shown)?.iconName ?? "questionmark.circle")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    Spacer()
                    Text(verbatim: "\(spent.currencyString) / \(budget.currencyString)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(spent > budget ? .red : .primary)
                        .contentTransition(.numericText())
                }
                UsageBar(used: spent, budget: budget)
            }
            .padding(.vertical, 4)

            if let template = engine.template(for: shown) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                    ForEach(template.sortedCategories) { category in
                        let categorySpent = engine.spent(on: shown, category: category)
                        Button {
                            spendTarget = SpendTarget(name: category.name, categoryID: category.uuid)
                        } label: {
                            CategoryGridCell(category: category, used: categorySpent)
                        }
                        .buttonStyle(.plain)
                        .matchedTransitionSource(id: category.name, in: cardZoom)
                    }
                }
                .padding(.horizontal, 16)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            }

            ExtraBudgetCards(engine: engine, date: shown, namespace: cardZoom, spendTarget: $spendTarget)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
            }
        }
    }

    private func dayStatus(_ day: Date, engine: BudgetEngine) -> WeekDayPill.Status {
        let spent = engine.spent(on: day)
        if spent <= 0 { return .empty }
        return spent > engine.effectiveBudget(for: day) ? .over : .under
    }
}
