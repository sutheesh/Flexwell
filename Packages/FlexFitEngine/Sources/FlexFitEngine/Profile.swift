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
    /// Nil = no limit.
    public var maxCookMinutes: Int?
    public var mealPattern: MealPattern = .threePlusSnack
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
    case highProtein, balanced, vegetarian, vegan, keto, intermittentFasting
}

public enum Cuisine: String, Codable, Sendable, CaseIterable {
    case indian = "Indian", western = "Western", mediterranean = "Mediterranean", eastAsian = "East Asian"
    case mexican = "Mexican", middleEastern = "Middle Eastern", thai = "Thai"
}

public enum Allergen: String, Codable, Sendable, CaseIterable {
    case peanuts, treeNuts, dairy, gluten, shellfish, fish, soy, eggs, sesame
}

public enum MealPattern: String, Codable, Sendable, CaseIterable {
    case two, three, threePlusSnack, fourToFive

    public var slots: [MealSlot] {
        switch self {
        case .two: [.lunch, .dinner]
        case .three: [.breakfast, .lunch, .dinner]
        case .threePlusSnack: [.breakfast, .lunch, .snack, .dinner]
        case .fourToFive: [.breakfast, .snack, .lunch, .snack, .dinner]
        }
    }
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
