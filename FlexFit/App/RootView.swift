import SwiftUI
import SwiftData

enum AppTab: Hashable {
    case train, today, eat, profile
}

/// The app's tabs — Gym, ⚡ Today (the raised centre button), Eat, and Profile split off to the right —
/// under the mock's floating bar. Path opens from a tile on Today; Adapt from Today's "What changed?".
struct RootView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        // The system tab bar is hidden; the mock's bar floats over the content. The TabView stays so each
        // tab keeps its scroll position and state.
        TabView(selection: $router.tab) {
            Tab(value: AppTab.train) { GymTab().mockTabBarSpace() }
            Tab(value: AppTab.today) { TodayTab().mockTabBarSpace() }
            Tab(value: AppTab.eat) { EatView().mockTabBarSpace() }
            Tab(value: AppTab.profile) { SettingsView(isTab: true).mockTabBarSpace() }
        }
        .overlay {
            // Mock: the bar's bottom edge sits 24 pt above the screen edge, not above the home indicator.
            GeometryReader { geo in
                MockTabBar()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .offset(y: geo.safeAreaInsets.bottom - Size.tabBarBottom)
            }
            .ignoresSafeArea(.keyboard)
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
            case .exerciseSwap(let request): SwapSheet(request: request)
            }
        }
        // Full-screen covers hang off separate views: stacked presentation modifiers on one view are unreliable.
        .background {
            Color.clear.fullScreenCover(item: Binding(
                get: { router.workoutDay.map(WorkoutDay.init) },
                set: { router.workoutDay = $0?.date }
            )) { day in
                WorkoutView(date: day.date)
            }
        }
        .background {
            Color.clear.fullScreenCover(isPresented: $router.isScannerPresented) {
                FoodScannerView()
            }
        }
        .toastOverlay(router)
    }
}

/// Today, with Path pushed from its tile (the tab bar stays).
private struct TodayTab: View {
    var body: some View {
        NavigationStack {
            TodayView()
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: TodayRoute.self) { route in
                    switch route {
                    case .path: PathView(isPushed: true)
                        .toolbar(.visible, for: .navigationBar)
                        .navigationTitle("")
                    case .progress: ProgressDetailView()
                        .toolbar(.visible, for: .navigationBar)
                        .navigationTitle("")
                    }
                }
        }
    }
}

/// Gym (Train + the exercise library), with its muscle lists, swap lists and exercise pages pushed on top.
/// Always navy.
private struct GymTab: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.gymPath) {
            TrainView()
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: GymRoute.self) { route in
                    switch route {
                    case .group(let group): MuscleGroupView(group: group).toolbar(.visible, for: .navigationBar)
                    case .exercise(let id): ExerciseDetailView(exerciseID: id).toolbar(.visible, for: .navigationBar)
                    case .swapDetail(let choice): ExerciseDetailView(exerciseID: choice.candidateID, swap: choice)
                        .toolbar(.visible, for: .navigationBar)
                    }
                }
        }
        .environment(\.colorScheme, .dark)
    }
}

enum TodayRoute: Hashable {
    case path, progress
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

private extension View {
    /// Hides the system tab bar and keeps content clear of the floating one. Content margins are inherited by
    /// every scroll view inside, including pages pushed on a tab's navigation stack (safe-area padding isn't).
    func mockTabBarSpace() -> some View {
        toolbar(.hidden, for: .tabBar)
            .contentMargins(.bottom, Size.tabBar + Space.md, for: .scrollContent)
            .contentMargins(.bottom, Size.tabBar, for: .scrollIndicators)
    }
}
