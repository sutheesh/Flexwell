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
