import SwiftData
import SwiftUI

struct OverallBudgetsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allSettings: [PlanSettings]

    var body: some View {
        List {
            if let settings = allSettings.primary {
                @Bindable var settings = settings
                Section {
                    TextField("Common.Amount", value: $settings.weeklyOverallBudget, format: .number)
                        .keyboardType(.decimalPad)
                } header: {
                    Text("OverallBudgets.Weekly.Header")
                } footer: {
                    Text("OverallBudgets.Weekly.Footer")
                }
                Section {
                    TextField("Common.Amount", value: $settings.monthlyOverallBudget, format: .number)
                        .keyboardType(.decimalPad)
                } header: {
                    Text("OverallBudgets.Monthly.Header")
                } footer: {
                    Text("OverallBudgets.Monthly.Footer")
                }
            }
        }
        .navigationTitle("More.OverallBudgets")
        .toolbarTitleDisplayMode(.inline)
        .onDisappear { try? modelContext.save() }
    }
}
