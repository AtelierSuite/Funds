import SwiftUI

extension BudgetEngine {
    func spendPalette(in interval: DateInterval) -> [SpendSlice] {
        palette(from: spentByCategory(in: interval, scope: .day))
    }

    func spendPalette(on date: Date) -> [SpendSlice] {
        palette(from: spentByCategory(on: date))
    }

    private func palette(from breakdown: [CategorySpend]) -> [SpendSlice] {
        breakdown.compactMap { item in
            guard item.amount > 0 else { return nil }
            let icon = item.iconName ?? "tag.fill"
            return SpendSlice(color: CategoryIconPalette.color(for: icon), weight: item.amount.doubleValue)
        }
    }
}

struct SpendSlice: Equatable {
    let color: Color
    let weight: Double
}
