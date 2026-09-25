/// Hard limits enforced by the engine, never by the UI or the AI (PRD "Safety and guardrails").
public enum Safety {
    public static let minimumAge = 18
    public static let maximumAge = 100
    /// Weight-loss pace cap: 1% of body weight per week.
    public static let maxLossPacePct = 1.0
    public static let maxGainPacePct = 0.5
    public static let minimumTargetBMI = 18.5

    public static func calorieFloor(sex: Sex, bmr: Double) -> Double {
        let bySex: Double = switch sex {
        case .female: 1_200
        // Unspecified takes the higher floor: under-eating is the risk the floor exists to stop.
        case .male, .unspecified: 1_500
        }
        return max(bySex, bmr)
    }

    public static func bmi(weightKg: Double, heightCm: Double) -> Double {
        let m = heightCm / 100
        return weightKg / (m * m)
    }

    /// The lowest target weight the app will accept for this height.
    public static func minimumTargetWeightKg(heightCm: Double) -> Double {
        let m = heightCm / 100
        return minimumTargetBMI * m * m
    }

    public static func paceOptions(for goal: Goal) -> [Double] {
        switch goal {
        case .lose: [0.25, 0.5, 0.75, 1.0]
        case .gain: [0.25, 0.5]
        case .maintain: []
        }
    }

    public static func cappedPace(_ pct: Double, goal: Goal) -> Double {
        switch goal {
        case .lose: min(max(pct, 0), maxLossPacePct)
        case .gain: min(max(pct, 0), maxGainPacePct)
        case .maintain: 0
        }
    }
}
