import SwiftData
import SwiftUI

struct CarryoverSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allSettings: [PlanSettings]

    var body: some View {
        List {
            if let settings = allSettings.primary {
                Section {
                    ForEach(CarryoverBehavior.allCases) { behavior in
                        Button {
                            settings.carryover = behavior
                            try? modelContext.save()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(behavior.title)
                                        .font(.body.weight(.medium))
                                    Text(behavior.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if settings.carryover == behavior {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                        .tint(.primary)
                    }
                } footer: {
                    Text("Carryover.Footer")
                }
            }
        }
        .navigationTitle("More.Leftovers")
        .toolbarTitleDisplayMode(.inline)
    }
}
