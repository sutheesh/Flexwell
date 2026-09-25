import Foundation

/// Daily calorie and macro targets.
public struct DailyTargets: Codable, Sendable, Equatable {
    public var calories: Int
    public var proteinG: Int
    public var carbsG: Int
    public var fatG: Int
    /// Estimated maintenance calories (the starting expenditure estimate).
    public var expenditure: Int
    /// True when the safety floor raised the target above the goal-derived number.
    public var floorApplied: Bool

    public init(calories: Int, proteinG: Int, carbsG: Int, fatG: Int, expenditure: Int, floorApplied: Bool) {
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.expenditure = expenditure
        self.floorApplied = floorApplied
    }
}

public enum TargetCalculator {
    static let kcalPerKg = 7_700.0

    /// Mifflin-St Jeor. Unspecified sex uses the midpoint of the two offsets.
    public static func bmr(_ p: UserProfile) -> Double {
        let offset: Double = switch p.sex {
        case .male: 5
        case .female: -161
        case .unspecified: -78
        }
        return 10 * p.weightKg + 6.25 * p.heightCm - 5 * Double(p.age) + offset
    }

    public static func expenditure(_ p: UserProfile) -> Double {
        bmr(p) * p.activity.multiplier
    }

    /// Initial targets (PRD F7). Weekly adaptation is layered on later.
    public static func initialTargets(for p: UserProfile) -> DailyTargets {
        let bmr = bmr(p)
        let tdee = bmr * p.activity.multiplier
        let pace = Safety.cappedPace(p.pacePctPerWeek, goal: p.goal)
        let dailyDelta = pace / 100 * p.weightKg * kcalPerKg / 7

        let goalCalories: Double = switch p.goal {
        case .lose: tdee - dailyDelta
        case .gain: tdee + dailyDelta
        case .maintain: tdee
        }
        let floor = Safety.calorieFloor(sex: p.sex, bmr: bmr)
        let calories = roundTo10(max(goalCalories, floor))

        // Protein per kg of *target* body weight, within PRD's 1.6–2.2 g/kg. Higher while cutting to hold muscle.
        let proteinPerKg = p.goal == .lose ? 2.0 : 1.8
        let protein = Int((p.targetWeightKg * proteinPerKg).rounded())
        let fat = Int((p.targetWeightKg * 0.8).rounded())
        let carbs = max(0, Int(((Double(calories) - Double(protein) * 4 - Double(fat) * 9) / 4).rounded()))

        return DailyTargets(
            calories: calories,
            proteinG: protein,
            carbsG: carbs,
            fatG: fat,
            expenditure: roundTo10(tdee),
            floorApplied: goalCalories < floor
        )
    }

    /// Whole weeks to reach the target at the chosen pace. Nil when maintaining.
    public static func weeksToGoal(for p: UserProfile) -> Int? {
        let pace = Safety.cappedPace(p.pacePctPerWeek, goal: p.goal)
        guard p.goal != .maintain, pace > 0 else { return nil }
        let perWeek = pace / 100 * p.weightKg
        let weeks = abs(p.weightKg - p.targetWeightKg) / perWeek
        return max(1, Int(weeks.rounded(.up)))
    }

    private static func roundTo10(_ v: Double) -> Int {
        Int((v / 10).rounded()) * 10
    }
}
