import Foundation

public enum MovementPattern: String, Codable, Sendable, CaseIterable {
    case horizontalPush, verticalPush, horizontalPull, verticalPull, squat, hinge, lunge, carry, core
    case elbowFlexion, elbowExtension, shoulderRaise, calf, mobility, conditioning
}

public enum Muscle: String, Codable, Sendable, CaseIterable {
    case chest, frontDelts, sideDelts, rearDelts, lats, upperBack, traps, biceps, triceps, forearms
    case quads, glutes, hamstrings, adductors, calves, core, obliques, lowerBack, hipFlexors, hips, cardio
}

public enum Measure: String, Codable, Sendable {
    case reps, seconds
}

/// One library entry (PRD "Data schema" → exercise).
public struct Exercise: Codable, Sendable, Hashable, Identifiable {
    public struct Media: Codable, Sendable, Hashable {
        public var clip: String
        public var bundled: Bool
    }

    public var id: String
    public var name: String
    public var pattern: MovementPattern
    public var primaryMuscles: [Muscle]
    public var secondaryMuscles: [Muscle]
    /// Every group must be satisfied by at least one item in it.
    public var equipment: [[Equipment]]
    /// 1 easy … 3 hard.
    public var difficulty: Int
    public var contraindications: [Limitation]
    public var compound: Bool
    public var measure: Measure
    public var targetLow: Int
    public var targetHigh: Int
    /// Exercises in the same group can carry load over between them.
    public var loadGroup: String?
    /// Load relative to the group's base exercise (per hand for dumbbells).
    public var loadFactor: Double?
    public var media: Media

    public func isAvailable(with owned: Set<Equipment>) -> Bool {
        equipment.allSatisfy { group in group.contains { owned.contains($0) } }
    }

    public func isSafe(for limitations: Set<Limitation>) -> Bool {
        limitations.isDisjoint(with: contraindications)
    }

    public var isLoadable: Bool { loadFactor != nil }

    /// Smallest sensible load jump for this exercise's implement, in kg.
    public var loadIncrementKg: Double {
        let all = Set(equipment.flatMap { $0 })
        if all.contains(.kettlebell) { return 4 }
        if all.contains(.dumbbells) || all.contains(.adjustableDumbbells) { return 2 }
        return 2.5
    }
}

public struct ExerciseLibrary: Sendable {
    public struct Document: Codable, Sendable {
        public var version: Int
        public var reviewStatus: String
        public var exercises: [Exercise]
    }

    public let version: Int
    public let reviewStatus: String
    public let exercises: [Exercise]
    private let byID: [String: Exercise]

    public init(exercises: [Exercise], version: Int = 1, reviewStatus: String = "") {
        self.exercises = exercises
        self.version = version
        self.reviewStatus = reviewStatus
        self.byID = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
    }

    public subscript(id: String) -> Exercise? { byID[id] }

    public func candidates(pattern: MovementPattern, equipment: Set<Equipment>, limitations: Set<Limitation>) -> [Exercise] {
        exercises.filter { $0.pattern == pattern && $0.isAvailable(with: equipment) && $0.isSafe(for: limitations) }
    }

    /// The library that ships in the engine bundle.
    public static let bundled: ExerciseLibrary = {
        guard let url = Bundle.module.url(forResource: "exercises", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let doc = try? JSONDecoder().decode(Document.self, from: data)
        else { fatalError("exercises.json is missing or invalid") }
        return ExerciseLibrary(exercises: doc.exercises, version: doc.version, reviewStatus: doc.reviewStatus)
    }()
}
