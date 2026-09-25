/// What the user has on the road (PRD F5).
public enum TravelKit: String, Codable, Sendable, CaseIterable {
    case none, bands, hotelDumbbells

    /// A chair is assumed everywhere; hotel rooms have one.
    public var equipment: Set<Equipment> {
        switch self {
        case .none: [.chair]
        case .bands: [.chair, .bands]
        case .hotelDumbbells: [.chair, .dumbbells]
        }
    }
}

public enum TravelConverter {
    /// Maps each exercise to its pattern's best option in the travel kit. Keeps the movement pattern;
    /// where load drops, adds a set or a 3-second lowering tempo to make up for it.
    public static func convert(_ plan: SessionPlan, kit: TravelKit, limitations: Set<Limitation>,
                               library: ExerciseLibrary = .bundled) -> SessionPlan {
        var result = plan
        var used = Set<String>()
        result.exercises = plan.exercises.compactMap { planned in
            guard let original = library[planned.exerciseID] else { return nil }
            if original.isAvailable(with: kit.equipment), original.isSafe(for: limitations), !used.contains(original.id) {
                used.insert(original.id)
                return planned
            }
            guard let best = SwapRanker.alternatives(for: original, equipment: kit.equipment, limitations: limitations,
                                                     library: library, excluding: used, limit: 1).first
            else { return nil }
            used.insert(best.exercise.id)
            var converted = planned
            converted.exerciseID = best.exercise.id
            converted.measure = best.exercise.measure
            converted.targetLow = best.exercise.targetLow
            converted.targetHigh = best.exercise.targetHigh
            if original.isLoadable && !best.exercise.isLoadable {
                if best.exercise.measure == .reps {
                    converted.tempoNote = "3 s down"
                } else {
                    converted.sets += 1
                }
            }
            return converted
        }
        return result
    }
}
