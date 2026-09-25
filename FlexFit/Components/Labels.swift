import Foundation
import FlexFitEngine

// User-facing names for engine values. The engine stays free of UI copy.

enum Formatters {
    static func mass(_ kg: Double, units: DisplayUnits) -> String {
        let value = Mass.display(kilograms: kg, in: units)
        switch units {
        case .metric:
            return value.formatted(.number.precision(.fractionLength(0...1))) + " kg"
        case .imperial:
            return value.formatted(.number.precision(.fractionLength(0))) + " lb"
        }
    }

    static func percent(_ pct: Double) -> String {
        (pct / 100).formatted(.percent.precision(.fractionLength(0...2)))
    }

    static func kcal(_ value: Int) -> String {
        value.formatted(.number)
    }
}

extension Sex {
    var title: String {
        switch self {
        case .male: "Male"
        case .female: "Female"
        case .unspecified: "Prefer not to say"
        }
    }
}

extension Goal {
    var title: String {
        switch self {
        case .lose: "Lose fat"
        case .gain: "Build muscle"
        case .maintain: "Maintain"
        }
    }

    var subtitle: String {
        switch self {
        case .lose: "Keep the muscle you have"
        case .gain: "Accept a little fat gain"
        case .maintain: "Hold the line, train for health"
        }
    }
}

extension ActivityLevel {
    var title: String {
        switch self {
        case .seated: "Desk, mostly seated"
        case .mixed: "Mixed, on and off my feet"
        case .onFeet: "On my feet all day"
        case .physical: "Physical labour"
        }
    }

    var subtitle: String {
        switch self {
        case .seated: "Sedentary"
        case .mixed: "Lightly active"
        case .onFeet: "Active"
        case .physical: "Very active"
        }
    }
}

extension TrainingEnvironment {
    var title: String {
        switch self {
        case .fullGym: "Full gym access"
        case .homeGym: "Basic home gym"
        case .bodyweight: "Bodyweight only"
        }
    }

    var subtitle: String {
        switch self {
        case .fullGym: "Barbells, machines, cables"
        case .homeGym: "Dumbbells, bands, a bar"
        case .bodyweight: "No equipment at all"
        }
    }
}

extension Equipment {
    var title: String {
        switch self {
        case .barbell: "Barbell"
        case .squatRack: "Squat rack"
        case .cableMachine: "Cable machine"
        case .latPulldown: "Lat pulldown"
        case .legPress: "Leg press"
        case .smithMachine: "Smith machine"
        case .rower: "Rower"
        case .treadmill: "Treadmill"
        case .bike: "Exercise bike"
        case .dumbbells: "Dumbbells"
        case .adjustableDumbbells: "Adjustable dumbbells"
        case .kettlebell: "Kettlebell"
        case .benchFlat: "Flat bench"
        case .benchAdjustable: "Adjustable bench"
        case .pullUpBar: "Pull-up bar"
        case .bands: "Resistance bands"
        case .jumpRope: "Jump rope"
        case .mat: "Mat"
        case .chair: "Sturdy chair"
        }
    }
}

extension Equipment.Group {
    var title: String {
        switch self {
        case .gym: "Gym"
        case .home: "Home kit"
        case .anywhere: "Anywhere"
        }
    }
}

extension Experience {
    var title: String {
        switch self {
        case .beginner: "Beginner"
        case .intermediate: "Intermediate"
        case .advanced: "Advanced"
        }
    }

    var subtitle: String {
        switch self {
        case .beginner: "Under 6 months"
        case .intermediate: "6 months – 3 years"
        case .advanced: "3 years +"
        }
    }
}

extension Limitation {
    var title: String {
        switch self {
        case .lowerBack: "Lower back"
        case .knees: "Knees"
        case .shoulders: "Shoulders"
        case .wrists: "Wrists"
        case .hips: "Hips"
        case .neck: "Neck"
        }
    }
}

extension SessionFocus {
    var title: String {
        switch self {
        case .fullBodyA: "Full body A"
        case .fullBodyB: "Full body B"
        case .fullBodyC: "Full body C"
        case .upper: "Upper body"
        case .lower: "Lower body"
        case .push: "Push"
        case .pull: "Pull"
        case .legs: "Legs"
        }
    }
}

enum Weekday {
    /// 0 = Monday.
    static func shortName(_ index: Int) -> String {
        ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][index]
    }
}

extension TrainingHistory {
    var title: String {
        switch self {
        case .firstAttempt: "First serious attempt"
        case .restarting: "Restarting after a break"
        case .plateaued: "Plateaued for months"
        case .consistent: "Consistent, want better programming"
        }
    }
}

