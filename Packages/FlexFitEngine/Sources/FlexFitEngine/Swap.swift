/// A ranked alternative for the 1-tap swap (PRD F3).
public struct SwapOption: Sendable, Hashable {
    public var exercise: Exercise
    public var score: Double
    /// True when it trains the same primary muscles as the original.
    public var sameMuscles: Bool
    /// True when the original was flagged for a joint this one isn't.
    public var easierOnJoints: Bool
    /// Load carried over from the original, rounded to the implement's increments. Nil when not comparable.
    public var carriedLoadKg: Double?
}

public enum SwapScope: String, Codable, Sendable {
    /// "Machine taken": today only.
    case today
    /// "I don't like this": future weeks too.
    case always
}

public enum SwapRanker {
    /// Hard filters, then 0.4 primary + 0.2 secondary + 0.2 difficulty + 0.1 history + 0.1 freshness. Top 3.
    public static func alternatives(
        for original: Exercise,
        equipment: Set<Equipment>,
        limitations: Set<Limitation>,
        library: ExerciseLibrary = .bundled,
        history: Set<String> = [],
        usedThisWeek: Set<String> = [],
        excluding: Set<String> = [],
        currentLoadKg: Double? = nil,
        limit: Int = 3
    ) -> [SwapOption] {
        let primary = Set(original.primaryMuscles)
        let secondary = Set(original.secondaryMuscles)
        return library.candidates(pattern: original.pattern, equipment: equipment, limitations: limitations)
            .filter { $0.id != original.id && !excluding.contains($0.id) }
            .map { ex -> SwapOption in
                let p = primary.isEmpty ? 0 : Double(primary.intersection(ex.primaryMuscles).count) / Double(primary.count)
                let s = secondary.isEmpty ? 1 : Double(secondary.intersection(ex.secondaryMuscles).count) / Double(secondary.count)
                let d = 1 - Double(abs(ex.difficulty - original.difficulty)) / 2
                let h: Double = history.contains(ex.id) ? 1 : 0
                let f: Double = usedThisWeek.contains(ex.id) ? 0 : 1
                let score = 0.4 * p + 0.2 * s + 0.2 * d + 0.1 * h + 0.1 * f
                return SwapOption(
                    exercise: ex,
                    score: score,
                    sameMuscles: p >= 1,
                    easierOnJoints: !Set(original.contraindications).subtracting(ex.contraindications).isEmpty,
                    carriedLoadKg: currentLoadKg.flatMap { LoadConverter.convert($0, from: original, to: ex) }
                )
            }
            .sorted { $0.score != $1.score ? $0.score > $1.score : $0.exercise.id < $1.exercise.id }
            .prefix(limit)
            .map { $0 }
    }
}

public enum LoadConverter {
    /// Converts a working load between exercises in the same load group, rounded to the target's increments.
    public static func convert(_ loadKg: Double, from: Exercise, to: Exercise) -> Double? {
        guard let group = from.loadGroup, group == to.loadGroup,
              let fromFactor = from.loadFactor, let toFactor = to.loadFactor, fromFactor > 0
        else { return nil }
        let raw = loadKg * toFactor / fromFactor
        let step = to.loadIncrementKg
        return max(step, (raw / step).rounded() * step)
    }
}
