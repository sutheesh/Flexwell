import Foundation

/// How to do an exercise: numbered steps and the cues that matter most.
/// Draft copy — `ExerciseGuides.reviewStatus` says so until a qualified coach or physio signs it off.
public struct ExerciseGuide: Codable, Sendable, Hashable {
    public var steps: [String]
    public var cues: [String]
}

public enum ExerciseGuides {
    private struct Document: Decodable {
        let version: Int
        let reviewStatus: String
        let guides: [String: ExerciseGuide]
    }

    private static let document: Document = {
        guard let url = Bundle.module.url(forResource: "exercise_guides", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let doc = try? JSONDecoder().decode(Document.self, from: data)
        else { fatalError("exercise_guides.json is missing or invalid") }
        return doc
    }()

    public static var bundled: [String: ExerciseGuide] { document.guides }
    public static var reviewStatus: String { document.reviewStatus }
}

/// The body map's groups: what a person taps ("Shoulders", "Back"), each covering one or more muscles.
public enum MuscleGroup: String, CaseIterable, Codable, Sendable {
    case shoulders, chest, biceps, triceps, forearms, abs, obliques, traps, back, lowerBack
    case glutes, hamstrings, quads, adductors, calves, hips, cardio

    public var muscles: Set<Muscle> {
        switch self {
        case .shoulders: [.frontDelts, .sideDelts, .rearDelts]
        case .chest: [.chest]
        case .biceps: [.biceps]
        case .triceps: [.triceps]
        case .forearms: [.forearms]
        case .abs: [.core]
        case .obliques: [.obliques]
        case .traps: [.traps]
        case .back: [.lats, .upperBack]
        case .lowerBack: [.lowerBack]
        case .glutes: [.glutes]
        case .hamstrings: [.hamstrings]
        case .quads: [.quads]
        case .adductors: [.adductors]
        case .calves: [.calves]
        case .hips: [.hips, .hipFlexors]
        case .cardio: [.cardio]
        }
    }

    public static func group(of muscle: Muscle) -> MuscleGroup {
        allCases.first { $0.muscles.contains(muscle) } ?? .abs
    }

    /// Exercises for this group: those that train it as a primary muscle first, then as a secondary one.
    public func exercises(in library: ExerciseLibrary = .bundled) -> [Exercise] {
        let all = library.exercises.sorted { $0.name < $1.name }
        let primary = all.filter { !$0.primaryMuscles.filter(muscles.contains).isEmpty }
        let secondary = all.filter { ex in !primary.contains { $0.id == ex.id } && !ex.secondaryMuscles.filter(muscles.contains).isEmpty }
        return primary + secondary
    }
}

extension ProgressStats {
    /// Every logged session of one exercise, newest first.
    public static func history(of exerciseID: String, in logs: [LoggedExercise]) -> [LoggedExercise] {
        logs.filter { $0.exerciseID == exerciseID && !$0.sets.isEmpty }.sorted { $0.date > $1.date }
    }

    /// The session's best estimated one-rep max (loaded sets only).
    public static func bestEstimatedMax(_ log: LoggedExercise) -> Double? {
        log.sets.compactMap { s in s.loadKg.map { Progression.estimatedOneRepMax(loadKg: $0, reps: s.value) } }.max()
    }
}
