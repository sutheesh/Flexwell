import Foundation
import SwiftData
import FlexFitEngine

/// Launch arguments for development and UI tests. Compiled out of Release.
///   -FFResetData      wipe the store on launch (see onboarding again)
///   -FFSeedProfile    insert the PRD's demo user and skip onboarding
///   -FFLowYesterday   with -FFSeedProfile: log yesterday as a low-energy day
enum DebugLaunch {
    static func apply(to container: ModelContainer) {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        let context = ModelContext(container)
        if args.contains("-FFResetData") || args.contains("-FFSeedProfile") {
            try? context.delete(model: ProfileRecord.self)
            try? context.delete(model: DailyLog.self)
        }
        if args.contains("-FFSeedProfile") {
            context.insert(ProfileRecord(profile: .demo))
            if args.contains("-FFLowYesterday"), let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now) {
                DailyLog.forDay(yesterday, in: context).energyValue = .low
            }
        }
        try? context.save()
        #endif
    }
}

extension UserProfile {
    /// Alex, the PRD's primary persona.
    static let demo = UserProfile(
        name: "Alex", age: 29, sex: .male, heightCm: 178, weightKg: 82, displayUnits: .metric,
        goal: .lose, targetWeightKg: 75, pacePctPerWeek: 0.5, activity: .seated, experience: .intermediate,
        trainingDays: 4, sessionMinutes: 45, environment: .homeGym,
        equipment: TrainingEnvironment.homeGym.presetEquipment, limitations: [.lowerBack]
    )
}
