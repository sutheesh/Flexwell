import Foundation
import SwiftData
import FlexFitEngine

// Persisted data is what's on users' phones. Once shipped, changing this without a
// new VersionedSchema + migration stage loses their data.
//
// Every property has a default and nothing is unique, so the store can be mirrored
// to the CloudKit private database later (PRD backup) without a migration.

enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [ProfileRecord.self] }

    @Model
    final class ProfileRecord {
        var createdAt: Date = Date.now
        var name: String = ""
        /// Stored as birth year (PRD schema), so age stays right over time.
        var birthYear: Int = 0
        var sex: String = Sex.unspecified.rawValue
        var heightCm: Double = 0
        var weightKg: Double = 0
        var displayUnits: String = DisplayUnits.metric.rawValue
        var goal: String = Goal.maintain.rawValue
        var targetWeightKg: Double = 0
        var pacePctPerWeek: Double = 0
        var activity: String = ActivityLevel.seated.rawValue
        var experience: String = Experience.beginner.rawValue
        var trainingDays: Int = 3
        var sessionMinutes: Int = 45
        var environment: String = TrainingEnvironment.homeGym.rawValue
        var equipment: [String] = []
        var limitations: [String] = []
        /// When the user acknowledged the health disclaimer in onboarding.
        var healthNoticeAcceptedAt: Date?

        init() {}
    }
}

typealias ProfileRecord = SchemaV1.ProfileRecord

enum FlexFitMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

extension ProfileRecord {
    convenience init(profile p: UserProfile, now: Date = .now) {
        self.init()
        update(from: p, now: now)
        healthNoticeAcceptedAt = now
    }

    func update(from p: UserProfile, now: Date = .now) {
        name = p.name
        birthYear = Calendar.current.component(.year, from: now) - p.age
        sex = p.sex.rawValue
        heightCm = p.heightCm
        weightKg = p.weightKg
        displayUnits = p.displayUnits.rawValue
        goal = p.goal.rawValue
        targetWeightKg = p.targetWeightKg
        pacePctPerWeek = p.pacePctPerWeek
        activity = p.activity.rawValue
        experience = p.experience.rawValue
        trainingDays = p.trainingDays
        sessionMinutes = p.sessionMinutes
        environment = p.environment.rawValue
        equipment = p.equipment.map(\.rawValue).sorted()
        limitations = p.limitations.map(\.rawValue).sorted()
    }

    func profile(now: Date = .now) -> UserProfile {
        UserProfile(
            name: name,
            age: Calendar.current.component(.year, from: now) - birthYear,
            sex: Sex(rawValue: sex) ?? .unspecified,
            heightCm: heightCm,
            weightKg: weightKg,
            displayUnits: DisplayUnits(rawValue: displayUnits) ?? .metric,
            goal: Goal(rawValue: goal) ?? .maintain,
            targetWeightKg: targetWeightKg,
            pacePctPerWeek: pacePctPerWeek,
            activity: ActivityLevel(rawValue: activity) ?? .seated,
            experience: Experience(rawValue: experience) ?? .beginner,
            trainingDays: trainingDays,
            sessionMinutes: sessionMinutes,
            environment: TrainingEnvironment(rawValue: environment) ?? .homeGym,
            equipment: Set(equipment.compactMap(Equipment.init(rawValue:))),
            limitations: Set(limitations.compactMap(Limitation.init(rawValue:)))
        )
    }
}
