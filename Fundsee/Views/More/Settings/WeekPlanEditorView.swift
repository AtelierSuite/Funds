import SwiftData
import SwiftUI

struct WeekPlanEditorView: View {
    var isEmbedded = false

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BudgetTemplate.createdAt) private var templates: [BudgetTemplate]
    @Query private var allSettings: [PlanSettings]

    private var calendar: Calendar { .current }

    var body: some View {
        List {
            Section {
                if let settings = allSettings.primary {
                    ForEach(orderedWeekdays(), id: \.self) { weekday in
                        Picker(calendar.weekdaySymbols[weekday - 1], selection: binding(for: weekday, settings: settings)) {
                            Text("Common.None").tag("")
                            ForEach(templates) { template in
                                Text(template.name).tag(template.uuid)
                            }
                        }
                    }
                }
            } footer: {
                Text("WeekPlan.Footer")
            }
        }
        .navigationTitle(isEmbedded ? Text(verbatim: "") : Text("More.WeekPlan"))
        .toolbarTitleDisplayMode(.inline)
    }

    private func orderedWeekdays() -> [Int] {
        (0..<7).map { ((calendar.firstWeekday - 1 + $0) % 7) + 1 }
    }

    private func binding(for weekday: Int, settings: PlanSettings) -> Binding<String> {
        Binding(
            get: { settings.templateUUID(forWeekday: weekday) ?? "" },
            set: { newValue in
                settings.setTemplateUUID(newValue.isEmpty ? nil : newValue, forWeekday: weekday)
                try? modelContext.save()
            }
        )
    }
}
