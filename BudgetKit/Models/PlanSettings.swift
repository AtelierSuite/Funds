import Foundation
import SwiftData

@Model
final class PlanSettings {
    var weekdayTemplateUUIDs: [String] = ["", "", "", "", "", "", ""]
    var weeklyOverallBudget: Decimal = 0
    var monthlyOverallBudget: Decimal = 0
    var carryoverRaw: String = CarryoverBehavior.leaveAsIs.rawValue
    var createdAt: Date = Date.distantPast

    init() {
        createdAt = .now
    }

    var carryover: CarryoverBehavior {
        get { CarryoverBehavior(rawValue: carryoverRaw) ?? .leaveAsIs }
        set { carryoverRaw = newValue.rawValue }
    }

    func templateUUID(forWeekday weekday: Int) -> String? {
        let index = weekday - 1
        guard weekdayTemplateUUIDs.indices.contains(index) else { return nil }
        let id = weekdayTemplateUUIDs[index]
        return id.isEmpty ? nil : id
    }

    func setTemplateUUID(_ uuid: String?, forWeekday weekday: Int) {
        var ids = weekdayTemplateUUIDs
        while ids.count < 7 { ids.append("") }
        ids[weekday - 1] = uuid ?? ""
        weekdayTemplateUUIDs = ids
    }
}
