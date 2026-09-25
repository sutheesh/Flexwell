import Foundation
import FlexFitEngine

/// Resolves what the user should actually do on a given day: the built session,
/// then saved swaps, then today's energy pivot.
struct PlanResolver {
    let profile: UserProfile
    let swaps: [ExerciseSwap]
    let logs: [DailyLog]
    var library: ExerciseLibrary = .bundled

    var week: [PlannedDay] { WeekPlanner.week(for: profile) }

    func session(forWeekday weekday: Int, on date: Date, applyPivot: Bool) -> SessionPlan? {
        let day = week[weekday]
        guard day.kind == .training, let focus = day.focus else { return nil }
        var plan = SessionBuilder.build(focus: focus, profile: profile, library: library,
                                        variation: WeekPlanner.variation(forWeekday: weekday, in: week))
        plan.exercises = plan.exercises.map { applySwaps(to: $0, on: date) }

        if applyPivot, let energy = log(for: date)?.energyValue {
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
            let pivot = EnergyPivot.pivot(energy: energy, lowYesterday: log(for: yesterday)?.energyValue == .low,
                                          plannedMinutes: plan.minutes)
            plan = SessionBuilder.apply(pivot, to: plan, profile: profile, library: library)
        }
        return plan
    }

    private func applySwaps(to planned: PlannedExercise, on date: Date) -> PlannedExercise {
        let start = Calendar.current.startOfDay(for: date)
        // A today-only swap wins over a standing one; the newest of each kind wins.
        let relevant = swaps
            .filter { $0.originalID == planned.exerciseID && ($0.day == nil || $0.day == start) }
            .sorted { ($0.day != nil ? 1 : 0, $0.createdAt) > ($1.day != nil ? 1 : 0, $1.createdAt) }
        guard let swap = relevant.first, let replacement = library[swap.replacementID] else { return planned }
        var result = planned
        result.exerciseID = replacement.id
        result.measure = replacement.measure
        result.targetLow = replacement.targetLow
        result.targetHigh = replacement.targetHigh
        return result
    }

    func log(for date: Date) -> DailyLog? {
        let start = Calendar.current.startOfDay(for: date)
        return logs.first { $0.day == start }
    }

    /// Exercises done on any logged day, for the swap ranker's "done it before" signal.
    var history: Set<String> { Set(logs.flatMap(\.completedExercises)) }

    /// Every exercise planned this week, for the "not used this week" signal.
    func usedThisWeek(on date: Date) -> Set<String> {
        Set((0..<7).compactMap { session(forWeekday: $0, on: date, applyPivot: false) }.flatMap { $0.exercises.map(\.exerciseID) })
    }
}
