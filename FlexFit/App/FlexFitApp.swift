import SwiftUI
import SwiftData

@main
struct FlexFitApp: App {
    let container: ModelContainer

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
    }

    var body: some Scene {
        WindowGroup {
            AppRoot()
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
        }
    }
}
