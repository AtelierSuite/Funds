import SwiftData
import SwiftUI

@main
struct FundseeApp: App {
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = true
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var container: ModelContainer

    init() {
        let syncEnabled = UserDefaults.standard.object(forKey: "iCloudSyncEnabled") as? Bool ?? true
        _container = State(initialValue: Self.makeContainer(cloudSync: syncEnabled))
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
            .onChange(of: iCloudSyncEnabled) { _, enabled in
                container = Self.makeContainer(cloudSync: enabled)
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
