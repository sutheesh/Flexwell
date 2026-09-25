import Foundation
import SwiftData
import FlexFitEngine

// Persisted data is what's on users' phones. Once shipped, changing this without a
// new VersionedSchema + migration stage loses their data.
//
// Every property has a default and nothing is unique, so the store can be mirrored
// to the CloudKit private database later (PRD backup) without a migration.

enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [ProfileRecord.self, DailyLog.self, ExerciseSwap.self, SessionLog.self, WeighIn.self, WeeklyTargets.self, PainFlag.self, IngredientSwapRecord.self, GroceryCheck.self, PantryItem.self, SavedMeal.self] }

    @Model
    final class ProfileRecord {
        var createdAt: Date = Date.now
        var name: String = ""
        /// Stored as birth year (PRD schema), so age stays right over time.
        var birthYear: Int = 0
        var sex: String = Sex.unspecified.rawValue
        var heightCm: Double = 0
        var weightKg: Double = 0
        var displayUnits: String = DisplayUnits.metric.rawValue
        var goal: String = Goal.maintain.rawValue
        var targetWeightKg: Double = 0
        var pacePctPerWeek: Double = 0
        var activity: String = ActivityLevel.seated.rawValue
        var experience: String = Experience.beginner.rawValue
        var trainingDays: Int = 3
        var sessionMinutes: Int = 45
        var environment: String = TrainingEnvironment.homeGym.rawValue
        var equipment: [String] = []
        var limitations: [String] = []
        /// When the user acknowledged the health disclaimer in onboarding.
        var healthNoticeAcceptedAt: Date?
        /// Travel Mode (PRD F5): on while `travelUntil` is in the future.
        var travelKit: String?
        var travelUntil: Date?
        /// Whether the user turned on Apple Health sync.
        var healthSyncEnabled: Bool = false
        /// Created by "Skip to the app": a sample plan until the user builds their own.
        var isSample: Bool = false
        // Food (PRD schema: diet_style, cuisines, allergens, excluded_ingredients, max_cook_minutes).
        var dietStyle: String = DietStyle.highProtein.rawValue
        var cuisines: [String] = []
        var allergens: [String] = []
        var dislikes: [String] = []
        /// 0 = no limit.
        var maxCookMinutes: Int = 0
        var mealPattern: String = MealPattern.threePlusSnack.rawValue
        var history: String = TrainingHistory.firstAttempt.rawValue
        var dailySteps: String = DailySteps.fourToEight.rawValue
        var styles: [String] = []
        var sleep: String = SleepBand.sixToSeven.rawValue
        var budget: String = GroceryBudget.moderate.rawValue
        var shopDay: String = ShopDay.sunday.rawValue
        var reminder: String = ReminderTime.morning.rawValue
        var tone: String = CoachTone.direct.rawValue

        init() {}
    }

    /// One row per calendar day: the energy check-in and the protein check.
    /// Not unique-constrained (CloudKit can't be); look it up by `day`.
    @Model
    final class DailyLog {
        /// Start of the local day.
        var day: Date = Date.now
        var energy: String?
        var soreAreas: [String] = []
        var proteinCheck: String?
        /// Exercises ticked off in this day's session. Set logging (PRD F6) replaces this.
        var completedExercises: [String] = []
        /// Indices (into the day's planned meals) the user marked as eaten.
        var eatenMeals: [Int] = []
        /// "I'm eating out": the order logged in place of dinner.
        var eatenOutName: String?
        var eatenOutKcal: Int = 0
        var eatenOutProteinG: Int = 0
        var updatedAt: Date = Date.now

        init(day: Date) {
            self.day = day
        }
    }

    /// A finished session with its logged sets (PRD F6).
    @Model
    final class SessionLog {
        var day: Date = Date.now
        var startedAt: Date = Date.now
        var finishedAt: Date = Date.now
        var focus: String = ""
        var variant: String = SessionVariant.full.rawValue
        /// JSON of `[LoggedExerciseRecord]`. Kept as one blob so a session saves and syncs atomically.
        var entriesData: Data = Data()
        var savedToHealth: Bool = false

        init(day: Date) { self.day = day }
    }

    /// A body-weight reading: weekly weigh-in or imported from Apple Health (PRD F7).
    @Model
    final class WeighIn {
        var date: Date = Date.now
        var kg: Double = 0
        /// "manual" or "health".
        var source: String = "manual"

        init(date: Date, kg: Double, source: String = "manual") {
            self.date = date
            self.kg = kg
            self.source = source
        }
    }

    /// The targets in force for a week, recalculated weekly (PRD F7).
    @Model
    final class WeeklyTargets {
        /// Monday of the week.
        var weekOf: Date = Date.now
        var calories: Int = 0
        var proteinG: Int = 0
        var carbsG: Int = 0
        var fatG: Int = 0
        var expenditure: Int = 0
        var trendKg: Double?
        var skippedForIntake: Bool = false
        var rapidLossWarning: Bool = false
        var floorApplied: Bool = false

        init(weekOf: Date) { self.weekOf = weekOf }
    }

    /// "I'm missing an ingredient": the swap for one meal on one day.
    @Model
    final class IngredientSwapRecord {
        var day: Date = Date.now
        var mealIndex: Int = 0
        var from: String = ""
        var to: String = ""

        init(day: Date, mealIndex: Int, from: String, to: String) {
            self.day = day
            self.mealIndex = mealIndex
            self.from = from
            self.to = to
        }
    }

    /// A ticked-off grocery item for one week.
    @Model
    final class GroceryCheck {
        var weekOf: Date = Date.now
        var name: String = ""
        init(weekOf: Date, name: String) { self.weekOf = weekOf; self.name = name }
    }

    /// A meal bookmarked from its detail screen.
    @Model
    final class SavedMeal {
        var mealID: Int = 0
        var savedAt: Date = Date.now
        init(mealID: Int) { self.mealID = mealID }
    }

    /// Something the user keeps at home; left off grocery lists (PRD pantry).
    @Model
    final class PantryItem {
        var name: String = ""
        init(name: String) { self.name = name }
    }

    /// "This hurts": the exercise is kept out of the plan until `until` (PRD safety: 7 days).
    @Model
    final class PainFlag {
        var exerciseID: String = ""
        var until: Date = Date.now

        init(exerciseID: String, until: Date) {
            self.exerciseID = exerciseID
            self.until = until
        }
    }

    /// A swap the user chose (PRD F3). `day` set → today only ("machine taken");
    /// `day` nil → applies to future weeks too ("I don't like this").
    @Model
    final class ExerciseSwap {
        var day: Date?
        var originalID: String = ""
        var replacementID: String = ""
        var createdAt: Date = Date.now

        init(day: Date?, originalID: String, replacementID: String) {
            self.day = day
            self.originalID = originalID
            self.replacementID = replacementID
        }
    }
}

