import Foundation
import Observation

@MainActor
@Observable
final class AppNavigation {
    static let shared = AppNavigation()

    var selectedTab = UserDefaults.standard.string(forKey: "initialTab") ?? "today"
}
