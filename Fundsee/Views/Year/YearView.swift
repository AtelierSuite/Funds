import Charts
import SwiftData
import SwiftUI

struct YearView: View {
    @Environment(BudgetStore.self) private var store

    @State private var yearOffset = 0

    private var engine: BudgetEngine { store.engine(around: referenceDate) }

    private var referenceDate: Date {
        Calendar.current.date(byAdding: .year, value: yearOffset, to: .now) ?? .now
    }

    private var months: [Date] {
        let calendar = Calendar.current
        guard let year = calendar.dateInterval(of: .year, for: referenceDate) else { return [] }
        return (0..<12).compactMap { calendar.date(byAdding: .month, value: $0, to: year.start) }
    }

    var body: some View {
        NavigationStack {
            List {
                yearSummarySection
                chartSection
                monthsSection
            }
            .listStyle(.plain)
            .navigationTitle(referenceDate.formatted(.dateTime.year()))
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Year.Previous", systemImage: "chevron.left") { yearOffset -= 1 }
                    Button("Year.Next", systemImage: "chevron.right") { yearOffset += 1 }
                }
            }
        }
    }

    private var yearSummarySection: some View {
        let engine = self.engine
        let today = Calendar.current.startOfDay(for: .now)
        let started = months.filter { engine.monthInterval(containing: $0).start <= today }
        let budget = started.reduce(Decimal(0)) { total, month in
            let interval = engine.monthInterval(containing: month)
            let full = interval.end <= today
            return total + (full ? engine.monthBudget(containing: month) : engine.monthBudgetToDate(containing: month, asOf: today))
        }
        let used = started.reduce(Decimal(0)) { $0 + engine.spent(in: engine.monthInterval(containing: $1)) }
        let balance = budget - used
        return Section {
            VStack(spacing: 8) {
            Text(verbatim: balance >= 0 ? "+\(balance.currencyString)" : balance.currencyString)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(balance >= 0 ? Color.green : Color.red)
                .contentTransition(.numericText())
            Text(balance >= 0
                 ? LocalizedStringKey("Year.Summary.Under")
                 : LocalizedStringKey("Year.Summary.Over"))
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                StatBlock(title: "Stat.Budgeted", amount: budget)
                StatBlock(title: "Stat.Spent", amount: used)
            }
            .padding(.top, 6)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
    }

    private var chartSection: some View {
        let engine = self.engine
        return Section {
            Chart {
                ForEach(months, id: \.self) { month in
                    let budget = engine.monthBudget(containing: month)
                    let used = engine.spent(in: engine.monthInterval(containing: month))
                    BarMark(
                        x: .value("Chart.Axis.Month", month, unit: .month),
                        yStart: .value("Chart.Series.Budget", 0),
                        yEnd: .value("Chart.Series.Budget", budget.doubleValue),
                        width: .ratio(0.72)
                    )
                    .foregroundStyle(Color.gray.opacity(0.18))
                    .cornerRadius(4)
                    BarMark(
                        x: .value("Chart.Axis.Month", month, unit: .month),
                        yStart: .value("Chart.Series.Spent", 0),
                        yEnd: .value("Chart.Series.Spent", used.doubleValue),
                        width: .ratio(0.45)
                    )
                    .foregroundStyle(used > budget ? Color.red : Color.accentColor)
                    .cornerRadius(4)
                }
            }
            .chartXAxis {
                AxisMarks(values: months) { _ in
                    AxisValueLabel(format: .dateTime.month(.narrow), centered: true)
                }
            }
            .frame(height: 200)
            .padding(.vertical, 6)
        }
    }

    private var monthsSection: some View {
        let engine = self.engine
        return Section {
            ForEach(months, id: \.self) { month in
                let budget = engine.monthBudget(containing: month)
                let used = engine.spent(in: engine.monthInterval(containing: month))
                HStack {
                    Text(month.formatted(.dateTime.month(.wide)))
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(verbatim: "\(used.currencyString) / \(budget.currencyString)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(used > budget ? .red : .secondary)
                        UsageBar(used: used, budget: budget)
                            .frame(width: 90)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}
