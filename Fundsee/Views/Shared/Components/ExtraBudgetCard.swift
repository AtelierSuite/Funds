import SwiftUI

enum ExtraBudgetKind: Hashable {
    case weekly, monthly

    var title: LocalizedStringKey {
        switch self {
        case .weekly: "OverallBudgets.Weekly.Header"
        case .monthly: "OverallBudgets.Monthly.Header"
        }
    }

    var caption: LocalizedStringKey {
        switch self {
        case .weekly: "Week.Extra.Caption"
        case .monthly: "Month.Extra.Caption"
        }
    }

    var scope: SpendScope {
        switch self {
        case .weekly: .week
        case .monthly: .month
        }
    }

    var categoryName: String {
        switch self {
        case .weekly:
            String(localized: "OverallBudgets.Weekly.Header", defaultValue: "Weekly Overall Budget")
        case .monthly:
            String(localized: "OverallBudgets.Monthly.Header", defaultValue: "Monthly Overall Budget")
        }
    }
}

struct ExtraBudgetCards: View {
    let engine: BudgetEngine
    let date: Date
    let namespace: Namespace.ID
    @Binding var spendTarget: SpendTarget?
    var kinds: [ExtraBudgetKind] = [.weekly, .monthly]

    var body: some View {
        VStack(spacing: 12) {
            if kinds.contains(.weekly), engine.weeklyExtra > 0 {
                card(.weekly, budget: engine.weeklyExtra, interval: engine.weekInterval(containing: date))
            }
            if kinds.contains(.monthly), engine.monthlyExtra > 0 {
                card(.monthly, budget: engine.monthlyExtra, interval: engine.monthInterval(containing: date))
            }
        }
    }

    private func card(_ kind: ExtraBudgetKind, budget: Decimal, interval: DateInterval) -> some View {
        let name = kind.categoryName
        return ExtraBudgetCard(
            kind: kind,
            budget: budget,
            used: engine.spent(in: interval, scope: kind.scope)
        ) {
            spendTarget = SpendTarget(name: name, scope: kind.scope, period: interval)
        }
        .matchedTransitionSource(id: name, in: namespace)
    }
}

struct ExtraBudgetCard: View {
    var kind: ExtraBudgetKind
    var budget: Decimal
    var used: Decimal
    var action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(kind.title)
                            .font(.subheadline.weight(.semibold))
                        Text(kind.caption)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 12)
                    Text(verbatim: "\(used.currencyString) / \(budget.currencyString)")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(used > budget ? .red : .primary)
                        .contentTransition(.numericText())
                }
                UsageBar(used: used, budget: budget)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.accentColor.opacity(colorScheme == .light ? 0.12 : 0.22))
                    .shadow(color: colorScheme == .light ? Color.accentColor.opacity(0.2) : .clear, radius: 8, y: 3)
            }
        }
        .buttonStyle(.plain)
    }
}
