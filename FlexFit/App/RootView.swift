import SwiftUI
import SwiftData

enum AppTab: Hashable {
    case today, train, adapt, eat, path
}

/// The app's tab structure. ⚡ Adapt is a tab in the bar but an action in behaviour:
/// selecting it opens the adapt sheet and leaves the current tab selected.
struct RootView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: tabSelection) {
            Tab("Today", systemImage: "house", value: AppTab.today) {
                TodayView()
            }
            Tab("Train", systemImage: "dumbbell", value: AppTab.train) {
                TrainView()
            }
            Tab("Adapt", systemImage: "bolt.fill", value: AppTab.adapt) {
                Color.clear
            }
            Tab("Eat", systemImage: "fork.knife", value: AppTab.eat) {
                EatView()
            }
            Tab("Path", systemImage: "point.topleft.down.to.point.bottomright.curvepath", value: AppTab.path) {
                PathView()
            }
        }
        .sheet(item: $router.sheet) { sheet in
            switch sheet {
            case .adapt: AdaptSheet()
            case .energy: EnergySheet()
            case .settings: SettingsView()
            case .grocery: GroceryView()
            case .restaurant: RestaurantSheet()
            case .paywall(let reason): PaywallView(reason: reason)
            case .ingredientSwap(let selection): RootIngredientSwap(selection: selection)
            }
        }
        .fullScreenCover(item: Binding(
            get: { router.workoutDay.map(WorkoutDay.init) },
            set: { router.workoutDay = $0?.date }
        )) { day in
            WorkoutView(date: day.date)
        }
        .toastOverlay(router)
    }

    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { router.tab },
            set: { newValue in
                if newValue == .adapt {
                    router.isAdaptPresented = true
                } else {
                    router.tab = newValue
                }
            }
        )
    }
}

struct WorkoutDay: Identifiable {
    let date: Date
    var id: Date { date }
}

/// Ingredient swap reachable from anywhere (Adapt, Today, meal detail).
private struct RootIngredientSwap: View {
    let selection: MealSelection
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Query private var profiles: [ProfileRecord]

    var body: some View {
        if let record = profiles.first {
            IngredientSwapSheet(planned: selection.planned, profile: record.profile()) { from, to in
                modelContext.insert(IngredientSwapRecord(day: Calendar.current.startOfDay(for: selection.date),
                                                         mealIndex: selection.planned.index, from: from, to: to))
                try? modelContext.save()
                router.toast("\(from) → \(to). Macros held close.")
            }
        }
    }
}
