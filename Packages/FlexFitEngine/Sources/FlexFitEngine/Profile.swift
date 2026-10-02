/// The user's answers from onboarding, in metric. The app persists this; the engine only reads it.
public struct UserProfile: Codable, Sendable, Equatable {
    public var name: String
    public var age: Int
    public var sex: Sex
    public var heightCm: Double
    public var weightKg: Double
    public var displayUnits: DisplayUnits
    public var goal: Goal
    /// Equal to `weightKg` when the goal is `.maintain`.
    public var targetWeightKg: Double
    /// Percent of body weight per week. 0 when maintaining. Capped by `Safety.maxLossPacePct`.
    public var pacePctPerWeek: Double
    public var activity: ActivityLevel
    public var experience: Experience
    public var trainingDays: Int
    public var sessionMinutes: Int
    public var environment: TrainingEnvironment
    public var equipment: Set<Equipment>
    public var limitations: Set<Limitation>
    // Food (PRD schema: diet_style, cuisines, allergens, excluded_ingredients, max_cook_minutes).
    public var diet: DietStyle = .highProtein
    public var cuisines: Set<Cuisine> = []
    /// Hard filter, always.
    public var allergens: Set<Allergen> = []
    /// Soft filter: ingredient keywords the user won't eat.
    public var dislikes: Set<String> = []
    /// Hard filter: proteins the user doesn't eat (everything is eaten unless listed).
    public var excludedProteins: Set<Protein> = []
    /// Hard filter: halal, Jain.
    public var foodRules: Set<FoodRule> = []
    /// Which snacks to lean towards.
    public var snackTaste: SnackTaste = .both
    /// Nil = no limit.
    public var maxCookMinutes: Int?
    /// Main meals a day; snacks come on top (see `snacksBetweenMeals`).
    public var mealPattern: MealPattern = .three
    /// A light snack between breakfast and lunch and another between lunch and dinner.
    public var snacksBetweenMeals = true
    public var cheatDays = CheatDays()
    // The rest of the mock's wizard.
    public var history: TrainingHistory = .firstAttempt
    public var dailySteps: DailySteps = .fourToEight
    public var styles: Set<TrainingStyle> = []
    public var sleep: SleepBand = .sixToSeven
    public var budget: GroceryBudget = .moderate
    public var shopDay: ShopDay = .sunday
    public var reminder: ReminderTime = .morning
    public var tone: CoachTone = .direct

    public init(name: String, age: Int, sex: Sex, heightCm: Double, weightKg: Double,
                displayUnits: DisplayUnits, goal: Goal, targetWeightKg: Double, pacePctPerWeek: Double,
                activity: ActivityLevel, experience: Experience, trainingDays: Int, sessionMinutes: Int,
                environment: TrainingEnvironment, equipment: Set<Equipment>, limitations: Set<Limitation>) {
        self.name = name
        self.age = age
        self.sex = sex
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.displayUnits = displayUnits
        self.goal = goal
        self.targetWeightKg = targetWeightKg
        self.pacePctPerWeek = pacePctPerWeek
        self.activity = activity
        self.experience = experience
        self.trainingDays = trainingDays
        self.sessionMinutes = sessionMinutes
        self.environment = environment
        self.equipment = equipment
        self.limitations = limitations
    }
}

public enum Sex: String, Codable, Sendable, CaseIterable {
    case male, female, unspecified
}

public enum Goal: String, Codable, Sendable, CaseIterable {
    case lose, gain, maintain
}

/// Working-day activity. Multipliers include typical training volume.
public enum ActivityLevel: String, Codable, Sendable, CaseIterable {
    case seated, mixed, onFeet, physical

    public var multiplier: Double {
        switch self {
        case .seated: 1.42
        case .mixed: 1.5
        case .onFeet: 1.6
        case .physical: 1.75
        }
    }
}

public enum Experience: String, Codable, Sendable, CaseIterable {
    case beginner, intermediate, advanced
}

public enum TrainingEnvironment: String, Codable, Sendable, CaseIterable {
    case fullGym, homeGym, bodyweight

    /// The equipment checklist is pre-ticked from this; the user edits from there.
    public var presetEquipment: Set<Equipment> {
        switch self {
        case .fullGym:
            [.barbell, .squatRack, .dumbbells, .kettlebell, .cableMachine, .latPulldown, .legPress,
             .smithMachine, .benchFlat, .benchAdjustable, .pullUpBar, .rower, .treadmill, .bike, .mat]
        case .homeGym:
            [.adjustableDumbbells, .kettlebell, .benchFlat, .pullUpBar, .bands, .jumpRope, .mat]
        case .bodyweight:
            [.mat, .chair]
        }
    }
}

public enum Equipment: String, Codable, Sendable, CaseIterable {
    // Gym
    case barbell, squatRack, cableMachine, latPulldown, legPress, smithMachine, rower, treadmill, bike
    // Home
    case dumbbells, adjustableDumbbells, kettlebell, benchFlat, benchAdjustable, pullUpBar, bands, jumpRope
    // Anywhere
    case mat, chair

    public enum Group: String, CaseIterable, Sendable {
        case gym, home, anywhere
    }

    public var group: Group {
        switch self {
        case .barbell, .squatRack, .cableMachine, .latPulldown, .legPress, .smithMachine, .rower, .treadmill, .bike:
            .gym
        case .dumbbells, .adjustableDumbbells, .kettlebell, .benchFlat, .benchAdjustable, .pullUpBar, .bands, .jumpRope:
            .home
        case .mat, .chair:
            .anywhere
        }
    }
}

