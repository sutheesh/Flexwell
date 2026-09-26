import Foundation

/// The "growth since you started" numbers on Today's progress tile: weight, body composition, calories,
/// training and walking. Built from plain values so the app's storage stays out of the engine.
public enum ProgressReport {
    /// Kind of body measurement besides weight.
    public enum BodyMetric: String, Codable, Sendable, CaseIterable {
        case bodyFatPercent, leanMassKg, waistCm
    }

    /// First and latest value of a series (by date), and the change between them. Nil with fewer than one point.
    public struct Change: Sendable, Equatable {
        public let first: Double
        public let latest: Double
        public var delta: Double { latest - first }
    }

    public static func change(_ series: [(date: Date, value: Double)]) -> Change? {
        let sorted = series.sorted { $0.date < $1.date }
        guard let first = sorted.first, let last = sorted.last else { return nil }
        return Change(first: first.value, latest: last.value)
    }

    /// Weight: from the start weight to the latest trend value (smoothed, so one heavy morning doesn't count).
    public static func weightChange(startKg: Double, entries: [WeightEntry]) -> Change? {
        guard let now = WeightTrend.series(entries).last?.kg else { return nil }
        return Change(first: startKg, latest: now)
    }

    public struct WeekCalories: Sendable, Equatable {
        public let weekOf: Date
        public let averageKcal: Int
        public let daysLogged: Int
    }

    /// Average intake per logged day, week by week (weeks start Monday), oldest first.
    public static func weeklyCalories(_ days: [(date: Date, kcal: Int)], calendar: Calendar = .current) -> [WeekCalories] {
        var byWeek: [Date: [Int]] = [:]
        for day in days where day.kcal > 0 {
            byWeek[weekStart(day.date, calendar), default: []].append(day.kcal)
        }
        return byWeek.keys.sorted().map { week in
            let values = byWeek[week] ?? []
            return WeekCalories(weekOf: week, averageKcal: values.reduce(0, +) / max(1, values.count), daysLogged: values.count)
        }
    }

    /// Days whose intake landed within ±10% of that day's target.
    public static func daysOnTarget(_ days: [(kcal: Int, target: Int)]) -> Int {
        days.filter { $0.kcal > 0 && $0.target > 0 && abs(Double($0.kcal - $0.target)) <= Double($0.target) * 0.1 }.count
    }

    public struct Training: Sendable, Equatable {
        public let sessions: Int
        public let hours: Double
        /// Sum of load × reps over loaded sets, in kg.
        public let liftedKg: Double
    }

    /// Sessions, hours trained (each session capped at 3 h so a forgotten timer can't inflate it) and weight lifted.
    public static func training(_ sessions: [(start: Date, end: Date, sets: [SetResult])]) -> Training {
        let hours = sessions.reduce(0.0) { $0 + min(3 * 3600, max(0, $1.end.timeIntervalSince($1.start))) } / 3600
        let lifted = sessions.flatMap(\.sets).reduce(0.0) { $0 + ($1.loadKg ?? 0) * Double($1.value) }
        return Training(sessions: sessions.count, hours: hours, liftedKg: lifted)
    }

    /// Whether the weekly check-in should nudge: no weigh-in for 7 days, or no body measurement for 14.
    public static func checkInDue(lastWeighIn: Date?, lastBodyMetric: Date?, now: Date = .now) -> Bool {
        let week: TimeInterval = 7 * 86_400
        let weighInDue = lastWeighIn.map { now.timeIntervalSince($0) >= week } ?? true
        let metricDue = lastBodyMetric.map { now.timeIntervalSince($0) >= 2 * week } ?? true
        return weighInDue || metricDue
    }

    private static func weekStart(_ date: Date, _ calendar: Calendar) -> Date {
        let day = calendar.startOfDay(for: date)
        let weekday = (calendar.component(.weekday, from: day) + 5) % 7
        return calendar.date(byAdding: .day, value: -weekday, to: day) ?? day
    }
}
