import SwiftData
import SwiftUI

struct SpendInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Environment(BudgetStore.self) private var store

    let date: Date
    let categoryName: String
    let categoryID: String?
    let scope: SpendScope
    let period: DateInterval?

    @Query private var periodEntries: [SpendEntry]

    @State private var amount: Decimal?
    @State private var recentAmounts: [Decimal] = []
    @FocusState private var amountFocused: Bool

    init(date: Date, categoryName: String, categoryID: String? = nil, scope: SpendScope = .day, period: DateInterval? = nil) {
        self.date = date
        self.categoryName = categoryName
        self.categoryID = categoryID
        self.scope = scope
        self.period = period
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let start = period?.start ?? dayStart
        let end = period?.end ?? calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let scopeRaw = scope.rawValue
        _periodEntries = Query(
            filter: #Predicate { $0.dayKey >= start && $0.dayKey < end && $0.scopeRaw == scopeRaw },
            sort: \.timestamp,
            order: .reverse
        )
    }

    private var recordedEntries: [SpendEntry] {
        guard scope == .day else { return periodEntries }
        let engine = store.engine(around: date)
        return periodEntries.filter { engine.entry($0, belongsTo: categoryID ?? "", named: categoryName) }
    }

    private var recordedTitle: String {
        if period != nil {
            return String(localized: "SpendInput.Recorded", defaultValue: "Recorded")
        }
        if date.isToday {
            return String(localized: "Common.TodaysSpend", defaultValue: "Today's Spend")
        }
        let day = date.formatted(.dateTime.month(.abbreviated).day())
        return String(localized: "Common.SpendOnDate", defaultValue: "Spend on \(day)")
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    inputArea
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                if !recordedEntries.isEmpty {
                    Section(recordedTitle) {
                        ForEach(recordedEntries) { entry in
                            HStack {
                                Text(period == nil
                                     ? entry.timestamp.formatted(date: .omitted, time: .shortened)
                                     : entry.dayKey.formatted(date: .abbreviated, time: .omitted))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(entry.amount.currencyString)
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            }
                            .swipeActions(edge: .trailing) {
                                Button("Common.Delete", systemImage: "trash", role: .destructive) {
                                    modelContext.delete(entry)
                                    try? modelContext.save()
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle(categoryName)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("SpendInput.Add") {
                        if let amount, amount > 0 {
                            modelContext.insert(SpendEntry(dayKey: date, categoryName: categoryName, categoryID: categoryID ?? "", amount: amount, scope: scope))
                            try? modelContext.save()
                        }
                        dismiss()
                    }
                    .disabled((amount ?? 0) <= 0)
                }
            }
            .onAppear {
                amountFocused = true
                recentAmounts = store.recentAmounts(categoryID: categoryID, name: categoryName, scope: scope)
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var inputArea: some View {
        VStack(spacing: 24) {
            Text(date.formatted(date: .abbreviated, time: .omitted))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("Common.Amount", value: $amount, format: .number)
                .keyboardType(.decimalPad)
                .focused($amountFocused)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if !recentAmounts.isEmpty {
                GlassEffectContainer {
                    HStack(spacing: 12) {
                        ForEach(recentAmounts, id: \.self) { recent in
                            Button {
                                amount = recent
                            } label: {
                                Text(recent.currencyString)
                                    .font(.callout.weight(.semibold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.glass)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
}
