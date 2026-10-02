import Foundation
import SwiftData
import FlexFitEngine

/// Any day's meals and calories: the week's calorie plan (rest day, cheat days) and that day's meals scaled
/// to it, with saved ingredient swaps applied.
struct MealPlanContext {
    let profile: UserProfile
    let targets: DailyTargets
    let swaps: [IngredientSwapRecord]

    static func weekday(of date: Date) -> Int { (Calendar.current.component(.weekday, from: date) + 5) % 7 }

    /// Days since 1 Jan 2001 (a Monday): what the planner rotates meals by.
    static func dayNumber(of date: Date) -> Int {
        let cal = Calendar.current
        let origin = cal.date(from: DateComponents(year: 2001, month: 1, day: 1)) ?? .distantPast
        return cal.dateComponents([.day], from: origin, to: cal.startOfDay(for: date)).day ?? 0
    }

    /// The week's calories, Monday first.
    var week: CalorieWeek.Week {
        CalorieWeek.week(for: profile, base: targets.calories, expenditure: targets.expenditure)
    }

    func day(on date: Date) -> CalorieWeek.Day { week.days[Self.weekday(of: date)] }

    func meals(on date: Date) -> [PlannedMeal] {
        let start = Calendar.current.startOfDay(for: date)
        let choices = swaps.filter { $0.day == start }
            .map { IngredientSwapChoice(mealIndex: $0.mealIndex, from: $0.from, to: $0.to) }
        let day = day(on: date)
        return MealPlanner.day(dayNumber: Self.dayNumber(of: date), profile: profile,
                               targetCalories: day.plannedCalories, cheatMeal: day.cheat == .meal, swaps: choices)
    }

    func calories(on date: Date) -> Int { day(on: date).calories }

    /// The next meal not yet eaten, by time of day; falls back to the first uneaten one.
    static func nextMeal(_ meals: [PlannedMeal], eaten: Set<Int>, now: Date = .now) -> PlannedMeal? {
        let hour = Double(Calendar.current.component(.hour, from: now)) + Double(Calendar.current.component(.minute, from: now)) / 60
        let open = meals.filter { !eaten.contains($0.index) }
        return open.first { $0.moment.hour + 1.5 >= hour } ?? open.first
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
