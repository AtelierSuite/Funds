import Foundation
import Observation

struct QuickLogRequest: Equatable {
    let id = UUID()
    let categoryID: String?
}

@MainActor
@Observable
final class AppNavigation {
    static let shared = AppNavigation()

    var selectedTab = UserDefaults.standard.string(forKey: "initialTab") ?? "today"
    var quickLog: QuickLogRequest?
    var recordID: String?
    var planID: String?
}
