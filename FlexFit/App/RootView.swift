import SwiftUI

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
        .sheet(isPresented: $router.isAdaptPresented) {
            AdaptSheet()
        }
        .sheet(isPresented: $router.isSettingsPresented) {
            SettingsView()
        }
        .sheet(isPresented: $router.isGroceryPresented) {
            GroceryView()
        }
        .sheet(isPresented: $router.isRestaurantPresented) {
            RestaurantSheet()
        }
        .sheet(item: $router.paywall) { reason in
            PaywallView(reason: reason)
        }
        .fullScreenCover(item: Binding(
            get: { router.workoutDay.map(WorkoutDay.init) },
            set: { router.workoutDay = $0?.date }
        )) { day in
            WorkoutView(date: day.date)
        }
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
