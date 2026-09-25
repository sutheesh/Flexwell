import Foundation
import Observation

/// App-wide presentation state, so any screen can open Adapt, the paywall, Settings or a workout.
@Observable
final class AppRouter {
    enum PaywallReason: String, Identifiable {
        case pivots, travel, adaptiveTargets, history, firstSession, settings
        var id: String { rawValue }
    }

    var tab: AppTab = .today
    var isAdaptPresented = false
    var paywall: PaywallReason?
    var isSettingsPresented = false
    /// Non-nil while a workout is running for that day.
    var workoutDay: Date?
}
