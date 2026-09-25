import Foundation
import SwiftData
import FlexFitEngine

/// Launch arguments for development and UI tests. Compiled out of Release.
///   -FFResetData      wipe the store on launch (see onboarding again)
///   -FFSeedProfile    insert the PRD's demo user and skip onboarding
///   -FFLowYesterday   with -FFSeedProfile: log yesterday as a low-energy day
///   -FFSeedHistory    with -FFSeedProfile: six weeks of weigh-ins and logged sessions
///   -FFPro            treat the user as Pro (see EntitlementService)
enum DebugLaunch {
    static func apply(to container: ModelContainer) {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        let context = ModelContext(container)
        if args.contains("-FFResetData") || args.contains("-FFSeedProfile") {
            try? context.delete(model: ProfileRecord.self)
            try? context.delete(model: DailyLog.self)
            try? context.delete(model: ExerciseSwap.self)
            try? context.delete(model: SessionLog.self)
            try? context.delete(model: WeighIn.self)
            try? context.delete(model: WeeklyTargets.self)
            try? context.delete(model: PainFlag.self)
            try? context.delete(model: IngredientSwapRecord.self)
            try? context.delete(model: GroceryCheck.self)
            try? context.delete(model: PantryItem.self)
        }
        if args.contains("-FFSeedProfile") {
            context.insert(ProfileRecord(profile: .demo))
            if args.contains("-FFSeedHistory") { seedHistory(context) }
            if args.contains("-FFLowYesterday"), let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now) {
                DailyLog.forDay(yesterday, in: context).energyValue = .low
            }
        }
        try? context.save()
        #endif
    }

    #if DEBUG
    private static func seedHistory(_ context: ModelContext) {
        let cal = Calendar.current
        let now = Date.now
        // Profile created six weeks ago; weekly weigh-ins drifting down about 0.4 kg a week.
        if let record = try? context.fetch(FetchDescriptor<ProfileRecord>()).first {
            record.createdAt = cal.date(byAdding: .day, value: -42, to: now) ?? now
        }
        for week in 0...6 {
            guard let date = cal.date(byAdding: .day, value: -7 * (6 - week), to: now) else { continue }
            context.insert(WeighIn(date: date, kg: 82 - Double(week) * 0.4 + (week % 2 == 0 ? 0.2 : -0.1)))
        }
        // Four sessions a week for the previous three weeks: an unbroken 3-week streak.
        let lifts: [(String, [SetResult])] = [
            ("db_flat_press", Array(repeating: SetResult(value: 10, loadKg: 22), count: 3)),
            ("kb_row", Array(repeating: SetResult(value: 12, loadKg: 16), count: 3)),
            ("db_goblet_squat", Array(repeating: SetResult(value: 12, loadKg: 24), count: 3)),
            ("db_romanian_deadlift", Array(repeating: SetResult(value: 10, loadKg: 20), count: 3)),
        ]
        for weeksAgo in 1...3 {
            let monday = cal.date(byAdding: .day, value: -7 * weeksAgo, to: Week.start(of: now)) ?? now
            for offset in [0, 1, 3, 4] {
                guard let day = cal.date(byAdding: .day, value: offset, to: monday) else { continue }
                let session = SessionLog(day: day)
                session.finishedAt = day.addingTimeInterval(3_600 * 18)
                session.startedAt = session.finishedAt.addingTimeInterval(-2_700)
                session.entries = lifts.map { LoggedExerciseRecord(exerciseID: $0.0, sets: $0.1.map { var s = $0; s.value -= weeksAgo - 1; return s }) }
                context.insert(session)
            }
        }
        context.insert(ExerciseSwap(day: cal.date(byAdding: .day, value: -9, to: cal.startOfDay(for: now)),
                                    originalID: "db_flat_press", replacementID: "db_floor_press"))
    }
    #endif
}

extension UserProfile {
    /// Alex, the PRD's primary persona (food answers from the PRD's schema example).
    static let demo: UserProfile = {
        var p = demoBase
        p.diet = .highProtein
        p.cuisines = [.indian, .western]
        p.allergens = [.peanuts]
        p.dislikes = ["Mushrooms"]
        p.maxCookMinutes = 20
        p.mealPattern = .threePlusSnack
        return p
    }()

    private static let demoBase = UserProfile(
        name: "Alex", age: 29, sex: .male, heightCm: 178, weightKg: 82, displayUnits: .metric,
        goal: .lose, targetWeightKg: 75, pacePctPerWeek: 0.5, activity: .seated, experience: .intermediate,
        trainingDays: 4, sessionMinutes: 45, environment: .homeGym,
        equipment: TrainingEnvironment.homeGym.presetEquipment, limitations: [.lowerBack]
    )
}
