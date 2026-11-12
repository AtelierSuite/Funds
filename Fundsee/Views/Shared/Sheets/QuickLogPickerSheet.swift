import SwiftUI

struct QuickLogPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(BudgetStore.self) private var store

    let onPick: (SpendTarget) -> Void

    private var today: Date { Calendar.current.startOfDay(for: .now) }

    var body: some View {
        let engine = store.engine(around: today)
        let categories = engine.template(for: today)?.sortedCategories ?? []
        NavigationStack {
            ScrollView {
                if categories.isEmpty {
                    ContentUnavailableView(
                        "Today.NoTemplate.Title",
                        systemImage: "square.dashed",
                        description: Text("Today.NoTemplate.Description")
                    )
                } else {
                    LazyVGrid(columns: CategoryGridCell.columns, spacing: CategoryGridCell.spacing) {
                        ForEach(categories) { category in
                            Button {
                                onPick(SpendTarget(name: category.name, categoryID: category.uuid))
                            } label: {
                                CategoryGridCell(category: CategorySnapshot(category, used: engine.spent(on: today, category: category)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("QuickLog.Title")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
