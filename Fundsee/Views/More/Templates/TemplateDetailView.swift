import SwiftData
import SwiftUI

struct TemplateDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(BudgetStore.self) private var store
    @Bindable var template: BudgetTemplate

    @State private var notificationsDenied = false

    private static let icons = [
        "building.2.fill", "house.fill", "sofa.fill", "party.popper.fill",
        "airplane", "figure.walk", "cart.fill", "star.fill",
    ]

    var body: some View {
        List {
            Section("Template.Section.Name") {
                TextField("Template.Field.Name", text: $template.name)
            }
            Section("Template.Section.Icon") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                    ForEach(Self.icons, id: \.self) { icon in
                        Button {
                            template.iconName = icon
                        } label: {
                            Image(systemName: icon)
                                .font(.title3)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(
                                    template.iconName == icon ? Color.accentColor.opacity(0.2) : Color.clear,
                                    in: .rect(cornerRadius: 10)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Section("Template.Section.Categories") {
                ForEach(template.sortedCategories) { category in
                    CategoryAmountRow(category: category)
                }
                .onDelete { indexSet in
                    let sorted = template.sortedCategories
                    for index in indexSet {
                        modelContext.delete(sorted[index])
                    }
                    try? modelContext.save()
                }
                Button("Template.AddCategory", systemImage: "plus") {
                    let category = TemplateCategory(
                        name: String(localized: "Template.NewCategory", defaultValue: "New Category"),
                        amount: 0,
                        sortOrder: (template.sortedCategories.last?.sortOrder ?? -1) + 1
                    )
                    category.template = template
                    modelContext.insert(category)
                    try? modelContext.save()
                }
            }
            Section {
                ForEach(template.sortedReminders) { reminder in
                    ReminderRow(reminder: reminder)
                }
                .onDelete { indexSet in
                    let sorted = template.sortedReminders
                    for index in indexSet {
                        modelContext.delete(sorted[index])
                    }
                    try? modelContext.save()
                }
                if template.sortedReminders.count < TemplateReminder.limitPerPlan {
                    Button("Template.AddReminder", systemImage: "plus", action: addReminder)
                }
            } header: {
                Text("Template.Section.Reminders")
            } footer: {
                Text(notificationsDenied ? "Template.Reminders.Footer.Denied" : "Template.Reminders.Footer")
            }
            Section {
                LabeledContent("Template.DailyTotal", value: template.total.currencyString)
                    .font(.headline)
            }
        }
        .navigationTitle(template.name)
        .toolbarTitleDisplayMode(.inline)
        .onDisappear { try? modelContext.save() }
        .task { notificationsDenied = await NotificationService.isDenied() }
    }

    private func addReminder() {
        let reminder = TemplateReminder()
        reminder.template = template
        modelContext.insert(reminder)
        try? modelContext.save()
        Task {
            _ = await NotificationService.requestAuthorization()
            notificationsDenied = await NotificationService.isDenied()
            await NotificationService.reschedule(engine: store.engine())
        }
    }
}
