import Testing
@testable import FlexFitEngine

let alex = UserProfile(
    name: "Alex", age: 29, sex: .male, heightCm: 178, weightKg: 82, displayUnits: .metric,
    goal: .lose, targetWeightKg: 75, pacePctPerWeek: 0.7, activity: .seated, experience: .intermediate,
    trainingDays: 4, sessionMinutes: 45, environment: .homeGym,
    equipment: TrainingEnvironment.homeGym.presetEquipment, limitations: [.lowerBack]
)

@Test func mifflinStJeorMale() {
    // 10×82 + 6.25×178 − 5×29 + 5 = 1792.5
    #expect(TargetCalculator.bmr(alex) == 1792.5)
}

@Test func lossTargetsSubtractPaceDeficit() {
    let t = TargetCalculator.initialTargets(for: alex)
    // TDEE 1792.5×1.42 = 2545.35; deficit 0.7%×82×7700/7 = 631.4 → 1913.95 → 1910
    #expect(t.calories == 1910)
    #expect(t.expenditure == 2550)
    #expect(t.proteinG == 150)          // 75 kg target × 2.0
    #expect(!t.floorApplied)
}

@Test func paceIsCappedAtOnePercent() {
    var p = alex
    p.pacePctPerWeek = 2.5
    var capped = alex
    capped.pacePctPerWeek = 1.0
    #expect(TargetCalculator.initialTargets(for: p) == TargetCalculator.initialTargets(for: capped))
}

@Test func calorieFloorHolds() {
    let small = UserProfile(
        name: "P", age: 60, sex: .female, heightCm: 150, weightKg: 50, displayUnits: .metric,
        goal: .lose, targetWeightKg: 45, pacePctPerWeek: 1.0, activity: .seated, experience: .beginner,
        trainingDays: 3, sessionMinutes: 30, environment: .bodyweight, equipment: [], limitations: []
    )
    let t = TargetCalculator.initialTargets(for: small)
    let bmr = TargetCalculator.bmr(small)
    #expect(Double(t.calories) >= max(1_200, bmr) - 5)
    #expect(t.floorApplied)
}

@Test func unspecifiedSexUsesHigherFloor() {
    #expect(Safety.calorieFloor(sex: .unspecified, bmr: 1_000) == 1_500)
}

@Test func minimumTargetWeightIsBMI18_5() {
    #expect(abs(Safety.minimumTargetWeightKg(heightCm: 178) - 58.6154) < 0.001)
}

@Test func weeksToGoal() {
    // 7 kg at 0.574 kg/wk = 12.2 → 13
    #expect(TargetCalculator.weeksToGoal(for: alex) == 13)
    var m = alex
    m.goal = .maintain
    #expect(TargetCalculator.weeksToGoal(for: m) == nil)
}

@Test(arguments: [(2, [SessionFocus.fullBodyA, .fullBodyB]),
                  (4, [.upper, .lower, .upper, .lower]),
                  (6, [.push, .pull, .legs, .push, .pull, .legs])])
func splitMatchesTrainingDays(days: Int, expected: [SessionFocus]) {
    #expect(WeekPlanner.split(forDays: days) == expected)
}

@Test func weekHasRequestedTrainingDays() {
    for days in 2...6 {
        var p = alex
        p.trainingDays = days
        let week = WeekPlanner.week(for: p)
        #expect(week.count == 7)
        #expect(week.filter { $0.kind == .training }.count == days)
        #expect(week[6].kind == .rest)
    }
}
