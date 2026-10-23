import SwiftData
import SwiftUI

struct MoreView: View {
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = true

    @Environment(\.modelContext) private var modelContext

    @State private var exportURL: URL?
    @State private var templatesExportURL: URL?

    var body: some View {
        NavigationStack {
            List {
                Section("More.Section.BudgetSetup") {
                    NavigationLink {
                        TemplatesEditorView()
                    } label: {
                        SettingsLabel(title: "More.BudgetTemplates", systemImage: AppSymbol.budgetTemplate, color: .green)
                    }
                    NavigationLink {
                        WeekPlanEditorView()
                    } label: {
                        SettingsLabel(title: "More.WeekPlan", systemImage: "calendar", color: .blue)
                    }
                    NavigationLink {
                        OverallBudgetsView()
                    } label: {
                        SettingsLabel(title: "More.OverallBudgets", systemImage: "basket.fill", color: .teal)
                    }
                }

                Section("More.Section.Behavior") {
                    NavigationLink {
                        CarryoverSettingsView()
                    } label: {
                        SettingsLabel(title: "More.Leftovers", systemImage: "arrow.uturn.forward", color: .orange)
                    }
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        SettingsLabel(title: "More.Notifications", systemImage: "bell.badge.fill", color: .red)
                    }
                }

                Section {
                    Toggle(isOn: $iCloudSyncEnabled) {
                        SettingsLabel(title: "More.ICloudSync", systemImage: "icloud.fill", color: .cyan)
                    }
                } footer: {
                    Text("More.ICloudSync.Footer")
                }

                Section("More.Section.Export") {
                    Button("More.ExportSpending") {
                        exportURL = try? CSVExporter.exportEntries(modelContext.fetch(FetchDescriptor<SpendEntry>()))
                    }
                    Button("More.ExportTemplates") {
                        templatesExportURL = try? CSVExporter.exportTemplates(modelContext.fetch(FetchDescriptor<BudgetTemplate>()))
                    }
                }

                Section {
                    Link(destination: URL(string: "https://github.com/AtelierSuite/Funds")!) {
                        HStack {
                            SettingsLabel(
                                title: "More.SourceCode",
                                systemImage: "chevron.left.forwardslash.chevron.right",
                                color: .gray
                            )
                            Spacer()
                            Text(verbatim: "AtelierSuite/Funds")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(.primary)
                }
            }
            .navigationTitle("More.Title")
            .toolbarTitleDisplayMode(.inlineLarge)
            .sheet(item: $exportURL) { url in
                ShareSheet(url: url)
            }
            .sheet(item: $templatesExportURL) { url in
                ShareSheet(url: url)
            }
        }
    }
}
