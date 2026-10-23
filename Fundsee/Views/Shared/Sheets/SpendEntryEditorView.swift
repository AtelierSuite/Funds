import SwiftData
import SwiftUI

struct SpendEntryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let entry: SpendEntry

    @State private var amount: Decimal?
    @State private var day: Date
    @State private var note: String

    init(entry: SpendEntry) {
        self.entry = entry
        _amount = State(initialValue: entry.amount)
        _day = State(initialValue: entry.dayKey)
        _note = State(initialValue: entry.note)
    }

    var body: some View {
        Form {
            Section {
                TextField("Common.Amount", value: $amount, format: .number)
                    .keyboardType(.decimalPad)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                DatePicker("EntryEditor.Date", selection: $day, displayedComponents: .date)
                TextField("EntryEditor.Note", text: $note, axis: .vertical)
            }
            Section {
                Button("EntryEditor.Delete", role: .destructive) {
                    modelContext.delete(entry)
                    try? modelContext.save()
                    dismiss()
                }
            }
        }
        .navigationTitle("EntryEditor.Title")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(role: .confirm) { save() }
                    .disabled((amount ?? 0) <= 0)
            }
        }
    }

    private func save() {
        guard let amount, amount > 0 else { return }
        entry.amount = amount
        entry.dayKey = Calendar.current.startOfDay(for: day)
        entry.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        try? modelContext.save()
        dismiss()
    }
}
