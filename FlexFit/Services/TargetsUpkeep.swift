import SwiftUI
import SwiftData
import FlexFitEngine

enum TargetsStore {
    /// The targets in force today: the latest weekly record, else the initial calculation.
    static func current(_ weekly: [WeeklyTargets], profile: UserProfile, now: Date = .now) -> DailyTargets {
        weekly.filter { $0.weekOf <= now }.max { $0.weekOf < $1.weekOf }?.dailyTargets
            ?? TargetCalculator.initialTargets(for: profile)
    }

    static func weightEntries(_ weighIns: [WeighIn]) -> [WeightEntry] {
        weighIns.map { WeightEntry(date: $0.date, kg: $0.kg) }
    }

    /// Makes sure this week has a targets record. Pro recalculates from the trend; free keeps static targets.
    @MainActor
    static func upkeep(context: ModelContext, record: ProfileRecord, isPro: Bool, now: Date = .now) {
        let profile = record.profile()
        let thisWeek = Week.start(of: now)
        let weekly = (try? context.fetch(FetchDescriptor<WeeklyTargets>(sortBy: [SortDescriptor(\.weekOf)]))) ?? []
        guard !weekly.contains(where: { $0.weekOf == thisWeek }) else { return }

        let new = WeeklyTargets(weekOf: thisWeek)
        guard let previous = weekly.last else {
            new.apply(TargetCalculator.initialTargets(for: profile))
            context.insert(new)
            try? context.save()
            return
        }

        let weighIns = (try? context.fetch(FetchDescriptor<WeighIn>())) ?? []
        let entries = weightEntries(weighIns).filter { $0.date < thisWeek }
        let trend = WeightTrend.series(entries).last?.kg
        new.trendKg = trend

        if isPro, let trend, let change = WeightTrend.weeklyChange(entries, asOf: thisWeek) {
            let fastNow = AdaptiveTargets.isFastLoss(trendChangeKg: change, trendWeightKg: trend)
            let fastWeeks = fastNow ? (previousWasFast(previous, weekly) ? 2 : 1) : 0
            let update = AdaptiveTargets.weeklyUpdate(profile: profile, previous: previous.dailyTargets,
                                                      trendChangeKg: change, trendWeightKg: trend,
                                                      fastLossWeeks: fastWeeks)
            new.apply(update.targets)
            new.rapidLossWarning = update.rapidLossWarning
        } else {
            new.apply(previous.dailyTargets)
        }
        context.insert(new)
        try? context.save()
    }

    /// Whether last week's recorded trend fell faster than 1.5% of body weight (first of the two weeks).
    private static func previousWasFast(_ previous: WeeklyTargets, _ weekly: [WeeklyTargets]) -> Bool {
        guard let before = weekly.dropLast().last, let a = before.trendKg, let b = previous.trendKg else { return false }
        return AdaptiveTargets.isFastLoss(trendChangeKg: b - a, trendWeightKg: b)
    }

    /// Imports Apple Health body weights since the last imported one.
    @MainActor
    static func importHealthWeights(context: ModelContext) async {
        let existing = (try? context.fetch(FetchDescriptor<WeighIn>())) ?? []
        let since = existing.filter { $0.source == "health" }.map(\.date).max()
            ?? Calendar.current.date(byAdding: .day, value: -90, to: .now) ?? .now
        let known = Set(existing.map(\.date))
        for (date, kg) in await HealthService.shared.weights(since: since) where !known.contains(date) {
            context.insert(WeighIn(date: date, kg: kg, source: "health"))
        }
        try? context.save()
    }

    /// Pulls body fat, lean mass and waist from Health (from the last imported sample, or 180 days back).
    @MainActor
    static func importHealthBodyMetrics(context: ModelContext) async {
        let existing = (try? context.fetch(FetchDescriptor<BodyMeasurement>())) ?? []
        for metric in ProgressReport.BodyMetric.allCases {
            let mine = existing.filter { $0.kind == metric.rawValue }
            let since = mine.filter { $0.source == "health" }.map(\.date).max()
                ?? Calendar.current.date(byAdding: .day, value: -180, to: .now) ?? .now
            let known = Set(mine.map(\.date))
            for (date, value) in await HealthService.shared.bodyMetrics(metric, since: since) where !known.contains(date) {
                context.insert(BodyMeasurement(date: date, kind: metric, value: value, source: "health"))
            }
        }
        try? context.save()
    }
}

private struct WeeklyTargetsUpkeep: ViewModifier {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var phase
    @Environment(EntitlementService.self) private var entitlements
    @Query private var profiles: [ProfileRecord]

    func body(content: Content) -> some View {
        content
            .task(id: phase) {
                guard phase == .active, let record = profiles.first else { return }
                if record.healthSyncEnabled {
                    // Health sync turned on before body composition and walking were read: ask once for the
                    // new types (iOS only prompts for ones not yet answered).
                    if !UserDefaults.standard.bool(forKey: "healthReadsV2") {
                        _ = await HealthService.shared.requestAuthorization()
                        UserDefaults.standard.set(true, forKey: "healthReadsV2")
                    }
                    await TargetsStore.importHealthWeights(context: context)
                    await TargetsStore.importHealthBodyMetrics(context: context)
                }
                TargetsStore.upkeep(context: context, record: record, isPro: entitlements.isPro)
            }
    }
}

extension View {
    func weeklyTargetsUpkeep() -> some View { modifier(WeeklyTargetsUpkeep()) }
}
