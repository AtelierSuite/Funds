import SwiftData
import SwiftUI

@main
struct FundseeApp: App {
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = true
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var container: ModelContainer
    @State private var store: BudgetStore

    init() {
        let syncEnabled = UserDefaults.standard.object(forKey: "iCloudSyncEnabled") as? Bool ?? true
        let container = Self.makeContainer(cloudSync: syncEnabled)
        _container = State(initialValue: container)
        _store = State(initialValue: BudgetStore(context: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    ContentView()
                } else {
                    OnboardingView()
                }
            }
            .modelContainer(container)
            .environment(store)
            .onChange(of: iCloudSyncEnabled) { _, enabled in
                container = Self.makeContainer(cloudSync: enabled)
                store = BudgetStore(context: container.mainContext)
            }
        }
    }

    static func makeContainer(cloudSync: Bool) -> ModelContainer {
        let schema = AppGroup.schema
        let configuration = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier(AppGroup.identifier),
            cloudKitDatabase: cloudSync ? .automatic : .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            let localConfiguration = ModelConfiguration(
                schema: schema,
                groupContainer: .identifier(AppGroup.identifier),
                cloudKitDatabase: .none
            )
            do {
                return try ModelContainer(for: schema, configurations: [localConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }
}
