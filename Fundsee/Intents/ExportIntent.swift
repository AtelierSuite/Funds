import AppIntents
import SwiftData
import UniformTypeIdentifiers

struct ExportDataIntent: AppIntent {
    static let title: LocalizedStringResource = "Intent.Export.Title"
    static let description = IntentDescription("Intent.Export.Description")

    @Parameter(title: "Intent.Parameter.ExportKind", default: .records)
    var kind: ExportKind

    @Parameter(title: "Intent.Parameter.StartDate", kind: .date)
    var start: Date?

    @Parameter(title: "Intent.Parameter.EndDate", kind: .date)
    var end: Date?

    static var parameterSummary: some ParameterSummary {
        When(\.$kind, .equalTo, .records) {
            Summary("Intent.Export.Summary \(\.$kind)") {
                \.$start
                \.$end
            }
        } otherwise: {
            Summary("Intent.Export.Summary \(\.$kind)")
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let context = IntentData.context
        let url: URL
        switch kind {
        case .records:
            let entries: [SpendEntry]
            if start != nil || end != nil {
                let interval = IntentData.days(from: start ?? .distantPast, through: end ?? .now)
                let lower = interval.start
                let upper = interval.end
                entries = try context.fetch(FetchDescriptor<SpendEntry>(predicate: #Predicate { $0.dayKey >= lower && $0.dayKey < upper }))
            } else {
                entries = try context.fetch(FetchDescriptor<SpendEntry>())
            }
            url = try CSVExporter.exportEntries(entries, categories: context.fetch(FetchDescriptor<TemplateCategory>()))
        case .plans:
            url = try CSVExporter.exportTemplates(context.fetch(FetchDescriptor<BudgetTemplate>()))
        }
        return .result(value: IntentFile(fileURL: url, filename: url.lastPathComponent, type: .commaSeparatedText))
    }
}
