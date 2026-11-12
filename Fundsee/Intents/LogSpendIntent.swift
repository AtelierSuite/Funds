import AppIntents
import SwiftData

struct LogSpendIntent: AppIntent {
    static let title: LocalizedStringResource = "Intent.LogSpend.Title"
    static let description = IntentDescription("Intent.LogSpend.Description")

    @Parameter(title: "Intent.Parameter.Category")
    var category: CategoryEntity

    @Parameter(title: "Common.Amount", inclusiveRange: (0.01, 1_000_000_000))
    var amount: Double

    @Parameter(title: "Intent.Parameter.Date", kind: .date)
    var date: Date?

    @Parameter(title: "Intent.Parameter.Note")
    var note: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Intent.LogSpend.Summary \(\.$amount) \(\.$category)") {
            \.$date
            \.$note
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<SpendRecordEntity> & ProvidesDialog {
        guard let value = IntentData.amount(amount), value > 0 else {
            throw $amount.needsValueError()
        }
        let day = date ?? .now
        let categories = IntentData.engine(around: day).template(for: day)?.sortedCategories ?? []
        let match = categories.first { $0.uuid == category.id } ?? categories.first { $0.name == category.name }
        let (record, dialog) = try await IntentData.logSpend(
            value,
            categoryID: match?.uuid ?? category.id,
            categoryName: match?.name ?? category.name,
            on: day,
            note: note ?? ""
        )
        return .result(value: record, dialog: dialog)
    }
}

struct LogPaymentIntent: AppIntent {
    static let title: LocalizedStringResource = "Intent.LogPayment.Title"
    static let description = IntentDescription("Intent.LogPayment.Description")

    @Parameter(title: "Common.Amount")
    var amount: IntentCurrencyAmount

    @Parameter(title: "Intent.Parameter.Merchant")
    var merchant: String?

    @Parameter(title: "Intent.Parameter.Category")
    var category: CategoryEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Intent.LogPayment.Summary \(\.$amount) \(\.$merchant)") {
            \.$category
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<SpendRecordEntity> & ProvidesDialog {
        guard amount.amount > 0 else { throw $amount.needsValueError() }
        if let currency = Locale.current.currency?.identifier,
           !amount.currencyCode.isEmpty,
           amount.currencyCode.caseInsensitiveCompare(currency) != .orderedSame {
            throw IntentDataError.currencyMismatch(code: amount.currencyCode)
        }
        let merchantName = merchant?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let categories = IntentData.engine().template(for: .now)?.sortedCategories ?? []
        let match: TemplateCategory?
        if let category {
            match = categories.first { $0.uuid == category.id } ?? categories.first { $0.name == category.name }
        } else {
            match = Self.category(forMerchant: merchantName, in: categories)
        }
        guard let categoryID = match?.uuid ?? category?.id, let categoryName = match?.name ?? category?.name else {
            throw $category.needsValueError(IntentDialog(text: String(
                localized: "Intent.LogPayment.AskCategory",
                defaultValue: "Which category is this payment for?"
            )))
        }
        let (record, dialog) = try await IntentData.logSpend(
            amount.amount,
            categoryID: categoryID,
            categoryName: categoryName,
            on: .now,
            note: merchantName
        )
        return .result(value: record, dialog: dialog)
    }

    @MainActor
    private static func category(forMerchant merchant: String, in categories: [TemplateCategory]) -> TemplateCategory? {
        guard !merchant.isEmpty else { return nil }
        var descriptor = FetchDescriptor<SpendEntry>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        descriptor.fetchLimit = 500
        let recent = (try? IntentData.context.fetch(descriptor)) ?? []
        if let previous = recent.first(where: {
            $0.scope == .day && $0.note.localizedCaseInsensitiveCompare(merchant) == .orderedSame
        }), let match = categories.first(where: { $0.uuid == previous.categoryID })
            ?? categories.first(where: { $0.name == previous.categoryName }) {
            return match
        }
        return categories.first { merchant.localizedStandardContains($0.name) }
    }
}

