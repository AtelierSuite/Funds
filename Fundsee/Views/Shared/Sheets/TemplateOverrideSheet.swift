import SwiftData
import SwiftUI

struct TemplateOverrideSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let initialDate: Date

    @Environment(BudgetStore.self) private var store
    @Query(sort: \BudgetTemplate.createdAt) private var templates: [BudgetTemplate]

    private var date: Date { initialDate }

    private var engine: BudgetEngine { store.engine(around: date) }

    var body: some View {
        NavigationStack {
            List {
                Section("TemplateOverride.Section.Template") {
                    ForEach(templates) { template in
                        Button {
                            apply(template)
                        } label: {
                            HStack {
                                Label(template.name, systemImage: template.iconName)
                                Spacer()
                                Text(template.total.currencyString)
                                    .foregroundStyle(.secondary)
                                if engine.template(for: date) === template {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                        .tint(.primary)
                    }
                }

                if engine.override(for: date) != nil {
                    Section {
                        Button("TemplateOverride.Remove", role: .destructive) {
                            removeOverride()
                        }
                    } footer: {
                        Text("TemplateOverride.Remove.Footer")
                    }
                }
            }
            .navigationTitle("Common.ChangeTemplate")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func apply(_ template: BudgetTemplate) {
        removeOverride()
        modelContext.insert(DayOverride(dayKey: date, template: template))
        try? modelContext.save()
        dismiss()
    }

    private func removeOverride() {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        let descriptor = FetchDescriptor<DayOverride>(predicate: #Predicate { $0.dayKey >= start && $0.dayKey < end })
        for override in (try? modelContext.fetch(descriptor)) ?? [] {
            modelContext.delete(override)
        }
        try? modelContext.save()
    }
}
