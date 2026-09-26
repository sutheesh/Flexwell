import Testing
import Foundation
@testable import FlexFitEngine

let day: TimeInterval = 86_400

@Test func progressionAddsRepsThenLoad() {
    let ex = library["db_flat_press"]!
    let planned = PlannedExercise(exerciseID: ex.id, sets: 3, targetLow: 8, targetHigh: 12, measure: .reps, rpeCap: 8)
    #expect(Progression.prefill(planned, exercise: ex, last: nil) == Array(repeating: SetResult(value: 8, loadKg: nil), count: 3))
    let mid = Progression.prefill(planned, exercise: ex, last: [SetResult(value: 10, loadKg: 20), SetResult(value: 9, loadKg: 20)])
    #expect(mid.first == SetResult(value: 10, loadKg: 20))
    let top = Progression.prefill(planned, exercise: ex, last: Array(repeating: SetResult(value: 12, loadKg: 20), count: 3))
    #expect(top.first == SetResult(value: 8, loadKg: 22))
}

@Test func trendSmoothsWithAlphaPointOne() {
    let start = Date(timeIntervalSince1970: 0)
    let s = WeightTrend.series([WeightEntry(date: start, kg: 80), WeightEntry(date: start + day, kg: 90)])
    #expect(s.last!.kg == 81)
}

@Test func adaptiveTargetsMoveAtMost150AndRespectFloor() {
    let initial = TargetCalculator.initialTargets(for: alex)
    // Losing nothing at all: expenditure is lower than thought → target drops, but by ≤ 150.
    let flat = AdaptiveTargets.weeklyUpdate(profile: alex, previous: initial, trendChangeKg: 0,
                                            trendWeightKg: 82, fastLossWeeks: 0)
    #expect(initial.calories - flat.targets.calories <= 150)
    #expect(flat.targets.calories < initial.calories)
    #expect(Double(flat.targets.calories) >= TargetCalculator.bmr(alex))
}

@Test func twoFastLossWeeksRaiseTargetsAndWarn() {
    let initial = TargetCalculator.initialTargets(for: alex)
    #expect(AdaptiveTargets.isFastLoss(trendChangeKg: -1.5, trendWeightKg: 82))
    let u = AdaptiveTargets.weeklyUpdate(profile: alex, previous: initial, trendChangeKg: -1.5,
                                         trendWeightKg: 82, fastLossWeeks: 2)
    #expect(u.rapidLossWarning && u.targets.calories == initial.calories + 150)
}

@Test func streakCountsWeeksAndToleratesCurrentWeek() {
    #expect(Streak.weeks(sessionsPerWeek: [1, 4, 4, 2, 4], planned: 4) == 2)
    #expect(Streak.weeks(sessionsPerWeek: [4, 4], planned: 4) == 2)
    #expect(Streak.weeks(sessionsPerWeek: [0, 3], planned: 4) == 0)
}

@Test func soreChestSwapsOutChestPrimaries() {
    var p = alex
    p.limitations = []
    let plan = SessionBuilder.build(focus: .push, profile: p)
    let adjusted = SessionAdjuster.avoid([.chest], in: plan, profile: p)
    for e in adjusted.exercises { #expect(!library[e.exerciseID]!.primaryMuscles.contains(.chest)) }
}

@Test func recordsUseEstimatedOneRepMax() {
    let now = Date()
    let r = ProgressStats.records([LoggedExercise(exerciseID: "bb_bench_press", date: now,
                                                  sets: [SetResult(value: 5, loadKg: 100), SetResult(value: 1, loadKg: 110)])])
    #expect(abs(r.first!.value - 116.667) < 0.01)
    let v = ProgressStats.volume([LoggedExercise(exerciseID: "bb_bench_press", date: now, sets: [SetResult(value: 5, loadKg: 100)])])
    #expect(v[.chest] == 1)
}