extension IntentData {
    static func logSpend(
        _ value: Decimal,
        categoryID: String,
        categoryName: String,
        on day: Date,
        note: String
    ) async throws -> (SpendRecordEntity, IntentDialog) {
        let entry = SpendEntry(dayKey: day, categoryName: categoryName, categoryID: categoryID, amount: value)
        entry.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        context.insert(entry)
        try await commit()

        let record = SpendRecordEntity(entry)
        let logged = value.currencyString
        let name = categoryName
        guard Calendar.current.isDateInToday(day) else {
            let dayText = dayLabel(day)
            return (record, IntentDialog(text: String(
                localized: "Intent.LogSpend.Dialog.OnDay",
                defaultValue: "Logged \(logged) for \(name) on \(dayText)."
            )))
        }
        let remaining = engine(around: day).remaining(for: day)
        if remaining >= 0 {
            return (record, IntentDialog(text: String(
                localized: "Intent.LogSpend.Dialog.Left",
                defaultValue: "Logged \(logged) for \(name). \(remaining.currencyString) left today."
            )))
        }
        return (record, IntentDialog(text: String(
            localized: "Intent.LogSpend.Dialog.Over",
            defaultValue: "Logged \(logged) for \(name). You're \((-remaining).currencyString) over today."
        )))
    }
}

struct LogOverallSpendIntent: AppIntent {
    static let title: LocalizedStringResource = "Intent.LogOverall.Title"
    static let description = IntentDescription("Intent.LogOverall.Description")

    @Parameter(title: "Intent.Parameter.OverallBudget")
    var budget: OverallBudgetKind

    @Parameter(title: "Common.Amount", inclusiveRange: (0.01, 1_000_000_000))
    var amount: Double

    @Parameter(title: "Intent.Parameter.Note")
    var note: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Intent.LogOverall.Summary \(\.$amount) \(\.$budget)") {
            \.$note
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<SpendRecordEntity> & ProvidesDialog {
        guard let value = IntentData.amount(amount), value > 0 else {
            throw $amount.needsValueError()
        }
        let entry = SpendEntry(dayKey: .now, categoryName: budget.label, amount: value, scope: budget.scope)
        entry.note = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        IntentData.context.insert(entry)
        try await IntentData.commit()

        let engine = IntentData.engine()
        let interval = budget == .weekly ? engine.weekInterval(containing: .now) : engine.monthInterval(containing: .now)
        let limit = budget == .weekly ? engine.weeklyExtra : engine.monthlyExtra
        let remaining = limit - engine.spent(in: interval, scope: budget.scope)
        let logged = value.currencyString
        let label = budget.label
        let dialog = remaining >= 0
            ? String(localized: "Intent.LogOverall.Dialog.Left", defaultValue: "Logged \(logged) to your \(label). \(remaining.currencyString) left.")
            : String(localized: "Intent.LogOverall.Dialog.Over", defaultValue: "Logged \(logged) to your \(label). You're \((-remaining).currencyString) over.")
        return .result(value: SpendRecordEntity(entry), dialog: IntentDialog(text: dialog))
    }
}

struct GetSpendRecordsIntent: AppIntent {
    static let title: LocalizedStringResource = "Intent.GetRecords.Title"
    static let description = IntentDescription("Intent.GetRecords.Description")

    @Parameter(title: "Intent.Parameter.Date", kind: .date)
    var date: Date?

