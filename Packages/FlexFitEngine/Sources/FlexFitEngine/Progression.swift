/// One performed set.
public struct SetResult: Codable, Sendable, Hashable {
    /// Reps, or seconds for timed exercises.
    public var value: Int
    /// Nil for bodyweight.
    public var loadKg: Double?

    public init(value: Int, loadKg: Double?) {
        self.value = value
        self.loadKg = loadKg
    }
}

/// Pre-fills the next session's sets (PRD F2 progression + F6 pre-filled logging):
/// add reps within the range; once every set hits the top of the range, add load and drop to the bottom.
public enum Progression {
    public static func prefill(_ planned: PlannedExercise, exercise: Exercise, last: [SetResult]?) -> [SetResult] {
        guard let last, !last.isEmpty else {
            return Array(repeating: SetResult(value: planned.targetLow, loadKg: nil), count: planned.sets)
        }
        let topHit = last.allSatisfy { $0.value >= planned.targetHigh }
        let lastLoad = last.compactMap(\.loadKg).max()
        let lastValue = last.map(\.value).min() ?? planned.targetLow

        let next: SetResult
        if topHit, let load = lastLoad, exercise.isLoadable {
            next = SetResult(value: planned.targetLow, loadKg: load + exercise.loadIncrementKg)
        } else if topHit {
            // Bodyweight / timed at the top of the range: nudge the target past it.
            let step = planned.measure == .seconds ? 5 : 1
            next = SetResult(value: lastValue + step, loadKg: lastLoad)
        } else {
            let step = planned.measure == .seconds ? 5 : 1
            next = SetResult(value: min(planned.targetHigh, max(planned.targetLow, lastValue + step)), loadKg: lastLoad)
        }
        return Array(repeating: next, count: planned.sets)
    }

    /// Epley estimated one-rep max, for personal records.
    public static func estimatedOneRepMax(loadKg: Double, reps: Int) -> Double {
        reps <= 1 ? loadKg : loadKg * (1 + Double(reps) / 30)
    }
}
