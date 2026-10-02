import Foundation

/// The week's calorie targets: the daily target, a little lower on the full-rest day, higher on cheat days,
/// and — when the user chose to pay for cheat days — a small cut on the other days that never goes below
/// the safety floor.
public enum CalorieWeek {
    /// The full-rest day eats this much less than training days.
    public static let restDayReduction = 150
    /// A cheat meal's calories on top of the dinner it replaces.
    public static let cheatMealExtra = 400

    public struct Day: Sendable, Equatable {
        /// The day's calorie target.
        public var calories: Int
        public var cheat: CheatDays.Style?
        /// On a cheat-meal day: the free meal's calories (part of `calories`).
        public var cheatMealKcal: Int?
        /// What the day would be without cheat days: the difference is this day's share of paying for them.
        public var plain: Int

        /// Calories for the planned meals: all of them, less the free meal on a cheat-meal day.
        public var plannedCalories: Int { calories - (cheatMealKcal ?? 0) }
    }

    public struct Week: Sendable, Equatable {
        /// Monday first.
        public var days: [Day]
        /// Cheat calories the other days couldn't pay for (all of them when the goal date is left to move).
        public var unpaidKcal: Int
    }

    /// The week (Monday first) for `profile` around the daily target `base`.
    public static func week(for profile: UserProfile, base: Int, expenditure: Int) -> Week {
        let kinds = WeekPlanner.week(for: profile).map(\.kind)
        let plain = kinds.map { $0 == .rest ? base - restDayReduction : base }
        let cheat = profile.cheatDays
        let cheatDays = Set(cheat.activeWeekdays)
        var days = plain.map { Day(calories: $0, cheat: nil, cheatMealKcal: nil, plain: $0) }

        var extra = 0
        for i in cheatDays {
            switch cheat.style {
            case .day:
                // About maintenance, and never less than a fifth over the usual day.
                let target = roundTo10(max(Double(plain[i]) * 1.2, Double(expenditure)))
                days[i].calories = target
                extra += target - plain[i]
            case .meal:
                let meal = roundTo10(Double(plain[i]) * MealMoment.dinner.share * 0.9) + cheatMealExtra
                days[i].calories = plain[i] + cheatMealExtra
                days[i].cheatMealKcal = meal
                extra += cheatMealExtra
            }
            days[i].cheat = cheat.style
        }

        guard cheat.budget == .spread, extra > 0 else { return Week(days: days, unpaidKcal: extra) }
        let floor = Int(Safety.calorieFloor(sex: profile.sex, bmr: TargetCalculator.bmr(profile)).rounded(.up))
        let others = (0..<7).filter { !cheatDays.contains($0) }
        var left = extra
        // Share it evenly; days that hit the floor pass their part on to the others.
        var open = others.filter { days[$0].calories > floor }
        while left > 0, !open.isEmpty {
            let each = max(1, left / open.count)
            for i in open where left > 0 {
                let cut = min(each, days[i].calories - floor, left)
                days[i].calories -= cut
                left -= cut
            }
            open = open.filter { days[$0].calories > floor }
        }
        // Whole tens read better. Rounding stays within a few calories of the week, never lifts a day above
        // its usual target and never drops one below the floor.
        let floor10 = Int((Double(floor) / 10).rounded(.up)) * 10
        for i in others where days[i].calories != days[i].plain {
            days[i].calories = min(days[i].plain, max(floor10, roundTo10(Double(days[i].calories))))
        }
        return Week(days: days, unpaidKcal: left)
    }

    static func roundTo10(_ v: Double) -> Int { Int((v / 10).rounded()) * 10 }
}
