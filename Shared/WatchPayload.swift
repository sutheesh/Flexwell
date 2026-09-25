import Foundation

/// Today's session as sent to the Watch, and the sets logged there coming back.
struct WatchSession: Codable, Equatable {
    struct Exercise: Codable, Equatable, Identifiable {
        var id: String
        var name: String
        var detail: String
        /// Pre-filled sets: reps (or seconds) and optional load in kg.
        var sets: [WatchSet]
        var isTimed: Bool
    }

    var day: Date
    var title: String
    var subtitle: String
    var exercises: [Exercise]

    static let demo = WatchSession(day: .now, title: "Upper body", subtitle: "45 min · RPE ≤ 8", exercises: [
        Exercise(id: "db_flat_press", name: "Dumbbell Flat Press", detail: "3 × 8–12",
                 sets: Array(repeating: WatchSet(value: 10, loadKg: 22), count: 3), isTimed: false),
        Exercise(id: "kb_row", name: "Kettlebell Row", detail: "3 × 8–12",
                 sets: Array(repeating: WatchSet(value: 10, loadKg: 16), count: 3), isTimed: false),
        Exercise(id: "plank", name: "Forearm Plank", detail: "3 × 30–60 s",
                 sets: Array(repeating: WatchSet(value: 30, loadKg: nil), count: 3), isTimed: true),
    ])
}

struct WatchSet: Codable, Equatable, Hashable {
    var value: Int
    var loadKg: Double?
}

/// Sent from the Watch when the user taps Finish.
struct WatchLoggedSession: Codable, Equatable {
    var day: Date
    var startedAt: Date
    var finishedAt: Date
    /// exerciseID → confirmed sets.
    var entries: [String: [WatchSet]]
}

enum WatchKeys {
    static let session = "session"
    static let logged = "logged"
}
