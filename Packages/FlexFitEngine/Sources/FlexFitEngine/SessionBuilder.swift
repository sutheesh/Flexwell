/// One exercise as prescribed in a session.
public struct PlannedExercise: Codable, Sendable, Hashable {
    public var exerciseID: String
    public var sets: Int
    public var targetLow: Int
    public var targetHigh: Int
    public var measure: Measure
    public var rpeCap: Int
    /// e.g. "3 s down" when Travel Mode makes up for lighter load with tempo.
    public var tempoNote: String?
}

public struct SessionPlan: Codable, Sendable, Hashable {
    public var focus: SessionFocus
    public var minutes: Int
    public var variant: SessionVariant
    public var exercises: [PlannedExercise]
}

/// Builds a session from the library: filter by pattern, equipment and limitations, then rank (PRD F2).
public enum SessionBuilder {
    /// Slot patterns per focus, in the order they're trained. Session length takes a prefix.
    public static func template(for focus: SessionFocus) -> [MovementPattern] {
        switch focus {
        case .fullBodyA: [.squat, .horizontalPush, .horizontalPull, .hinge, .core, .shoulderRaise]
        case .fullBodyB: [.hinge, .verticalPush, .verticalPull, .lunge, .carry, .elbowFlexion]
        case .fullBodyC: [.lunge, .horizontalPush, .verticalPull, .squat, .core, .elbowExtension]
        case .upper: [.horizontalPush, .horizontalPull, .verticalPush, .verticalPull, .elbowFlexion, .elbowExtension]
        case .lower, .legs: [.squat, .hinge, .lunge, .calf, .core, .carry]
        case .push: [.horizontalPush, .verticalPush, .horizontalPush, .shoulderRaise, .elbowExtension, .core]
        case .pull: [.verticalPull, .horizontalPull, .horizontalPull, .elbowFlexion, .core, .carry]
        }
    }

    /// When nothing in a pattern is available, the closest pattern that trains similar muscles.
    static let fallback: [MovementPattern: MovementPattern] = [
        .verticalPull: .horizontalPull, .carry: .core, .shoulderRaise: .verticalPush,
        .elbowFlexion: .horizontalPull, .elbowExtension: .horizontalPush, .calf: .lunge,
    ]

    public static func slotCount(forMinutes minutes: Int) -> Int {
        switch minutes {
        case ..<25: 3
        case ..<40: 4
        case ..<55: 5
        default: 6
        }
    }

    /// - Parameter variation: which occurrence of this focus in the week (0, 1…), so repeats aren't identical.
    public static func build(focus: SessionFocus, profile: UserProfile, library: ExerciseLibrary = .bundled,
                             variation: Int = 0, equipment: Set<Equipment>? = nil) -> SessionPlan {
        let owned = equipment ?? profile.equipment
        let slots = template(for: focus).prefix(slotCount(forMinutes: profile.sessionMinutes))
        var used = Set<String>()
        var planned: [PlannedExercise] = []

        for (index, pattern) in slots.enumerated() {
            var options = ranked(pattern: pattern, slot: index, profile: profile, owned: owned, used: used, library: library)
            if options.isEmpty, let alternate = fallback[pattern] {
                options = ranked(pattern: alternate, slot: index, profile: profile, owned: owned, used: used, library: library)
            }
            // Last resort, so a narrow kit plus limitations never yields an empty session.
            if options.isEmpty {
                options = ranked(pattern: .core, slot: index, profile: profile, owned: owned, used: used, library: library)
            }
            guard !options.isEmpty else { continue }
            let pick = options[variation % min(2, options.count)]
            used.insert(pick.id)
            planned.append(prescribe(pick, experience: profile.experience))
        }
        return SessionPlan(focus: focus, minutes: profile.sessionMinutes, variant: .full, exercises: planned)
    }

    static func ranked(pattern: MovementPattern, slot: Int, profile: UserProfile, owned: Set<Equipment>,
                       used: Set<String>, library: ExerciseLibrary) -> [Exercise] {
        let maxDifficulty = profile.experience == .beginner ? 2 : 3
        let target: Double = switch profile.experience {
        case .beginner: 1
        case .intermediate: 2
        case .advanced: 2.5
        }
        return library.candidates(pattern: pattern, equipment: owned, limitations: profile.limitations)
            .filter { !used.contains($0.id) && $0.difficulty <= maxDifficulty }
            .map { ex -> (Exercise, Double) in
                var score = 1 - abs(Double(ex.difficulty) - target) / 2
                if slot < 3 && ex.compound { score += 1 }
                if ex.isLoadable { score += 0.3 }
                return (ex, score)
            }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.id < $1.0.id }
            .map(\.0)
    }

    static func prescribe(_ ex: Exercise, experience: Experience, rpeCap: Int = 8) -> PlannedExercise {
        let sets = ex.compound && experience == .advanced ? 4 : 3
        return PlannedExercise(exerciseID: ex.id, sets: sets, targetLow: ex.targetLow, targetHigh: ex.targetHigh,
                               measure: ex.measure, rpeCap: rpeCap, tempoNote: nil)
    }

    /// Shapes a full session to the energy pivot (PRD "Energy pivot rules").
    public static func apply(_ pivot: PivotResult, to plan: SessionPlan, profile: UserProfile,
                             library: ExerciseLibrary = .bundled, equipment: Set<Equipment>? = nil) -> SessionPlan {
        var result = plan
        result.variant = pivot.variant
        result.minutes = pivot.minutes
        switch pivot.variant {
        case .full:
            result.exercises = plan.exercises.map { var e = $0; e.rpeCap = pivot.rpeCap; return e }
        case .trimmed:
            // Top 3 compound lifts, 2 sets each.
            let compounds = plan.exercises.filter { library[$0.exerciseID]?.compound == true }
            result.exercises = (compounds.isEmpty ? plan.exercises : compounds).prefix(3).map {
                var e = $0; e.sets = 2; e.rpeCap = pivot.rpeCap; return e
            }
        case .minimum:
            // Mobility plus one easy compound.
            let owned = equipment ?? profile.equipment
            let mobility = library.candidates(pattern: .mobility, equipment: owned, limitations: profile.limitations)
                .sorted { $0.id < $1.id }
                .prefix(2)
                .map { prescribe($0, experience: .beginner, rpeCap: pivot.rpeCap) }
            let easiest = plan.exercises
                .compactMap { planned in library[planned.exerciseID].map { (planned, $0) } }
                .filter { $0.1.compound }
                .min { $0.1.difficulty != $1.1.difficulty ? $0.1.difficulty < $1.1.difficulty : $0.1.id < $1.1.id }
            var compound = easiest?.0
            compound?.sets = 2
            compound?.rpeCap = pivot.rpeCap
            result.exercises = mobility.map { var e = $0; e.sets = 1; return e } + (compound.map { [$0] } ?? [])
        }
        return result
    }
}
