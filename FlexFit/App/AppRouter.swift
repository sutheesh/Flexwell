import Foundation
import SwiftUI
import Observation

/// App-wide presentation state, so any screen can open Adapt, the paywall, Settings or a workout.
/// Every sheet goes through one `sheet` value: stacked `.sheet` modifiers present unreliably.
@Observable
final class AppRouter {
    enum PaywallReason: String, Identifiable {
        case pivots, travel, adaptiveTargets, history, firstSession, settings
        var id: String { rawValue }
    }

    enum Sheet: Identifiable {
        case adapt, energy, settings, grocery, restaurant
        case paywall(PaywallReason)
        case ingredientSwap(MealSelection)
        /// Alternatives for one exercise in the Gym plan, as a bottom sheet.
        case exerciseSwap(SwapRequest)

        var id: String {
            switch self {
            case .adapt: "adapt"
            case .energy: "energy"
            case .settings: "settings"
            case .grocery: "grocery"
            case .restaurant: "restaurant"
            case .paywall(let r): "paywall-\(r.rawValue)"
            case .ingredientSwap(let s): "swap-\(s.id)"
            case .exerciseSwap(let r): "exercise-swap-\(r.originalID)"
            }
        }
    }

    var tab: AppTab = AppRouter.launchTab
    /// The Gym tab's navigation stack, so a swap can return straight to the plan.
    var gymPath = NavigationPath()
    var sheet: Sheet?
    /// Non-nil while a workout is running for that day.
    var workoutDay: Date?
    /// The full-screen food scanner.
    var isScannerPresented = false

    // Convenience flags used across screens; each maps onto `sheet`.
    var isAdaptPresented: Bool { get { isShowing(.adapt) } set { show(.adapt, newValue) } }
    var isEnergyPresented: Bool { get { isShowing(.energy) } set { show(.energy, newValue) } }
    var isSettingsPresented: Bool { get { isShowing(.settings) } set { show(.settings, newValue) } }
    var isGroceryPresented: Bool { get { isShowing(.grocery) } set { show(.grocery, newValue) } }
    var isRestaurantPresented: Bool { get { isShowing(.restaurant) } set { show(.restaurant, newValue) } }
    var paywall: PaywallReason? {
        get { if case .paywall(let r) = sheet { r } else { nil } }
        set { sheet = newValue.map { .paywall($0) } }
    }
    var ingredientSwap: MealSelection? {
        get { if case .ingredientSwap(let s) = sheet { s } else { nil } }
        set { sheet = newValue.map { .ingredientSwap($0) } }
    }

    private func isShowing(_ s: Sheet) -> Bool { sheet?.id == s.id }
    private func show(_ s: Sheet, _ on: Bool) {
        if on { sheet = s } else if isShowing(s) { sheet = nil }
    }

    /// The mock's confirmation toast.
    private(set) var toastMessage: String?
    private var toastTask: Task<Void, Never>?

    @MainActor
    func toast(_ message: String) {
        toastMessage = message
        toastTask?.cancel()
        toastTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.6))
            if !Task.isCancelled { self.toastMessage = nil }
        }
    }
}

extension AppRouter {
    /// `-FFTab train|eat|profile` opens on that tab (DEBUG only; screenshots and UI tests).
    static var launchTab: AppTab {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-FFTab"), i + 1 < args.count {
            switch args[i + 1] {
            case "train": return .train
            case "eat": return .eat
            case "profile": return .profile
            default: break
            }
        }
        #endif
        return .today
    }
}
