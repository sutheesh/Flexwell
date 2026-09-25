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
        do {
            container = try ModelContainer(
                for: Schema(versionedSchema: SchemaV1.self),
                migrationPlan: FlexFitMigrationPlan.self
            )
        } catch {
            fatalError("Could not open the data store: \(error)")
        }
        DebugLaunch.apply(to: container)
        let entitlements = EntitlementService()
        self.entitlements = entitlements
        self.store = StoreService(entitlements: entitlements)
    }

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
