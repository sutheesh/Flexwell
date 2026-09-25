import Foundation

/// Body areas for the optional soreness question (PRD F4).
public enum SoreArea: String, Codable, Sendable, CaseIterable {
    case chest, shoulders, back, arms, legs, core

    public var muscles: Set<Muscle> {
        switch self {
        case .chest: [.chest]
        case .shoulders: [.frontDelts, .sideDelts, .rearDelts]
        case .back: [.lats, .upperBack, .lowerBack, .traps]
        case .arms: [.biceps, .triceps, .forearms]
        case .legs: [.quads, .hamstrings, .glutes, .calves, .adductors]
        case .core: [.core, .obliques]
        }
    }
}

public enum SessionAdjuster {
    /// Sore area flagged: swap exercises that hit it as a primary muscle (PRD energy pivot rules).
    /// Exercises with no safe alternative are dropped rather than trained sore.
    public static func avoid(_ areas: Set<SoreArea>, in plan: SessionPlan, profile: UserProfile,
                             equipment: Set<Equipment>? = nil, library: ExerciseLibrary = .bundled) -> SessionPlan {
        let sore = areas.reduce(into: Set<Muscle>()) { $0.formUnion($1.muscles) }
        guard !sore.isEmpty else { return plan }
        return replace(in: plan, profile: profile, equipment: equipment, library: library) { ex in
            !sore.isDisjoint(with: ex.primaryMuscles)
        }
    }

    /// Removes excluded exercises (e.g. "This hurts" for 7 days), swapping in the best alternative.
    public static func exclude(_ ids: Set<String>, in plan: SessionPlan, profile: UserProfile,
                               equipment: Set<Equipment>? = nil, library: ExerciseLibrary = .bundled) -> SessionPlan {
        guard !ids.isEmpty else { return plan }
        return replace(in: plan, profile: profile, equipment: equipment, library: library, excluded: ids) { ids.contains($0.id) }
    }

    static func replace(in plan: SessionPlan, profile: UserProfile, equipment: Set<Equipment>?,
                        library: ExerciseLibrary, excluded: Set<String> = [],
                        where shouldReplace: (Exercise) -> Bool) -> SessionPlan {
        let owned = equipment ?? profile.equipment
        var used = Set(plan.exercises.map(\.exerciseID)).union(excluded)
        var result = plan
        result.exercises = plan.exercises.compactMap { planned in
            guard let ex = library[planned.exerciseID], shouldReplace(ex) else { return planned }
            let pick = SwapRanker.alternatives(for: ex, equipment: owned, limitations: profile.limitations,
                                               library: library, excluding: used, limit: 20)
                .first { !shouldReplace($0.exercise) }
            guard let pick else { return nil }
            used.insert(pick.exercise.id)
            var swapped = planned
            swapped.exerciseID = pick.exercise.id
            swapped.measure = pick.exercise.measure
            swapped.targetLow = pick.exercise.targetLow
            swapped.targetHigh = pick.exercise.targetHigh
            return swapped
        }
        return result
    }
}
