import SwiftUI
import SwiftData

@main
struct FlexFitApp: App {
    let container: ModelContainer
    // Created once here, in init, so the instance wired into the entitlements is the one the app keeps.
    let entitlements: EntitlementService
    let store: StoreService
    @State private var router = AppRouter()

    init() {
        container = Self.makeContainer()
        DebugLaunch.apply(to: container)
        let container = self.container
        Task { @MainActor in WatchSync.shared.activate(container: container) }
        let entitlements = EntitlementService()
        self.entitlements = entitlements
        self.store = StoreService(entitlements: entitlements)
    }

    /// Backed up to the user's own iCloud (CloudKit private database, PRD "Backup/sync").
    /// If CloudKit can't start (no iCloud account, UI tests), fall back to a local store so the app always opens.
    private static func makeContainer() -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let useCloud = !ProcessInfo.processInfo.arguments.contains("-FFLocalOnly")
        if useCloud,
           let container = try? ModelContainer(for: schema, migrationPlan: FlexFitMigrationPlan.self,
                                               configurations: ModelConfiguration(schema: schema, cloudKitDatabase: .private(cloudContainer))) {
            return container
        }
        do {
            return try ModelContainer(for: schema, migrationPlan: FlexFitMigrationPlan.self,
                                      configurations: ModelConfiguration(schema: schema, cloudKitDatabase: .none))
        } catch {
            fatalError("Could not open the data store: \(error)")
        }
    }

    static let cloudContainer = "iCloud.com.ilabbs.flexfit"

    var body: some Scene {
        WindowGroup {
            AppRoot()
                .environment(entitlements)
                .environment(store)
                .environment(router)
                .task { await store.refreshPurchaseStatus() }
        }
        .modelContainer(container)
    }
}

/// Onboarding until a profile exists, then the tabs.
struct AppRoot: View {
    @Query private var profiles: [ProfileRecord]

    var body: some View {
        if profiles.isEmpty {
            OnboardingFlow()
        } else {
            RootView()
                .weeklyTargetsUpkeep()
        }
    }
}
