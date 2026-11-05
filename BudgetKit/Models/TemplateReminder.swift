import Foundation
import SwiftData

@Model
final class TemplateReminder {
    static let limitPerPlan = 3

    var uuid: String = ""
    var hour: Int = 20
    var minute: Int = 0
    var message: String = ""
    var createdAt: Date = Date.distantPast
    var template: BudgetTemplate?

    init(hour: Int = 20, minute: Int = 0, message: String = "") {
        self.uuid = UUID().uuidString
        self.hour = hour
        self.minute = minute
        self.message = message
        self.createdAt = .now
    }
}
