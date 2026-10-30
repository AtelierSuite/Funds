import Foundation

extension DateInterval {
    var weekRangeLabel: String {
        let lastDay = Calendar.current.date(byAdding: .day, value: -1, to: end) ?? end
        return (start..<lastDay).formatted(.interval.month(.defaultDigits).day())
    }
}
