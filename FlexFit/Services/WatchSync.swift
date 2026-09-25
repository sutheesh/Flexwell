import Foundation
import SwiftData
import WatchConnectivity
import FlexFitEngine

/// Phone side of the Watch session view (PRD Phase 3): sends today's session, receives logged sets.
@MainActor
final class WatchSync: NSObject {
    static let shared = WatchSync()
    private var container: ModelContainer?
    private var lastSent: WatchSession?

    func activate(container: ModelContainer) {
        guard WCSession.isSupported() else { return }
        self.container = container
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Latest-wins: the Watch always gets the current version of today's session.
    func send(_ session: WatchSession) {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated,
              WCSession.default.isPaired, WCSession.default.isWatchAppInstalled,
              session != lastSent, let data = try? JSONEncoder().encode(session) else { return }
        try? WCSession.default.updateApplicationContext([WatchKeys.session: data])
        lastSent = session
    }

    /// Builds the Watch payload from a resolved plan, with the same pre-fills as the phone's workout screen.
    static func payload(plan: SessionPlan, day: Date, sessions: [SessionLog]) -> WatchSession {
        let exercises = plan.exercises.compactMap { planned -> WatchSession.Exercise? in
            guard let ex = ExerciseLibrary.bundled[planned.exerciseID] else { return nil }
            let last = sessions.sorted { $0.finishedAt > $1.finishedAt }
                .lazy.compactMap { $0.entries.first { $0.exerciseID == ex.id }?.sets }.first
            let sets = Progression.prefill(planned, exercise: ex, last: last).map { WatchSet(value: $0.value, loadKg: $0.loadKg) }
            return .init(id: ex.id, name: ex.name, detail: ExerciseCopy.prescription(planned), sets: sets,
                         isTimed: planned.measure == .seconds)
        }
        return WatchSession(day: Calendar.current.startOfDay(for: day), title: plan.focus.title,
                            subtitle: "\(plan.minutes) min · RPE ≤ \(plan.exercises.first?.rpeCap ?? 8)", exercises: exercises)
    }

    private func save(_ logged: WatchLoggedSession) {
        guard let container, !logged.entries.isEmpty else { return }
        let context = ModelContext(container)
        let session = SessionLog(day: Calendar.current.startOfDay(for: logged.day))
        session.startedAt = logged.startedAt
        session.finishedAt = logged.finishedAt
        session.entries = logged.entries.map { id, sets in
            LoggedExerciseRecord(exerciseID: id, sets: sets.map { SetResult(value: $0.value, loadKg: $0.loadKg) })
        }
        context.insert(session)
        let log = DailyLog.forDay(logged.day, in: context)
        for id in logged.entries.keys where !log.completedExercises.contains(id) { log.completedExercises.append(id) }
        try? context.save()
    }
}

extension WatchSync: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {}
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo[WatchKeys.logged] as? Data,
              let logged = try? JSONDecoder().decode(WatchLoggedSession.self, from: data) else { return }
        Task { @MainActor in WatchSync.shared.save(logged) }
    }
}
