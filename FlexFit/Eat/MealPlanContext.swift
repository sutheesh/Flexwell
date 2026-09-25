import Foundation
import FlexFitEngine

/// Any day's meals: the week plan scaled to that day's calorie target, with saved ingredient swaps applied.
struct MealPlanContext {
    let profile: UserProfile
    let targets: DailyTargets
    let swaps: [IngredientSwapRecord]

    static func weekday(of date: Date) -> Int { (Calendar.current.component(.weekday, from: date) + 5) % 7 }

    func meals(on date: Date) -> [PlannedMeal] {
        let start = Calendar.current.startOfDay(for: date)
        let choices = swaps.filter { $0.day == start }
            .map { IngredientSwapChoice(mealIndex: $0.mealIndex, from: $0.from, to: $0.to) }
        return MealPlanner.day(weekday: Self.weekday(of: date), profile: profile,
                               targetCalories: calories(on: date), swaps: choices)
    }

    /// The mock's day target: full on training and recovery days, 150 kcal lower on the full-rest day.
    func calories(on date: Date) -> Int {
        Self.calories(base: targets.calories, kind: WeekPlanner.week(for: profile)[Self.weekday(of: date)].kind)
    }

    static let restDayReduction = 150

    static func calories(base: Int, kind: DayKind) -> Int {
        kind == .rest ? base - restDayReduction : base
    }

    /// The next meal not yet eaten, by time of day; falls back to the first uneaten one.
    static func nextMeal(_ meals: [PlannedMeal], eaten: Set<Int>, now: Date = .now) -> PlannedMeal? {
        let hour = Double(Calendar.current.component(.hour, from: now)) + Double(Calendar.current.component(.minute, from: now)) / 60
        let open = meals.filter { !eaten.contains($0.index) }
        return open.first { $0.slot.hour + 1.5 >= hour } ?? open.first
    }
}

struct MealSelection: Identifiable {
    let date: Date
    let planned: PlannedMeal
    var id: String { "\(date.timeIntervalSince1970)-\(planned.id)" }
}
