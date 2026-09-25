import SwiftUI
import SwiftData
import Charts
import FlexFitEngine

/// Path (PRD F8): goal, weight trend against the planned line, streak, volume per muscle,
/// personal records, and what the plan adapted. Free shows the last 30 days.
struct PathView: View {
    @Environment(AppRouter.self) private var router
    @Environment(EntitlementService.self) private var entitlements
    @Query private var profiles: [ProfileRecord]
    @Query(sort: \WeighIn.date) private var weighIns: [WeighIn]
    @Query(sort: \SessionLog.day) private var sessions: [SessionLog]
    @Query private var logs: [DailyLog]
    @Query(sort: \ExerciseSwap.createdAt, order: .reverse) private var swaps: [ExerciseSwap]
    @Query(sort: \WeeklyTargets.weekOf) private var weekly: [WeeklyTargets]
    @Query private var ingredientSwaps: [IngredientSwapRecord]
    @Environment(\.modelContext) private var modelContext
    @State private var mealDetail: MealSelection?

    var body: some View {
        if let record = profiles.first {
            content(record: record, profile: record.profile())
        }
    }

    private func content(record: ProfileRecord, profile: UserProfile) -> some View {
        let since = entitlements.historyStart()
        let visibleSessions = sessions.filter { since == nil || $0.day >= since! }
        let logged = visibleSessions.flatMap(\.loggedExercises)
        let weeks = TargetCalculator.weeksToGoal(for: profile)
        let elapsed = TodayPlan.weekNumber(since: record.createdAt, now: .now) - 1
        let remaining = weeks.map { max(0, $0 - elapsed) }
        let streak = Streak.weeks(sessionsPerWeek: sessionsPerWeek(), planned: profile.trainingDays)

        return ScrollView {
            VStack(alignment: .leading, spacing: Space.md - 2) {
                HeaderButton(name: profile.name, kicker: "Your path",
                             title: remaining.map { $0 == 0 ? "Goal week" : "\($0) weeks to goal" } ?? "Holding steady")

                // The trend is computed from every weigh-in; the free tier only limits what's drawn.
                GoalPanel(profile: profile, start: record.createdAt, entries: TargetsStore.weightEntries(weighIns),
                          visibleFrom: since,
                          weeks: weeks, streak: streak, sessions: sessions.count, adaptations: adaptationCount())

                if since != nil {
                    Button { router.paywall = .history } label: {
                        ActionRowContent(icon: "clock.arrow.circlepath", title: "Showing the last 30 days",
                                         subtitle: "Pro shows your full history. Nothing older is deleted.")
                    }
                    .buttonStyle(.plain)
                    .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.md))
                    .cardShadow()
                }

                SectionHeader(title: "The road to \(Formatters.mass(profile.targetWeightKg, units: profile.displayUnits))")
                RoadSection(profile: profile, targets: TargetsStore.current(weekly, profile: profile),
                            weeks: weeks, currentWeek: elapsed + 1)

                SectionHeader(title: "Day by day")
                DayByDaySection(profile: profile, targets: TargetsStore.current(weekly, profile: profile),
                                swaps: ingredientSwaps) { mealDetail = $0 }

                SectionHeader(title: "Volume by muscle")
                VolumeCard(volume: ProgressStats.volume(logged))

                SectionHeader(title: "Personal records")
                RecordsCard(records: ProgressStats.records(logged), units: profile.displayUnits)

                SectionHeader(title: "How the plan adapted")
                AdaptLog(items: adaptLog(since: since))
            }
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.xs)
            .padding(.bottom, Space.xl)
            .readableColumn()
        }
        .statusBarBackdrop()
        .pageBackground()
        .sheet(item: $mealDetail) { selection in
            MealDetailView(planned: selection.planned,
                           isEaten: logs.first { Calendar.current.isDate($0.day, inSameDayAs: selection.date) }?.eatenMeals.contains(selection.planned.index) == true,
                           onToggleEaten: {
                               let log = DailyLog.forDay(selection.date, in: modelContext)
                               if let i = log.eatenMeals.firstIndex(of: selection.planned.index) { log.eatenMeals.remove(at: i) }
                               else { log.eatenMeals.append(selection.planned.index) }
                               try? modelContext.save()
                           },
                           onMissingIngredient: { mealDetail = nil; router.tab = .eat })
        }
    }

    /// Completed sessions per week, index 0 = this week.
    private func sessionsPerWeek() -> [Int] {
        let thisWeek = Week.start(of: .now)
        var counts: [Int] = Array(repeating: 0, count: 53)
        for s in sessions {
            let weeksAgo = (Calendar.current.dateComponents([.day], from: Week.start(of: s.day), to: thisWeek).day ?? 0) / 7
            if (0..<counts.count).contains(weeksAgo) { counts[weeksAgo] += 1 }
        }
        return counts
    }

    private func adaptationCount() -> Int {
        swaps.count + logs.filter { $0.energyValue == .low || !$0.soreAreas.isEmpty }.count
    }

    private func adaptLog(since: Date?) -> [AdaptLog.Item] {
        var items: [AdaptLog.Item] = []
        for swap in swaps where since == nil || swap.createdAt >= since! {
            let from = ExerciseLibrary.bundled[swap.originalID]?.name ?? swap.originalID
            let to = ExerciseLibrary.bundled[swap.replacementID]?.name ?? swap.replacementID
            items.append(.init(date: swap.createdAt, text: swap.day == nil ? "Swapped \(from) for \(to) for good." : "\(from) taken: swapped to \(to)."))
        }
        for log in logs where since == nil || log.day >= since! {
            if log.energyValue == .low { items.append(.init(date: log.day, text: "Low energy: session trimmed, streak kept.")) }
            if !log.soreAreas.isEmpty {
                let areas = log.soreAreas.compactMap { SoreArea(rawValue: $0)?.title.lowercased() }.joined(separator: ", ")
                items.append(.init(date: log.day, text: "Sore \(areas): exercises swapped."))
            }
        }
        return items.sorted { $0.date > $1.date }.prefix(12).map { $0 }
    }
}

