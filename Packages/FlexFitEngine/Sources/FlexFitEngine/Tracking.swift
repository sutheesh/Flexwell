import Foundation

// MARK: - Weight trend (PRD F7)

public struct WeightEntry: Codable, Sendable, Hashable {
    public var date: Date
    public var kg: Double
    public init(date: Date, kg: Double) { self.date = date; self.kg = kg }
}

public enum WeightTrend {
    public static let alpha = 0.1

    /// Exponentially smoothed trend (α = 0.1) over entries in date order.
    public static func series(_ entries: [WeightEntry]) -> [WeightEntry] {
        var trend: Double?
        return entries.sorted { $0.date < $1.date }.map { e in
            let t = trend.map { $0 + alpha * (e.kg - $0) } ?? e.kg
            trend = t
            return WeightEntry(date: e.date, kg: t)
        }
    }

    /// Trend change over the last 7 days, in kg. Nil without two points a week apart.
    public static func weeklyChange(_ entries: [WeightEntry], asOf now: Date) -> Double? {
        let s = series(entries).filter { $0.date <= now }
        guard let latest = s.last,
              let weekAgo = s.last(where: { $0.date <= latest.date.addingTimeInterval(-6.5 * 86_400) })
        else { return nil }
        let days = latest.date.timeIntervalSince(weekAgo.date) / 86_400
        return (latest.kg - weekAgo.kg) * 7 / max(days, 1)
    }
}

// MARK: - Weekly adaptive targets (PRD F7 + safety)

public struct TargetUpdate: Sendable, Equatable {
    public var targets: DailyTargets
    /// Trend dropped > 1.5%/week for 2 weeks: targets raised; suggest a professional check-in.
    public var rapidLossWarning: Bool
}

public enum AdaptiveTargets {
    public static let maxWeeklyChange = 150

    /// - Parameters:
    ///   - previous: last week's targets (calories = intake target, expenditure = prior estimate).
    ///   - trendChangeKg: weekly trend change (negative = losing).
    ///   - fastLossWeeks: consecutive weeks (including this one) the trend fell faster than 1.5% of body weight.
    public static func weeklyUpdate(profile: UserProfile, previous: DailyTargets, trendChangeKg: Double,
                                    trendWeightKg: Double, fastLossWeeks: Int) -> TargetUpdate {
        let bmr = TargetCalculator.bmr(profile)
        let floor = Int(Safety.calorieFloor(sex: profile.sex, bmr: bmr).rounded(.up))

        if fastLossWeeks >= 2 {
            var t = previous
            t.calories = max(floor, previous.calories + maxWeeklyChange)
            t.carbsG = macroCarbs(calories: t.calories, protein: t.proteinG, fat: t.fatG)
            return TargetUpdate(targets: t, rapidLossWarning: true)
        }

        // Expenditure = intake − (weekly trend change × 7700 / 7), blended 50/50 with the prior estimate.
        let observed = Double(previous.calories) - trendChangeKg * 7_700 / 7
        let expenditure = 0.5 * observed + 0.5 * Double(previous.expenditure)
        let pace = Safety.cappedPace(profile.pacePctPerWeek, goal: profile.goal)
        let delta = pace / 100 * trendWeightKg * 7_700 / 7
        let goal: Double = switch profile.goal {
        case .lose: expenditure - delta
        case .gain: expenditure + delta
        case .maintain: expenditure
        }
        let limited = min(Double(previous.calories + maxWeeklyChange), max(Double(previous.calories - maxWeeklyChange), goal))
        let calories = max(floor, Int((limited / 10).rounded()) * 10)

        var t = previous
        t.calories = calories
        t.expenditure = Int((expenditure / 10).rounded()) * 10
        t.floorApplied = calories == floor
        t.carbsG = macroCarbs(calories: calories, protein: t.proteinG, fat: t.fatG)
        return TargetUpdate(targets: t, rapidLossWarning: false)
    }

    /// Whether this week's trend change counts as rapid loss (> 1.5% of body weight).
    public static func isFastLoss(trendChangeKg: Double, trendWeightKg: Double) -> Bool {
        trendChangeKg < 0 && -trendChangeKg / trendWeightKg > 0.015
    }

    static func macroCarbs(calories: Int, protein: Int, fat: Int) -> Int {
        max(0, Int(((Double(calories) - Double(protein) * 4 - Double(fat) * 9) / 4).rounded()))
    }
}

// MARK: - Streak (PRD F8)

public enum Streak {
    /// Consecutive weeks meeting the planned session count, newest first. Minimum sessions count.
    /// The current week counts once it's met; while it's in progress it doesn't break the streak.
    /// - Parameter sessionsPerWeek: completed sessions per week, index 0 = current week, 1 = last week…
    public static func weeks(sessionsPerWeek: [Int], planned: Int) -> Int {
        guard planned > 0 else { return 0 }
        var count = 0
        for (i, done) in sessionsPerWeek.enumerated() {
            if done >= planned {
                count += 1
            } else if i == 0 {
                continue
            } else {
                break
            }
        }
        return count
    }
}

// MARK: - Progress stats (PRD F8)

public struct LoggedExercise: Sendable, Hashable {
    public var exerciseID: String
    public var date: Date
    public var sets: [SetResult]
    public init(exerciseID: String, date: Date, sets: [SetResult]) {
        self.exerciseID = exerciseID
        self.date = date
        self.sets = sets
    }
}

public struct PersonalRecord: Sendable, Hashable {
    public var exerciseID: String
    public var date: Date
    /// Estimated 1RM for loaded lifts; best reps (or seconds) for bodyweight.
    public var value: Double
    public var isLoad: Bool
}

public enum ProgressStats {
    /// Completed working sets per primary muscle.
    public static func volume(_ logs: [LoggedExercise], library: ExerciseLibrary = .bundled) -> [Muscle: Int] {
        var result: [Muscle: Int] = [:]
        for log in logs {
            guard let ex = library[log.exerciseID], ex.pattern != .mobility, ex.pattern != .conditioning else { continue }
            for m in ex.primaryMuscles { result[m, default: 0] += log.sets.count }
        }
        return result
    }

    /// Best performance per exercise.
    public static func records(_ logs: [LoggedExercise]) -> [PersonalRecord] {
        var best: [String: PersonalRecord] = [:]
        for log in logs {
            for set in log.sets {
                let record: PersonalRecord = if let load = set.loadKg, load > 0 {
                    PersonalRecord(exerciseID: log.exerciseID, date: log.date,
                                   value: Progression.estimatedOneRepMax(loadKg: load, reps: set.value), isLoad: true)
                } else {
                    PersonalRecord(exerciseID: log.exerciseID, date: log.date, value: Double(set.value), isLoad: false)
                }
                if let current = best[log.exerciseID], current.value >= record.value { continue }
                best[log.exerciseID] = record
            }
        }
        return best.values.sorted { $0.date > $1.date }
    }
}

// MARK: - Free tier (PRD Monetization)

public enum FreeTier {
    public static let pivotsPerMonth = 3
    /// Free users see the last 30 days of progress.
    public static let historyDays = 30

    /// A check-in that reshapes the session (Trimmed or Minimum) spends a pivot. High/OK don't.
    public static func spendsPivot(_ result: PivotResult) -> Bool {
        result.variant != .full
    }
}
