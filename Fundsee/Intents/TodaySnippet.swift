import AppIntents
import SwiftUI

struct TodaySnippetIntent: SnippetIntent {
    static let title: LocalizedStringResource = "Intent.Remaining.Title"
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult & ShowsSnippetView {
        let today = Date.now
        let engine = IntentData.engine(around: today)
        let categories = (engine.template(for: today)?.sortedCategories ?? []).map {
            CategorySnapshot($0, used: engine.spent(on: today, category: $0))
        }
        return .result(view: TodaySnippetView(
            used: engine.spent(on: today),
            budget: engine.effectiveBudget(for: today),
            categories: categories
        ))
    }
}

struct TodaySnippetView: View {
    let used: Decimal
    let budget: Decimal
    let categories: [CategorySnapshot]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(used.currencyString)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text(String(localized: "Ring.Caption.Of", defaultValue: "of \(budget.currencyString)"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            UsageBar(used: used, budget: budget)
            if !categories.isEmpty {
                LazyVGrid(columns: CategoryGridCell.columns, spacing: CategoryGridCell.spacing) {
                    ForEach(categories) { category in
                        Button(intent: QuickLogIntent(categoryID: category.id)) {
                            CategoryGridCell(category: category)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
    }
}
