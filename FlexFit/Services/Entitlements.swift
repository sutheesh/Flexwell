import Foundation
import Observation
import FlexFitEngine

/// The one place every Pro limit is decided (PRD Monetization). Knows nothing about StoreKit.
@Observable
final class EntitlementService {
    /// Mirrored from the store, not read through, so views observing this redraw when a purchase lands.
    private(set) var isPurchased = false

    #if DEBUG
    /// Launch with -FFPro to exercise every gate without the store. Compiled out of Release.
    var debugProOverride = ProcessInfo.processInfo.arguments.contains("-FFPro")
    #endif

    var isPro: Bool {
        #if DEBUG
        if debugProOverride { return true }
        #endif
        return isPurchased
    }

    func premiumStatusChanged(to purchased: Bool) {
        isPurchased = purchased
    }

    // MARK: Gates

    /// Energy check-in pivots left this month: 3 free, unlimited (nil) on Pro. Today's counts once spent.
    func pivotsLeftThisMonth(logs: [DailyLog], now: Date = .now) -> Int? {
        guard !isPro else { return nil }
        let spent = logs.filter {
            Calendar.current.isDate($0.day, equalTo: now, toGranularity: .month) && $0.energyValue == .low
        }.count
        return max(0, FreeTier.pivotsPerMonth - spent)
    }

    /// Whether choosing Low today needs Pro. Re-picking an already-spent Low never does.
    func lowNeedsPro(todayIsLow: Bool, logs: [DailyLog], now: Date = .now) -> Bool {
        guard !todayIsLow, let left = pivotsLeftThisMonth(logs: logs, now: now) else { return false }
        return left <= 0
    }

    var canUseTravelMode: Bool { isPro }
    var hasAdaptiveTargets: Bool { isPro }

    /// Free users see the last 30 days of progress; nothing is ever deleted.
    func historyStart(now: Date = .now) -> Date? {
        isPro ? nil : Calendar.current.date(byAdding: .day, value: -FreeTier.historyDays, to: now)
    }
}