/// Fixed list, never free text (PRD F1). Flagged exercises are excluded, not modified.
public enum Limitation: String, Codable, Sendable, CaseIterable {
    case lowerBack, knees, shoulders, wrists, hips, neck
}

public enum DietStyle: String, Codable, Sendable, CaseIterable {
    case highProtein, balanced, vegetarian, vegan, pescatarian, keto, intermittentFasting
}

public enum Cuisine: String, Codable, Sendable, CaseIterable {
    case indian = "Indian", western = "Western", mediterranean = "Mediterranean", eastAsian = "East Asian"
    case mexican = "Mexican", middleEastern = "Middle Eastern", thai = "Thai"
    case chinese = "Chinese", japanese = "Japanese", korean = "Korean", italian = "Italian"
    case southIndian = "South Indian", caribbean = "Caribbean", african = "African"

    /// The recipe cuisines this choice serves: East Asian takes in Chinese, Japanese and Korean (and each of those
    /// the broader East Asian recipes); Indian and South Indian take in each other.
    public var served: Set<String> {
        switch self {
        case .eastAsian: [rawValue, Cuisine.chinese.rawValue, Cuisine.japanese.rawValue, Cuisine.korean.rawValue]
        case .chinese, .japanese, .korean: [rawValue, Cuisine.eastAsian.rawValue]
        case .indian: [rawValue, Cuisine.southIndian.rawValue]
        case .southIndian: [rawValue, Cuisine.indian.rawValue]
        default: [rawValue]
        }
    }
}

public enum Allergen: String, Codable, Sendable, CaseIterable {
    case peanuts, treeNuts, dairy, gluten, shellfish, fish, soy, eggs, sesame
}

/// Main meals a day.
public enum MealPattern: String, Codable, Sendable, CaseIterable {
    case two, three

    /// Reads a stored value, including the patterns from before snacks became their own setting.
    public init(stored: String) {
        self = stored == "two" ? .two : .three
    }

    /// Whether a pattern stored before snacks became their own setting included snacks (nil if it isn't one).
    public static func legacyHadSnacks(_ stored: String) -> Bool? {
        switch stored {
        case "threePlusSnack", "fourToFive": true
        case "two", "three": false
        default: nil
        }
    }
}

/// Planned cheat days: how often, on which weekdays, the whole day or one meal, and what pays for it.
public struct CheatDays: Codable, Sendable, Equatable {
    public var frequency: Frequency = .none
    /// Weekdays (0 = Monday) in order of preference; `frequency` says how many are used.
    public var weekdays: [Int] = [5, 2]
    public var style: Style = .day
    public var budget: Budget = .spread

    public enum Frequency: String, Codable, Sendable, CaseIterable {
        case none, once, twice
        public var count: Int {
            switch self {
            case .none: 0
            case .once: 1
            case .twice: 2
            }
        }
    }

    public enum Style: String, Codable, Sendable, CaseIterable {
        /// The whole day at about maintenance.
        case day
        /// One free meal in place of dinner.
        case meal
    }

    public enum Budget: String, Codable, Sendable, CaseIterable {
        /// A small cut on the other days pays for it, so the goal date holds.
        case spread
        /// Nothing else changes; the goal date moves out.
        case goalMoves
    }

    /// The cheat weekdays in use (0 = Monday), distinct.
    public var activeWeekdays: [Int] {
        var seen = Set<Int>()
        return Array(weekdays.filter { (0..<7).contains($0) && seen.insert($0).inserted }.prefix(frequency.count))
    }

    public init() {}
}

public enum TrainingHistory: String, Codable, Sendable, CaseIterable {
    case firstAttempt, restarting, plateaued, consistent
}

/// Honest daily steps; nudges the activity multiplier (steps outside training aren't in the job factor).
public enum DailySteps: String, Codable, Sendable, CaseIterable {
    case under4k, fourToEight, eightToTwelve, over12k

    public var multiplierAdjustment: Double {
        switch self {
        case .under4k: -0.05
        case .fourToEight: 0
        case .eightToTwelve: 0.05
        case .over12k: 0.1
        }
    }
}

public enum TrainingStyle: String, Codable, Sendable, CaseIterable {
    case heavyStrength, hypertrophy, hiit, circuits, running, cycling, mobility, sport
}

public enum SleepBand: String, Codable, Sendable, CaseIterable {
    case under5, fiveToSix, sixToSeven, sevenToEight, over8

    /// Short sleep makes a low-energy day likelier; the check-in says so.
    public var isShort: Bool { self == .under5 || self == .fiveToSix }
}

public enum GroceryBudget: String, Codable, Sendable, CaseIterable {
    case tight, moderate, comfortable
}

public enum ShopDay: String, Codable, Sendable, CaseIterable {
    case sunday, midweek, littleAndOften, delivery
}

public enum ReminderTime: String, Codable, Sendable, CaseIterable {
    case morning, midday, evening, none

    /// Hour of the daily check-in notification. Nil = no reminders.
    public var hour: Int? {
        switch self {
        case .morning: 7
        case .midday: 12
        case .evening: 19
        case .none: nil
        }
    }
}

public enum CoachTone: String, Codable, Sendable, CaseIterable {
    case direct, warm, hard
}