typealias ProfileRecord = SchemaV1.ProfileRecord
typealias ExerciseSwap = SchemaV1.ExerciseSwap
typealias SessionLog = SchemaV1.SessionLog
typealias WeighIn = SchemaV1.WeighIn
typealias WeeklyTargets = SchemaV1.WeeklyTargets
typealias PainFlag = SchemaV1.PainFlag
typealias IngredientSwapRecord = SchemaV1.IngredientSwapRecord
typealias GroceryCheck = SchemaV1.GroceryCheck
typealias PantryItem = SchemaV1.PantryItem
typealias SavedMeal = SchemaV1.SavedMeal

struct LoggedExerciseRecord: Codable, Hashable {
    var exerciseID: String
    var sets: [SetResult]
}

extension SessionLog {
    var entries: [LoggedExerciseRecord] {
        get { (try? JSONDecoder().decode([LoggedExerciseRecord].self, from: entriesData)) ?? [] }
        set { entriesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var loggedExercises: [LoggedExercise] {
        entries.map { LoggedExercise(exerciseID: $0.exerciseID, date: day, sets: $0.sets) }
    }
}

extension WeeklyTargets {
    var dailyTargets: DailyTargets {
        DailyTargets(calories: calories, proteinG: proteinG, carbsG: carbsG, fatG: fatG,
                     expenditure: expenditure, floorApplied: floorApplied)
    }

    func apply(_ t: DailyTargets) {
        calories = t.calories
        proteinG = t.proteinG
        carbsG = t.carbsG
        fatG = t.fatG
        expenditure = t.expenditure
        floorApplied = t.floorApplied
    }
}

extension ProfileRecord {
    /// The active travel kit, if Travel Mode is on and hasn't expired.
    func activeTravelKit(now: Date = .now) -> TravelKit? {
        guard let raw = travelKit, let kit = TravelKit(rawValue: raw), let until = travelUntil, until > now else { return nil }
        return kit
    }
}

enum Week {
    /// Monday 00:00 of the week containing `date`.
    static func start(of date: Date) -> Date {
        let cal = Calendar.current
        let day = cal.startOfDay(for: date)
        let weekday = (cal.component(.weekday, from: day) + 5) % 7
        return cal.date(byAdding: .day, value: -weekday, to: day) ?? day
    }
}
typealias DailyLog = SchemaV1.DailyLog

extension DailyLog {
    var energyValue: Energy? {
        get { energy.flatMap(Energy.init(rawValue:)) }
        set { energy = newValue?.rawValue; updatedAt = .now }
    }

    var proteinValue: ProteinCheck? {
        get { proteinCheck.flatMap(ProteinCheck.init(rawValue:)) }
        set { proteinCheck = newValue?.rawValue; updatedAt = .now }
    }

    /// The log for `date`'s day, creating it if needed.
    static func forDay(_ date: Date, in context: ModelContext) -> DailyLog {
        let start = Calendar.current.startOfDay(for: date)
        if let existing = existing(start, in: context) { return existing }
        let log = DailyLog(day: start)
        context.insert(log)
        return log
    }

    static func existing(_ date: Date, in context: ModelContext) -> DailyLog? {
        let start = Calendar.current.startOfDay(for: date)
        var descriptor = FetchDescriptor<DailyLog>(predicate: #Predicate { $0.day == start })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}

enum FlexFitMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

extension ProfileRecord {
    convenience init(profile p: UserProfile, now: Date = .now) {
        self.init()
        update(from: p, now: now)
        healthNoticeAcceptedAt = now
    }

    func update(from p: UserProfile, now: Date = .now) {
        name = p.name
        birthYear = Calendar.current.component(.year, from: now) - p.age
        sex = p.sex.rawValue
        heightCm = p.heightCm
        weightKg = p.weightKg
        displayUnits = p.displayUnits.rawValue
        goal = p.goal.rawValue
        targetWeightKg = p.targetWeightKg
        pacePctPerWeek = p.pacePctPerWeek
        activity = p.activity.rawValue
        experience = p.experience.rawValue
        trainingDays = p.trainingDays
        sessionMinutes = p.sessionMinutes
        environment = p.environment.rawValue
        equipment = p.equipment.map(\.rawValue).sorted()
        limitations = p.limitations.map(\.rawValue).sorted()
        dietStyle = p.diet.rawValue
        cuisines = p.cuisines.map(\.rawValue).sorted()
        allergens = p.allergens.map(\.rawValue).sorted()
        dislikes = p.dislikes.sorted()
        maxCookMinutes = p.maxCookMinutes ?? 0
        mealPattern = p.mealPattern.rawValue
        history = p.history.rawValue
        dailySteps = p.dailySteps.rawValue
        styles = p.styles.map(\.rawValue).sorted()
        sleep = p.sleep.rawValue
        budget = p.budget.rawValue
        shopDay = p.shopDay.rawValue
        reminder = p.reminder.rawValue
        tone = p.tone.rawValue
    }

    func profile(now: Date = .now) -> UserProfile {
        var p = UserProfile(
            name: name,
            age: Calendar.current.component(.year, from: now) - birthYear,
            sex: Sex(rawValue: sex) ?? .unspecified,
            heightCm: heightCm,
            weightKg: weightKg,
            displayUnits: DisplayUnits(rawValue: displayUnits) ?? .metric,
            goal: Goal(rawValue: goal) ?? .maintain,
            targetWeightKg: targetWeightKg,
            pacePctPerWeek: pacePctPerWeek,
            activity: ActivityLevel(rawValue: activity) ?? .seated,
            experience: Experience(rawValue: experience) ?? .beginner,
            trainingDays: trainingDays,
            sessionMinutes: sessionMinutes,
            environment: TrainingEnvironment(rawValue: environment) ?? .homeGym,
            equipment: Set(equipment.compactMap(Equipment.init(rawValue:))),
            limitations: Set(limitations.compactMap(Limitation.init(rawValue:)))
        )
        p.diet = DietStyle(rawValue: dietStyle) ?? .highProtein
        p.cuisines = Set(cuisines.compactMap(Cuisine.init(rawValue:)))
        p.allergens = Set(allergens.compactMap(Allergen.init(rawValue:)))
        p.dislikes = Set(dislikes)
        p.maxCookMinutes = maxCookMinutes > 0 ? maxCookMinutes : nil
        p.mealPattern = MealPattern(rawValue: mealPattern) ?? .threePlusSnack
        p.history = TrainingHistory(rawValue: history) ?? .firstAttempt
        p.dailySteps = DailySteps(rawValue: dailySteps) ?? .fourToEight
        p.styles = Set(styles.compactMap(TrainingStyle.init(rawValue:)))
        p.sleep = SleepBand(rawValue: sleep) ?? .sixToSeven
        p.budget = GroceryBudget(rawValue: budget) ?? .moderate
        p.shopDay = ShopDay(rawValue: shopDay) ?? .sunday
        p.reminder = ReminderTime(rawValue: reminder) ?? .morning
        p.tone = CoachTone(rawValue: tone) ?? .direct
        return p
    }
}
