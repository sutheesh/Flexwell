import Foundation

/// What the home-screen widgets show, written by the app into the shared app group.
struct WidgetSnapshot: Codable, Equatable {
    static let appGroup = "group.com.ilabbs.flexfit"
    static let fileName = "widget-snapshot.json"

    var date: Date
    var sessionTitle: String
    var sessionDetail: String
    var isTrainingDay: Bool
    var kcalEaten: Int
    var kcalTarget: Int
    var proteinTarget: Int
    var streakWeeks: Int
    var nextMeal: String?

    static let placeholder = WidgetSnapshot(date: .now, sessionTitle: "Upper body", sessionDetail: "45 min · 5 exercises",
                                            isTrainingDay: true, kcalEaten: 990, kcalTarget: 2_090, proteinTarget: 150,
                                            streakWeeks: 3, nextMeal: "Chicken Tikka Rice Bowl")

    private static var url: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?.appendingPathComponent(fileName)
    }

    static func load() -> WidgetSnapshot? {
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    func save() {
        guard let url = Self.url, let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
