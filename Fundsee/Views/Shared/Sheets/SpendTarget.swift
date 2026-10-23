import Foundation

struct SpendTarget: Identifiable, Hashable {
    let name: String
    var categoryID: String?
    var scope: SpendScope = .day
    var period: DateInterval?

    var id: String { name }
}
