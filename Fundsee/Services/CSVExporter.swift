import Foundation

enum CSVExporter {
    static func exportEntries(_ entries: [SpendEntry], categories: [TemplateCategory]) throws -> URL {
        var namesByID: [String: String] = [:]
        for category in categories where !category.uuid.isEmpty {
            namesByID[category.uuid] = category.name
        }
        var csv = "Date,Time,Category,Amount,Currency,Note\n"
        let currency = Locale.current.currency?.identifier ?? "USD"
        let dateFormat = Date.FormatStyle(date: .numeric, time: .omitted).locale(Locale(identifier: "en_US_POSIX"))
        let timeFormat = Date.FormatStyle(date: .omitted, time: .standard).locale(Locale(identifier: "en_US_POSIX"))
        for entry in entries.sorted(by: { $0.timestamp < $1.timestamp }) {
            let fields = [
                entry.dayKey.formatted(dateFormat),
                entry.timestamp.formatted(timeFormat),
                escape(namesByID[entry.categoryID] ?? entry.categoryName),
                "\(entry.amount)",
                currency,
                escape(entry.note),
            ]
            csv += fields.joined(separator: ",") + "\n"
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Funds-Export-\(Date.now.formatted(.iso8601.year().month().day())).csv")
        try csv.data(using: .utf8)?.write(to: url, options: .atomic)
        return url
    }

    static func exportTemplates(_ templates: [BudgetTemplate]) throws -> URL {
        var csv = "Template,Category,Amount,Currency\n"
        let currency = Locale.current.currency?.identifier ?? "USD"
        for template in templates.sorted(by: { $0.createdAt < $1.createdAt }) {
            for category in template.sortedCategories {
                csv += [escape(template.name), escape(category.name), "\(category.amount)", currency]
                    .joined(separator: ",") + "\n"
            }
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Funds-Templates.csv")
        try csv.data(using: .utf8)?.write(to: url, options: .atomic)
        return url
    }

    private static func escape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }
}