    @Parameter(title: "Intent.Parameter.Category")
    var category: CategoryEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Intent.GetRecords.Summary \(\.$date)") {
            \.$category
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[SpendRecordEntity]> & ProvidesDialog {
        let day = date ?? .now
        let engine = IntentData.engine(around: day)
        var entries = engine.entries(on: day)
        if let category {
            entries = entries.filter { engine.entry($0, belongsTo: category.id, named: category.name) }
        }
        entries.sort { $0.timestamp > $1.timestamp }
        let total = entries.reduce(Decimal(0)) { $0 + $1.amount }
        let dayText = IntentData.dayLabel(day)
        let names = IntentData.categoryNames()
        let dialog = entries.isEmpty
            ? String(localized: "Intent.GetRecords.Dialog.None", defaultValue: "Nothing recorded for \(dayText).")
            : String(localized: "Intent.GetRecords.Dialog", defaultValue: "\(dayText): \(String(entries.count)) records totaling \(total.currencyString).")
        return .result(value: entries.map { SpendRecordEntity($0, categoryNames: names) }, dialog: IntentDialog(text: dialog))
    }
}

struct EditSpendRecordIntent: AppIntent {
    static let title: LocalizedStringResource = "Intent.EditRecord.Title"
    static let description = IntentDescription("Intent.EditRecord.Description")

    @Parameter(title: "Intent.Parameter.Record")
    var record: SpendRecordEntity

    @Parameter(title: "Common.Amount", inclusiveRange: (0.01, 1_000_000_000))
    var amount: Double?

    @Parameter(title: "Intent.Parameter.Category")
    var category: CategoryEntity?

    @Parameter(title: "Intent.Parameter.Note")
    var note: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Intent.EditRecord.Summary \(\.$record)") {
            \.$amount
            \.$category
            \.$note
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<SpendRecordEntity> & ProvidesDialog {
        let entry = try IntentData.entry(for: record)
        if let amount {
            guard let value = IntentData.amount(amount), value > 0 else { throw $amount.needsValueError() }
            entry.amount = value
        }
        if let category, entry.scope == .day {
            let categories = IntentData.engine(around: entry.dayKey).template(for: entry.dayKey)?.sortedCategories ?? []
            let match = categories.first { $0.uuid == category.id } ?? categories.first { $0.name == category.name }
            entry.categoryName = match?.name ?? category.name
            entry.categoryID = match?.uuid ?? category.id
        }
        if let note {
            entry.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        try await IntentData.commit()
        let updated = SpendRecordEntity(entry)
        let amountText = entry.amount.currencyString
        let name = updated.categoryName
        return .result(value: updated, dialog: IntentDialog(text: String(
            localized: "Intent.EditRecord.Dialog",
            defaultValue: "Updated to \(amountText) for \(name)."
        )))
    }
}

struct DeleteSpendRecordIntent: AppIntent {
    static let title: LocalizedStringResource = "Intent.DeleteRecord.Title"
    static let description = IntentDescription("Intent.DeleteRecord.Description")

    @Parameter(title: "Intent.Parameter.Record")
    var record: SpendRecordEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Intent.DeleteRecord.Summary \(\.$record)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let entry = try IntentData.entry(for: record)
        return try await deleteRecord(entry)
    }
}

struct UndoLastSpendIntent: AppIntent {
    static let title: LocalizedStringResource = "Intent.UndoLast.Title"
    static let description = IntentDescription("Intent.UndoLast.Description")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let entry = IntentData.latestEntry() else { throw IntentDataError.noRecords }
        return try await deleteRecord(entry)
    }
}

private extension AppIntent {
    @MainActor
    func deleteRecord(_ entry: SpendEntry) async throws -> some IntentResult & ProvidesDialog {
        let record = SpendRecordEntity(entry)
        let amountText = entry.amount.currencyString
        let name = record.categoryName
        let dayText = IntentData.dayLabel(entry.dayKey)
        try await requestConfirmation(dialog: IntentDialog(text: String(
            localized: "Intent.DeleteRecord.Confirm",
            defaultValue: "Delete \(amountText) for \(name) from \(dayText)?"
        )))
        IntentData.context.delete(entry)
        try await IntentData.commit()
        return .result(dialog: IntentDialog(text: String(
            localized: "Intent.DeleteRecord.Dialog",
            defaultValue: "Deleted \(amountText) for \(name)."
        )))
    }
}
