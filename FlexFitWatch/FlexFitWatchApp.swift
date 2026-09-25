import SwiftUI
import WatchConnectivity

@main
struct FlexFitWatchApp: App {
    @State private var store = WatchStore()

    var body: some Scene {
        WindowGroup {
            SessionListView()
                .environment(store)
                .onAppear { store.activate() }
        }
    }
}

/// Watch side: holds today's session from the phone and the sets confirmed on the wrist.
@Observable
@MainActor
final class WatchStore: NSObject, WCSessionDelegate {
    var session: WatchSession?
    var confirmed: [String: Set<Int>] = [:]
    var startedAt: Date?
    var finished = false

    func activate() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-FFWatchDemo") { session = .demo }
        #endif
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func toggle(_ exercise: String, set index: Int) {
        if startedAt == nil { startedAt = .now }
        var sets = confirmed[exercise, default: []]
        if sets.contains(index) { sets.remove(index) } else { sets.insert(index) }
        confirmed[exercise] = sets
    }

    var confirmedCount: Int { confirmed.values.reduce(0) { $0 + $1.count } }

    func finish() {
        guard let session, confirmedCount > 0 else { return }
        var entries: [String: [WatchSet]] = [:]
        for ex in session.exercises {
            let done = (confirmed[ex.id] ?? []).sorted().compactMap { ex.sets.indices.contains($0) ? ex.sets[$0] : nil }
            if !done.isEmpty { entries[ex.id] = done }
        }
        let logged = WatchLoggedSession(day: session.day, startedAt: startedAt ?? .now, finishedAt: .now, entries: entries)
        if let data = try? JSONEncoder().encode(logged) {
            // Queued and delivered even if the phone isn't reachable right now.
            WCSession.default.transferUserInfo([WatchKeys.logged: data])
        }
        finished = true
    }

    // MARK: WCSessionDelegate

    nonisolated func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        let data = session.receivedApplicationContext[WatchKeys.session] as? Data
        Task { @MainActor in self.apply(data) }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        let data = context[WatchKeys.session] as? Data
        Task { @MainActor in self.apply(data) }
    }

    private func apply(_ data: Data?) {
        guard let data, let incoming = try? JSONDecoder().decode(WatchSession.self, from: data) else { return }
        if incoming.day != session?.day { confirmed = [:]; finished = false; startedAt = nil }
        session = incoming
    }
}
