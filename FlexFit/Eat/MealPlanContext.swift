import Foundation
import SwiftData
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

/// Everything eaten on a day: planned meals marked eaten plus logged food (scans, restaurant, manual).
/// The single source every screen reads, so Today, Eat, Restaurant mode and the widget always agree.
struct DayIntake {
    let meals: [PlannedMeal]
    let eatenMealIndices: Set<Int>
    let entries: [FoodEntry]
    let target: Int
    let proteinTarget: Int

    init(context: MealPlanContext, date: Date, logs: [DailyLog], entries: [FoodEntry]) {
        let log = logs.first { Calendar.current.isDate($0.day, inSameDayAs: date) }
        meals = context.meals(on: date)
        eatenMealIndices = Set(log?.eatenMeals ?? [])
        self.entries = entries.filter { Calendar.current.isDate($0.day, inSameDayAs: date) }.sorted { $0.loggedAt < $1.loggedAt }
        target = context.calories(on: date)
        proteinTarget = context.targets.proteinG
    }

    var eatenMeals: [PlannedMeal] { meals.filter { eatenMealIndices.contains($0.index) } }
    /// A restaurant dinner stands in for the planned one.
    var dinnerReplaced: Bool { entries.contains { $0.replacesDinner } }
    var visibleMeals: [PlannedMeal] { meals.filter { !dinnerReplaced || $0.slot != .dinner } }

    var kcal: Int { eatenMeals.reduce(0) { $0 + $1.kcal } + entries.reduce(0) { $0 + $1.kcal } }
    var protein: Int { eatenMeals.reduce(0) { $0 + $1.proteinG } + Int(entries.reduce(0) { $0 + $1.proteinG }.rounded()) }
    var carbs: Int { eatenMeals.reduce(0) { $0 + $1.carbsG } + Int(entries.reduce(0) { $0 + $1.carbsG }.rounded()) }
    var fat: Int { eatenMeals.reduce(0) { $0 + $1.fatG } + Int(entries.reduce(0) { $0 + $1.fatG }.rounded()) }
    var kcalLeft: Int { target - kcal }
    var proteinLeft: Int { proteinTarget - protein }
}

extension DailyLog {
    /// Moves a legacy eaten-out order onto the food log (one-time, per day).
    func migrateEatingOut(into context: ModelContext) {
        guard let name = eatenOutName else { return }
        let entry = FoodEntry(day: day, name: name)
        entry.kcal = eatenOutKcal
        entry.proteinG = Double(eatenOutProteinG)
        entry.source = "restaurant"
        entry.category = "Eating out"
        entry.replacesDinner = true
        context.insert(entry)
        eatenOutName = nil
        eatenOutKcal = 0
        eatenOutProteinG = 0
    }
}