/// Navy goal panel with the trend chart. Fixed-dark content.
private struct GoalPanel: View {
    let profile: UserProfile
    let start: Date
    let entries: [WeightEntry]
    let visibleFrom: Date?
    let weeks: Int?
    let streak: Int
    let sessions: Int
    let adaptations: Int

    var body: some View {
        let fullTrend = WeightTrend.series(entries)
        let trend = fullTrend.filter { visibleFrom == nil || $0.date >= visibleFrom! }
        let units = profile.displayUnits
        // Window: plan start (or the visible limit) to four weeks past today, so the real trend isn't squashed.
        let windowStart = max(start, visibleFrom ?? start)
        let windowEnd = Calendar.current.date(byAdding: .day, value: 28, to: .now) ?? .now
        VStack(alignment: .leading, spacing: Space.md) {
            HStack {
                stat(Formatters.mass(profile.weightKg, units: units), "Start")
                stat(fullTrend.last.map { Formatters.mass($0.kg, units: units) } ?? "—", "Now")
                stat(Formatters.mass(profile.targetWeightKg, units: units), "Goal")
            }

            if trend.count >= 2 {
                Chart {
                    if weeks != nil {
                        ForEach([windowStart, windowEnd], id: \.self) { date in
                            LineMark(x: .value("Date", date), y: .value("Plan", Mass.display(kilograms: planned(at: date), in: units)),
                                     series: .value("Line", "Plan"))
                                .foregroundStyle(Palette.onPanelOutline)
                                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        }
                    }
                    ForEach(trend, id: \.date) { e in
                        LineMark(x: .value("Date", e.date), y: .value("Trend", Mass.display(kilograms: e.kg, in: units)), series: .value("Line", "Trend"))
                            .foregroundStyle(Palette.copper)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))
                    }
                }
                .chartLegend(.hidden)
                .chartYScale(domain: .automatic(includesZero: false))
                .chartXScale(domain: windowStart...windowEnd)
                .chartXAxis { AxisMarks { _ in AxisValueLabel().foregroundStyle(Palette.onPanelMuted) } }
                .chartYAxis { AxisMarks { _ in AxisGridLine().foregroundStyle(Palette.onPanelHairline); AxisValueLabel().foregroundStyle(Palette.onPanelMuted) } }
                .frame(height: Size.row * 2.5)
                .accessibilityLabel("Weight trend against the planned line")
            } else {
                Text("Log two weigh-ins on the Eat tab to see your trend against the plan.")
                    .textStyle(.caption)
                    .foregroundStyle(Palette.onPanelMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 0) {
                stat(streak == 1 ? "1 week" : "\(streak) weeks", "Streak")
                stat("\(sessions)", "Sessions done")
                stat("\(adaptations)×", "Plan adapted")
            }
            .padding(.top, Space.sm)
            .overlay(alignment: .top) { Rectangle().fill(Palette.onPanelHairline).frame(height: 1) }
        }
        .padding(Space.lg)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Palette.panelEdge))
    }

    /// Where the plan says the weight should be on `date`: a straight line from start to goal.
    private func planned(at date: Date) -> Double {
        guard let weeks, weeks > 0 else { return profile.weightKg }
        let fraction = min(1, max(0, date.timeIntervalSince(start) / (Double(weeks) * 7 * 86_400)))
        return profile.weightKg + (profile.targetWeightKg - profile.weightKg) * fraction
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: Space.xxs + 2) {
            Text(value).textStyle(.statValue).foregroundStyle(Palette.onPanel)
            Text(label).textStyle(.micro).foregroundStyle(Palette.onPanelMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct VolumeCard: View {
    let volume: [Muscle: Int]

    var body: some View {
        let rows = volume.sorted { $0.value > $1.value }.prefix(8)
        Group {
            if rows.isEmpty {
                Text("Finish a workout to see how many sets each muscle group gets.")
                    .textStyle(.caption)
                    .foregroundStyle(Palette.inkMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Chart(Array(rows), id: \.key) { item in
                    BarMark(x: .value("Sets", item.value), y: .value("Muscle", item.key.title))
                        .foregroundStyle(Palette.copperText)
                        .annotation(position: .trailing) {
                            Text("\(item.value)").textStyle(.micro).foregroundStyle(Palette.inkMuted)
                        }
                }
                .chartXAxis(.hidden)
                .chartYAxis { AxisMarks { _ in AxisValueLabel().foregroundStyle(Palette.ink) } }
                .frame(height: CGFloat(rows.count) * Size.control * 0.7)
                .accessibilityLabel("Working sets per muscle group")
            }
        }
        .padding(Space.md)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.md))
        .cardShadow()
    }
}

private struct RecordsCard: View {
    let records: [PersonalRecord]
    let units: DisplayUnits

    var body: some View {
        if records.isEmpty {
            Text("Records appear as you log sets.")
                .textStyle(.caption)
                .foregroundStyle(Palette.inkMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Space.md)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.md))
                .cardShadow()
        } else {
            CardList {
                ForEach(records.prefix(6), id: \.exerciseID) { r in
                    HStack {
                        VStack(alignment: .leading, spacing: Space.xxs) {
                            Text(ExerciseLibrary.bundled[r.exerciseID]?.name ?? r.exerciseID)
                                .textStyle(.rowTitle)
                                .foregroundStyle(Palette.ink)
                            Text(r.date.formatted(.dateTime.day().month(.abbreviated)))
                                .textStyle(.caption)
                                .foregroundStyle(Palette.inkMuted)
                        }
                        Spacer()
                        Text(r.isLoad ? "e1RM " + Formatters.mass(r.value, units: units) : "\(Int(r.value)) reps")
                            .textStyle(.label)
                            .foregroundStyle(Palette.copperText)
                    }
                    .padding(.horizontal, Space.md)
                    .padding(.vertical, Space.sm)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

private struct AdaptLog: View {
    struct Item: Hashable {
        let date: Date
        let text: String
    }
    let items: [Item]

    var body: some View {
        if items.isEmpty {
            Text("Swaps, low-energy days and travel will show up here. Every one is a session you didn't skip.")
                .textStyle(.caption)
                .foregroundStyle(Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Space.md)
                .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.md))
                .cardShadow()
        } else {
            CardList {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: Space.sm) {
                        Text(item.date.formatted(.dateTime.weekday(.abbreviated)).uppercased())
                            .textStyle(.micro)
                            .foregroundStyle(Palette.copperText)
                            .frame(width: Size.control, alignment: .leading)
                        Text(item.text)
                            .textStyle(.caption)
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, Space.md)
                    .padding(.vertical, Space.sm)
                }
            }
        }
    }
}

extension Muscle {
    var title: String {
        switch self {
        case .chest: "Chest"
        case .frontDelts: "Front delts"
        case .sideDelts: "Side delts"
        case .rearDelts: "Rear delts"
        case .lats: "Lats"
        case .upperBack: "Upper back"
        case .traps: "Traps"
        case .biceps: "Biceps"
        case .triceps: "Triceps"
        case .forearms: "Forearms"
        case .quads: "Quads"
        case .glutes: "Glutes"
        case .hamstrings: "Hamstrings"
        case .adductors: "Adductors"
        case .calves: "Calves"
        case .core: "Core"
        case .obliques: "Obliques"
        case .lowerBack: "Lower back"
        case .hipFlexors: "Hip flexors"
        case .hips: "Hips"
        case .cardio: "Conditioning"
        }
    }
}