extension DailySteps {
    var title: String {
        switch self {
        case .under4k: "Under 4,000"
        case .fourToEight: "4,000 – 8,000"
        case .eightToTwelve: "8,000 – 12,000"
        case .over12k: "Over 12,000"
        }
    }
}

extension TrainingStyle {
    var title: String {
        switch self {
        case .heavyStrength: "Heavy strength"
        case .hypertrophy: "Hypertrophy"
        case .hiit: "HIIT"
        case .circuits: "Circuits"
        case .running: "Running"
        case .cycling: "Cycling"
        case .mobility: "Mobility"
        case .sport: "Sport"
        }
    }
}

extension SleepBand {
    var title: String {
        switch self {
        case .under5: "Under 5 hrs"
        case .fiveToSix: "5 – 6 hrs"
        case .sixToSeven: "6 – 7 hrs"
        case .sevenToEight: "7 – 8 hrs"
        case .over8: "8 hrs +"
        }
    }
}

extension DietStyle {
    var title: String {
        switch self {
        case .highProtein: "High protein"
        case .balanced: "Balanced / flexible"
        case .vegetarian: "Vegetarian"
        case .vegan: "Vegan"
        case .keto: "Keto"
        case .intermittentFasting: "Intermittent fasting"
        }
    }

    var subtitle: String {
        switch self {
        case .highProtein: "Flexible, protein-led"
        case .balanced: "No rules beyond calories"
        case .vegetarian: "No meat or fish"
        case .vegan: "No animal products"
        case .keto: "Very low carb"
        case .intermittentFasting: "8-hour eating window"
        }
    }
}

extension Allergen {
    var title: String {
        switch self {
        case .peanuts: "Peanuts"
        case .treeNuts: "Tree nuts"
        case .dairy: "Dairy"
        case .gluten: "Gluten"
        case .shellfish: "Shellfish"
        case .fish: "Fish"
        case .soy: "Soy"
        case .eggs: "Eggs"
        case .sesame: "Sesame"
        }
    }
}

enum FoodDislikes {
    /// The mock's "Foods you will not eat" list.
    static let options = ["Tofu", "Salmon", "Paneer", "Coriander", "Avocado", "Chickpeas", "Mushrooms"]
}

extension MealPattern {
    var title: String {
        switch self {
        case .two: "2 meals"
        case .three: "3 meals"
        case .threePlusSnack: "3 meals + snack"
        case .fourToFive: "4 – 5 small meals"
        }
    }
}

extension MealSlot {
    var title: String {
        switch self {
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        case .snack: "Snack"
        case .dinner: "Dinner"
        }
    }

    /// Suggested time of day, from the mock.
    var clock: String {
        switch self {
        case .breakfast: "8:00 am"
        case .lunch: "1:00 pm"
        case .snack: "4:30 pm"
        case .dinner: "8:00 pm"
        }
    }

    var hour: Double {
        switch self {
        case .breakfast: 8
        case .lunch: 13
        case .snack: 16.5
        case .dinner: 20
        }
    }

    var illustration: String { "Illustration-\(rawValue)" }
}

extension Meal.Tag {
    var title: String {
        switch self {
        case .highProtein: "High protein"
        case .lowCarb: "Low carb"
        case .vegan: "Vegan"
        case .vegetarian: "Vegetarian"
        case .balanced: "Balanced"
        }
    }
}

extension GroceryBudget {
    var title: String {
        switch self {
        case .tight: "Tight"
        case .moderate: "Moderate"
        case .comfortable: "Comfortable"
        }
    }

    var subtitle: String {
        switch self {
        case .tight: "Staples, batch cooking"
        case .moderate: "Some convenience items"
        case .comfortable: "Whatever hits the macros"
        }
    }
}

extension ShopDay {
    var title: String {
        switch self {
        case .sunday: "Sunday"
        case .midweek: "Midweek"
        case .littleAndOften: "Little and often"
        case .delivery: "Delivery, whenever"
        }
    }
}

extension ReminderTime {
    var title: String {
        switch self {
        case .morning: "Morning, before work"
        case .midday: "Midday"
        case .evening: "Evening"
        case .none: "Do not remind me"
        }
    }
}

extension CoachTone {
    var title: String {
        switch self {
        case .direct: "Direct"
        case .warm: "Warm"
        case .hard: "Hard"
        }
    }

    var subtitle: String {
        switch self {
        case .direct: "Short, factual, no fluff"
        case .warm: "Encouraging but honest"
        case .hard: "Tell me when I am slipping"
        }
    }
}
