import SwiftUI
import SwiftData
import WidgetKit
import FlexFitEngine

/// Today: a glance and the next action — the energy check-in, the session to start, the next meal.
/// The full plans live on Train and Eat; the calorie card lives on Eat.
struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Environment(EntitlementService.self) private var entitlements
    @Query private var profiles: [ProfileRecord]
    @Query(sort: \DailyLog.day, order: .reverse) private var logs: [DailyLog]
    @Query(sort: \WeeklyTargets.weekOf) private var weekly: [WeeklyTargets]
    @Query private var sessions: [SessionLog]
    @Query private var swaps: [ExerciseSwap]
    @Query private var painFlags: [PainFlag]
    @Query private var ingredientSwaps: [IngredientSwapRecord]
    @Query private var foodEntries: [FoodEntry]
    @Query(sort: \WeighIn.date) private var weighIns: [WeighIn]
    @Query(sort: \BodyMeasurement.date) private var measurements: [BodyMeasurement]
    @State private var walking: HealthService.Walking?
    @State private var isLoggingProgress = false
    /// "Later" on the weekly check-in hides it until this time (seconds since 1970).
    @AppStorage("checkInSnoozedUntil") private var checkInSnoozedUntil: Double = 0
    @State private var mealDetail: MealSelection?
    @State private var intro: String?

    var body: some View {
        if let record = profiles.first {
            content(record: record, profile: record.profile())
        }
    }

    private func content(record: ProfileRecord, profile: UserProfile) -> some View {
        let now = Date.now
        let plannedToday = TodayPlan.plannedDay(for: profile, on: now)
        let todayLog = log(for: now)
        let resolver = PlanResolver(record: record, swaps: swaps, logs: logs, painFlags: painFlags)
        let plan = resolver.session(forWeekday: TrainView.todayWeekday, on: now, applyPivot: true)
        let pivot = resolver.pivot(on: now, plannedMinutes: plannedToday.minutes)
        let targets = TargetsStore.current(weekly, profile: profile, now: now)
        let week = TodayPlan.weekNumber(since: record.createdAt, now: now)
        let streak = TodayPlan.streak(sessions: sessions, planned: profile.trainingDays, now: now)
        let doneToday = sessions.contains { Calendar.current.isDate($0.day, inSameDayAs: now) }
        let mealContext = MealPlanContext(profile: profile, targets: targets, swaps: ingredientSwaps)
        let intake = DayIntake(context: mealContext, date: now, logs: logs, entries: foodEntries)
        let meals = intake.meals
        let dayTarget = intake.target
        let eatenIdx = intake.eatenMealIndices
        let eaten = (kcal: intake.kcal, protein: intake.protein, carbs: intake.carbs, fat: intake.fat)
        let next = MealPlanContext.nextMeal(meals, eaten: eatenIdx, now: now)
        let snapshot = WidgetSnapshot(
            date: Calendar.current.startOfDay(for: now),
            sessionTitle: plannedToday.kind == .training ? (plan?.focus.title ?? "Training")
                : (plannedToday.kind == .rest ? "Rest day" : "Walk + mobility"),
            sessionDetail: plan.map { "\($0.minutes) min · \($0.exercises.count) exercises" }
                ?? (plannedToday.minutes > 0 ? "\(plannedToday.minutes) min · easy" : "Recover"),
            isTrainingDay: plannedToday.kind == .training,
            kcalEaten: eaten.kcal, kcalTarget: dayTarget, proteinTarget: targets.proteinG,
            streakWeeks: streak, nextMeal: next?.meal.name
        )

        return ScrollView {
            VStack(alignment: .leading, spacing: Space.md - 2) {
                TabHeader(name: profile.name.isEmpty ? "Y" : profile.name,
                          kicker: "\(now.formatted(.dateTime.weekday(.abbreviated))), \(DayMonth.text(now)) · " + (streak > 0 ? "🔥 \(streak)-week streak" : "week \(week)"),
                          title: profile.name.isEmpty ? "Hi there" : "Hi \(profile.name)", showsCart: false)

                if record.isSample {
                    SampleBanner { startOver() }
                }

                // First tile: growth since the start. Opens the full Progress page.
                NavigationLink(value: TodayRoute.progress) {
                    ProgressTile(snapshot: ProgressSnapshot.make(record: ProgressRecordInputs(
                                     profile: profile, weighIns: weighIns, measurements: measurements, sessions: sessions,
                                     logs: logs, foodEntries: foodEntries, weekly: weekly, swaps: ingredientSwaps),
                                     since: record.createdAt),
                                 walking: walking, healthOn: record.healthSyncEnabled)
                }
                .buttonStyle(.plain)

                if checkInDue(now: now) {
                    WeeklyCheckInCard(
                        daysSinceWeighIn: weighIns.last.map { Calendar.current.dateComponents([.day], from: $0.date, to: now).day ?? 0 },
                        onLog: { isLoggingProgress = true },
                        onLater: {
                            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now)) ?? now
                            withAnimation { checkInSnoozedUntil = tomorrow.timeIntervalSince1970 }
                        }
                    )
                }

                if plannedToday.kind == .training {
                    if todayLog?.energyValue == nil && profile.sleep.isShort {
                        Text("You said sleep often runs short. \"Low\" is an honest answer: the session shrinks, the streak holds.")
                            .textStyle(.caption)
                            .foregroundStyle(Palette.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, Space.xxs)
                    }
                    EnergyCheckIn(energy: todayLog?.energyValue, pivot: pivot,
                                  onPick: { pick($0, on: now) },
                                  onChange: { router.isEnergyPresented = true })
                }

                SessionCard(day: plannedToday, pivot: pivot, plan: plan, travel: record.activeTravelKit(now: now),
                            isDone: doneToday, intro: intro,
                            onStart: { router.workoutDay = Calendar.current.startOfDay(for: now) },
                            onOpen: { router.tab = .train })

                CardList {
                    ActionRow(icon: "bolt.fill", tint: .copper, title: "What changed?",
                              subtitle: "Low energy, no gym, a missing ingredient or eating out. One tap adapts today.") {
                        router.isAdaptPresented = true
                    }
                }

                if !meals.isEmpty || !intake.entries.isEmpty {
                    HStack(alignment: .firstTextBaseline) {
                        SectionHeader(title: next == nil ? "Today's food" : "Next meal")
                        Spacer()
                        Button { router.isScannerPresented = true } label: {
                            Label("Scan", systemImage: "viewfinder")
                        }
                        .textStyle(.label)
                        .foregroundStyle(Palette.copperText)
                    }
                    CardList {
                        ForEach(intake.entries) { entry in
                            FoodEntryRow(entry: entry) { remove(entry) }
                        }
                        if let next {
                            Button { mealDetail = MealSelection(date: now, planned: next) } label: {
                                TodayMealRow(meal: next, target: dayTarget, status: .upNext)
                            }
                            .buttonStyle(.plain)
                        }
                        Button { router.tab = .eat } label: {
                            FoodSummaryRow(eatenCount: intake.visibleMeals.filter { eatenIdx.contains($0.index) }.count,
                                           mealCount: intake.visibleMeals.count,
                                           kcalLeft: max(0, dayTarget - eaten.kcal))
                        }
                        .buttonStyle(.plain)
                    }
                }

                CardList {
                    Button { isLoggingProgress = true } label: {
                        ActionRowContent(icon: "square.and.pencil", title: "Log progress",
                                         subtitle: "Weight, body fat, lean mass, waist")
                    }
                    .buttonStyle(.plain)
                    NavigationLink(value: TodayRoute.path) {
                        ActionRowContent(icon: "point.topleft.down.to.point.bottomright.curvepath", title: "Your path",
                                         subtitle: pathLine(week: week, profile: profile))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.xs)
            .padding(.bottom, Space.xl)
            .readableColumn()
        }
        .statusBarBackdrop()
        .pageBackground()
        .sheet(isPresented: $isLoggingProgress) { LogProgressSheet(units: profile.displayUnits) }
        .task(id: record.healthSyncEnabled) {
            if record.healthSyncEnabled { walking = await HealthService.shared.walking(since: record.createdAt) }
        }
        .task {
            // One-time move of the old single "eating out" field onto the food log.
            for log in logs where log.eatenOutName != nil { log.migrateEatingOut(into: modelContext) }
            try? modelContext.save()
        }
        .task(id: snapshot) {
            // Keep the home-screen widget in step with Today.
            if WidgetSnapshot.load() != snapshot {
                snapshot.save()
                WidgetCenter.shared.reloadAllTimelines()
            }
            // And the Watch session view.
            if let plan { WatchSync.shared.send(WatchSync.payload(plan: plan, day: now, sessions: sessions)) }
        }
        .task(id: plan.map { introFacts(plan: $0, profile: profile, travel: record.activeTravelKit(now: now) != nil) }) {
            guard let plan else { intro = nil; return }
            intro = await CoachText.sessionIntro(introFacts(plan: plan, profile: profile, travel: record.activeTravelKit(now: now) != nil))
        }
        .sheet(item: $mealDetail) { selection in
            MealDetailView(planned: selection.planned,
                           isEaten: log(for: selection.date)?.eatenMeals.contains(selection.planned.index) == true,
                           onToggleEaten: { toggleEaten(selection) },
                           onMissingIngredient: { mealDetail = nil; router.tab = .eat })
        }
    }

    private func introFacts(plan: SessionPlan, profile: UserProfile, travel: Bool) -> CoachText.SessionFacts {
        CoachText.SessionFacts(name: profile.name, focus: plan.focus.title, minutes: plan.minutes,
                               exercises: plan.exercises.count, rpeCap: plan.exercises.first?.rpeCap ?? 8,
                               variant: plan.variant, travel: travel, tone: profile.tone)
    }

    // MARK: Meals & no-gym

    private func toggleEaten(_ selection: MealSelection) {
        let log = DailyLog.forDay(selection.date, in: modelContext)
        if let i = log.eatenMeals.firstIndex(of: selection.planned.index) {
            log.eatenMeals.remove(at: i)
        } else {
            log.eatenMeals.append(selection.planned.index)
        }
        log.updatedAt = .now
        try? modelContext.save()
    }

    /// "Can't make it to the gym": Travel Mode with no equipment until the end of today (Pro).
    /// "Week 7 of 18 · 12 weeks to go" for the Path tile.
    private func pathLine(week: Int, profile: UserProfile) -> String {
        guard let total = TargetCalculator.weeksToGoal(for: profile) else { return "Week \(week) · the road, day by day, what adapted" }
        let left = max(0, total - (week - 1))
        return "Week \(min(week, total)) of \(total) · " + (left == 0 ? "goal week" : "\(left) weeks to go")
    }

    /// Weekly check-in: due (no weigh-in for 7 days or measurements for 14) and not put off with "Later".
    private func checkInDue(now: Date) -> Bool {
        now.timeIntervalSince1970 >= checkInSnoozedUntil
            && ProgressReport.checkInDue(lastWeighIn: weighIns.last?.date, lastBodyMetric: measurements.last?.date, now: now)
    }

    // MARK: Logs

    private func log(for date: Date) -> DailyLog? {
        let start = Calendar.current.startOfDay(for: date)
        return logs.first { $0.day == start }
    }

    /// Low energy spends one of the free tier's monthly pivots; out of pivots opens the paywall.
    private func pick(_ energy: Energy, on date: Date) {
        if energy == .low, entitlements.lowNeedsPro(todayIsLow: log(for: date)?.energyValue == .low, logs: logs, now: date) {
            router.paywall = .pivots
            return
        }
        setEnergy(energy, on: date)
        let message = switch energy {
        case .high: "Full session. Loads up."
        case .ok: "Session as written."
        case .low: "Cut short. Still counts."
        }
        router.toast(message)
    }

    private func remove(_ entry: FoodEntry) {
        let wasDinner = entry.replacesDinner
        modelContext.delete(entry)
        try? modelContext.save()
        router.toast(wasDinner ? "Back to your planned dinner." : "Removed from today.")
    }

    /// "Build my plan" from a sample: clear the sample so onboarding starts.
    private func startOver() {
        for model in [ProfileRecord.self, DailyLog.self, ExerciseSwap.self, SessionLog.self, WeighIn.self, WeeklyTargets.self,
                      PainFlag.self, IngredientSwapRecord.self, GroceryCheck.self, PantryItem.self, SavedMeal.self, FoodEntry.self, FavoriteExercise.self, ExerciseNote.self, BodyMeasurement.self] as [any PersistentModel.Type] {
            try? modelContext.delete(model: model)
        }
        try? modelContext.save()
    }

    private func setEnergy(_ energy: Energy?, on date: Date) {
        withAnimation(.easeInOut(duration: 0.2)) {
            DailyLog.forDay(date, in: modelContext).energyValue = energy
        }
        try? modelContext.save()
    }
}

enum TodayPlan {
    /// Weeks in a row with the planned number of sessions (the streak pill).
    static func streak(sessions: [SessionLog], planned: Int, now: Date = .now) -> Int {
        let thisWeek = Week.start(of: now)
        var counts = Array(repeating: 0, count: 53)
        for s in sessions {
            let weeksAgo = (Calendar.current.dateComponents([.day], from: Week.start(of: s.day), to: thisWeek).day ?? 0) / 7
            if (0..<counts.count).contains(weeksAgo) { counts[weeksAgo] += 1 }
        }
        return Streak.weeks(sessionsPerWeek: counts, planned: planned)
    }

    /// The planned day for `date` (the engine's week starts on Monday).
    static func plannedDay(for profile: UserProfile, on date: Date) -> PlannedDay {
        let weekday = (Calendar.current.component(.weekday, from: date) + 5) % 7
        return WeekPlanner.week(for: profile)[weekday]
    }

    /// 1-based week of the plan, counted from when the profile was created.
    static func weekNumber(since start: Date, now: Date) -> Int {
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: start),
                                                   to: Calendar.current.startOfDay(for: now)).day ?? 0
        return max(0, days) / 7 + 1
    }
}

// MARK: - Targets

/// Navy panel: dark in both appearances, so its content uses fixed tokens.
/// 1:1 with the mock: date + streak pill, the 13-segment calorie arc, then three macro columns.
struct TargetsCard: View {
    let targets: DailyTargets
    let date: Date
    let weekLabel: String
    let eaten: (kcal: Int, protein: Int, carbs: Int, fat: Int)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("\(date.formatted(.dateTime.weekday(.wide))), \(date.formatted(.dateTime.day())) \(date.formatted(.dateTime.month(.wide)))")
                    .textStyle(.caption)
                    .foregroundStyle(Palette.onPanelMuted)
                Spacer()
                Text(weekLabel)
                    .textStyle(.micro)
                    .foregroundStyle(Palette.ice)
                    .padding(.horizontal, Space.sm - 1)
                    .padding(.vertical, Space.xs - 1)
                    .background(Palette.ice.opacity(0.14), in: Capsule())
            }

            CalorieArc(fraction: Double(eaten.kcal) / Double(max(1, targets.calories)))
                .overlay(alignment: .top) {
                    VStack(spacing: 0) {
                        Image(systemName: "bolt.fill")
                            .font(TextStyle.rowTitle.font)
                            .foregroundStyle(Palette.copper)
                        Text("\(Formatters.kcal(eaten.kcal)) kcal")
                            .textStyle(.arcValue)
                            .foregroundStyle(Palette.onPanel)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.top, Space.xs)
                        Text("Goal \(Formatters.kcal(targets.calories)) kcal")
                            .textStyle(.caption)
                            .foregroundStyle(Palette.copper)
                            .padding(.top, Space.xs - 1)
                    }
                    .frame(width: (Size.arcOuterRadius - Size.segment.height) * 2)
                    .padding(.top, Size.arcTextTop)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, Space.xxs)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(eaten.kcal) of \(targets.calories) kilocalories eaten today")

            HStack(spacing: 0) {
                MacroStat(label: "Protein", eaten: eaten.protein, target: targets.proteinG, fill: Palette.ice, first: true)
                MacroStat(label: "Carbs", eaten: eaten.carbs, target: targets.carbsG, fill: Palette.copper)
                MacroStat(label: "Fat", eaten: eaten.fat, target: targets.fatG, fill: Palette.sand)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, Space.md - 1)
            .overlay(alignment: .top) { Rectangle().fill(Palette.onPanelHairline).frame(height: 1) }
            .padding(.top, Space.xs - 2)
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.lg - 2)
        .padding(.bottom, Space.lg)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Palette.panelEdge))
    }
}

/// The mock's arc SVG, drawn 1:1: capsules pivot on (118, 122), spanning -102°…+102°.
private struct CalorieArc: View {
    let fraction: Double
    private let segments = 13

    var body: some View {
        let filled = Int((min(1, max(0, fraction)) * Double(segments)).rounded())
        // Distance from the pivot to each capsule's centre: outer end on radius 108.
        let centreRadius = Size.arcOuterRadius - Size.segment.height / 2
        ZStack(alignment: .topLeading) {
            ForEach(0..<segments, id: \.self) { i in
                Capsule()
                    .fill(i < filled ? Palette.copper : Palette.onPanelHairline)
                    .frame(width: Size.segment.width, height: Size.segment.height)
                    // Offset first (rendering only), then rotate about the layout centre = the pivot.
                    .offset(y: -centreRadius)
                    .rotationEffect(.degrees(-102 + Double(i) * 204 / Double(segments - 1)))
                    .position(Size.arcPivot)
            }
        }
        .frame(width: Size.arcBox.width, height: Size.arcBox.height)
    }
}

private struct MacroStat: View {
    let label: String
    let eaten: Int
    let target: Int
    let fill: Color
    var first = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .textStyle(.micro)
                .foregroundStyle(Palette.onPanelMuted)
            Text("\(eaten) / \(target)g")
                .textStyle(.rowTitle)
                .foregroundStyle(Palette.onPanel)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.top, Space.xs)
                .padding(.bottom, Space.xs + 1)
            Capsule()
                .fill(Palette.onPanelHairline)
                .frame(height: Size.progressBar)
                .overlay(alignment: .leading) {
                    GeometryReader { geo in
                        Capsule().fill(fill)
                            .frame(width: geo.size.width * min(1, Double(eaten) / Double(max(1, target))))
                    }
                }
        }
        .padding(.horizontal, first ? 0 : Space.sm - 2)
        .padding(.trailing, first ? Space.sm - 2 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .leading) {
            if !first { Rectangle().fill(Palette.onPanelHairline).frame(width: 1) }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Energy check-in

private struct EnergyCheckIn: View {
    let energy: Energy?
    let pivot: PivotResult?
    let onPick: (Energy) -> Void
    let onChange: () -> Void

    var body: some View {
        if let energy, let pivot {
            HStack(spacing: Space.sm - 2) {
                Image(systemName: "bolt.fill")
                    .font(TextStyle.chip.font)
                    .foregroundStyle(Palette.navy)
                    .frame(width: Size.checkRing + 8, height: Size.checkRing + 8)
                    .background(Palette.ice, in: Circle())
                    .accessibilityHidden(true)
                Text(EnergyCopy.summary(energy: energy, pivot: pivot))
                    .textStyle(.caption)
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: onChange) {
                    Text("Change")
                        .textStyle(.label)
                        .foregroundStyle(Palette.copperText)
                        .padding(.vertical, Space.sm)
                        .padding(.horizontal, Space.xs)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Change")
            }
            .padding(.horizontal, Space.xxs)
        } else {
            HStack(spacing: Space.sm - 2) {
                Text("How's your energy?")
                    .textStyle(.rowTitle)
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: Space.xxs) {
                    ForEach(Energy.allCases, id: \.self) { option in
                        Button { onPick(option) } label: {
                            Text(option.title)
                                .textStyle(.chip)
                                .foregroundStyle(Palette.ink)
                                .padding(.horizontal, Space.sm)
                                .padding(.vertical, Space.sm - 2)
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(option.title) energy")
                    }
                }
                .padding(Space.xxs)
                .background(Palette.card, in: Capsule())
                .cardShadow()
            }
            .padding(.horizontal, Space.xxs)
        }
    }
}

extension Energy {
    var title: String {
        switch self {
        case .high: "High"
        case .ok: "OK"
        case .low: "Low"
        }
    }
}

enum EnergyCopy {
    static func summary(energy: Energy, pivot: PivotResult) -> String {
        switch pivot.variant {
        case .full where energy == .high:
            "High energy: full session, push to RPE \(pivot.rpeCap). Finisher's on the table."
        case .full:
            "Normal day: session as written, RPE \(pivot.rpeCap) cap."
        case .trimmed:
            "Low energy: cut to \(pivot.minutes) min, top 3 lifts. Still counts."
        case .minimum:
            "Second low day: \(pivot.minutes)-min minimum session. Eat at maintenance today."
        }
    }

    static func sessionNote(day: PlannedDay, pivot: PivotResult?) -> String {
        guard day.kind == .training else {
            return day.kind == .rest ? "Rest day: walk, stretch, eat well." : "Brisk walk plus hips and T-spine mobility. Keeps legs fresh."
        }
        switch pivot?.variant {
        case .trimmed?: return "Top 3 compound lifts, 2 sets each. Streak kept."
        case .minimum?: return "Mobility plus one easy compound. Minimum still counts."
        default: return "Loads go up if last week felt clean."
        }
    }
}

// MARK: - Session card

/// Navy panel with the session illustration. Always dark, so fixed tokens throughout.
/// Today's session at a glance: what it is, how long, and Start. The picture and the plan are on Train.
private struct SessionCard: View {
    let day: PlannedDay
    let pivot: PivotResult?
    let plan: SessionPlan?
    let travel: TravelKit?
    let isDone: Bool
    /// On-device (or template) intro for today's session.
    var intro: String?
    let onStart: () -> Void
    let onOpen: () -> Void

    private var isTraining: Bool { day.kind == .training }
    private var minutes: Int { plan?.minutes ?? pivot?.minutes ?? day.minutes }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .center, spacing: Space.sm) {
                Button(action: onOpen) {
                    VStack(alignment: .leading, spacing: Space.xs - 2) {
                        HStack(spacing: Space.xs - 2) {
                            Circle().fill(Palette.blueText).frame(width: Size.dot, height: Size.dot)
                            Text(badge)
                                .textStyle(.micro)
                                .foregroundStyle(Palette.blueText)
                        }
                        Text(title)
                            .textStyle(.headline)
                            .foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        if isTraining, let focus = day.focus {
                            Text(focus.moves)
                                .textStyle(.micro)
                                .foregroundStyle(Palette.blueText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Text(meta)
                            .textStyle(.micro)
                            .foregroundStyle(Palette.inkMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the session on Train")

                if isTraining {
                    Button(action: onStart) {
                        Text(isDone ? "Log another ›" : "Start ›")
                            .textStyle(.label)
                            .foregroundStyle(Palette.onInkFill)
                            .padding(.horizontal, Space.md)
                            .frame(minHeight: Size.control)
                            .background(Palette.inkFill, in: Capsule())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel(isDone ? "Log another workout" : "Start workout")
                }
            }

            Text(intro ?? EnergyCopy.sessionNote(day: day, pivot: pivot))
                .textStyle(.caption)
                .foregroundStyle(Palette.inkMuted)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.md)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.lg))
        .cardShadow()
    }

    private var badge: String {
        if isDone { return "Done today · streak kept" }
        if travel != nil && isTraining { return "Travel mode" }
        return switch (day.kind, pivot?.variant) {
        case (.training, .trimmed?): "Adapted · low energy"
        case (.training, .minimum?): "Minimum session"
        case (.training, _): "Training day"
        case (.activeRecovery, _): "Active recovery"
        case (.rest, _): "Rest"
        }
    }

    private var title: String {
        switch day.kind {
        case .training:
            let base = day.focus?.title ?? "Training"
            return pivot?.variant == .minimum ? "Mobility + \(base.lowercased())" : base
        case .activeRecovery: return "Walk + mobility"
        case .rest: return "Rest day"
        }
    }

    private var meta: String {
        switch day.kind {
        case .training: "⏱ \(minutes) min    🔥 \(Burn.kcal(minutes: minutes, training: true)) kcal"
        case .activeRecovery: "⏱ \(minutes) min    🔥 \(Burn.kcal(minutes: minutes, training: false)) kcal"
        case .rest: "Recover"
        }
    }
}

// MARK: - Rows

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .textStyle(.headline)
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, Space.xxs / 2)
            .padding(.top, Space.xs - 2)
            .accessibilityAddTraits(.isHeader)
    }
}

struct ActionRow: View {
    enum Tint { case navy, copper, blue }

    let icon: String
    let tint: Tint
    let title: String
    let subtitle: String
    var badge: String?
    /// When set, the row shows the mock's pill switch in this state instead of a chevron.
    var toggle: Bool? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.sm + 1) {
                Image(systemName: icon)
                    .font(TextStyle.rowTitle.font)
                    .foregroundStyle(iconColor)
                    .frame(width: Size.iconTile, height: Size.iconTile)
                    .background(tileColor, in: RoundedRectangle(cornerRadius: Radius.xs))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Space.xxs) {
                    HStack(spacing: Space.xs - 2) {
                        Text(title)
                            .textStyle(.rowTitle)
                            .foregroundStyle(Palette.ink)
                        if let badge {
                            Text(badge)
                                .textStyle(.kicker)
                                .foregroundStyle(Palette.copperText)
                                .padding(.horizontal, Space.xs - 2)
                                .padding(.vertical, Space.xxs - 1)
                                .background(Palette.copperTint, in: Capsule())
                        }
                    }
                    Text(subtitle)
                        .textStyle(.caption)
                        .foregroundStyle(Palette.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let toggle {
                    MockSwitch(isOn: toggle)
                } else {
                    Image(systemName: "chevron.right")
                        .font(TextStyle.chip.font)
                        .foregroundStyle(Palette.inkMuted)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.md - 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(toggle.map { $0 ? "On" : "Off" } ?? "")
    }

    private var iconColor: Color {
        switch tint {
        case .navy: Palette.onInkFill
        case .copper: Palette.copperText
        case .blue: Palette.blueText
        }
    }

    private var tileColor: Color {
        switch tint {
        case .navy: Palette.inkFill
        case .copper: Palette.copperTint
        case .blue: Palette.blueTint
        }
    }
}

private struct TodayMealRow: View {
    enum Status { case eaten, upNext, planned }
    let meal: PlannedMeal
    let target: Int
    let status: Status

    var body: some View {
        HStack(spacing: Space.sm + 1) {
            Circle()
                .fill(Palette.page)
                .overlay { Image(meal.slot.illustration).resizable().scaledToFill() }
                .frame(width: Size.avatar + 10, height: Size.avatar + 10)
                .clipShape(Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.xxs + 2) {
                HStack(spacing: Space.xs - 1) {
                    Text("\(meal.slot.title) · \(meal.slot.clock)")
                        .textStyle(.micro)
                        .foregroundStyle(Palette.inkMuted)
                    Text(statusTitle)
                        .textStyle(.micro)
                        .foregroundStyle(statusFg)
                        .padding(.horizontal, Space.xs - 1)
                        .padding(.vertical, Space.xxs)
                        .background(statusBg, in: Capsule())
                }
                Text(meal.meal.name)
                    .textStyle(.rowTitle)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("P \(meal.proteinG)g · C \(meal.carbsG)g · F \(meal.fatG)g")
                    .textStyle(.micro)
                    .foregroundStyle(Palette.inkMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: Space.xs - 2) {
                Text("\(meal.kcal)").textStyle(.statValue).foregroundStyle(Palette.ink)
                Text("\(Int((Double(meal.kcal) / Double(max(1, target)) * 100).rounded()))% of goal")
                    .textStyle(.micro)
                    .foregroundStyle(Palette.copperText)
            }
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm + 1)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var statusTitle: String {
        switch status { case .eaten: "Logged"; case .upNext: "Up next"; case .planned: "Planned" }
    }
    private var statusFg: Color {
        switch status { case .eaten: Palette.blueText; case .upNext: Palette.copperText; case .planned: Palette.inkMuted }
    }
    private var statusBg: Color {
        switch status { case .eaten: Palette.blueTint; case .upNext: Palette.copperTint; case .planned: Palette.hairline }
    }
}

/// Rough session burn, as the mock estimates it: ~7.5 kcal/min lifting, ~4.5 kcal/min walking.
/// "2 of 4 meals eaten · 865 kcal left  See all ›" — opens Eat.
private struct FoodSummaryRow: View {
    let eatenCount: Int
    let mealCount: Int
    let kcalLeft: Int

    var body: some View {
        HStack(spacing: Space.xs) {
            Text("\(eatenCount) of \(mealCount) meals eaten · \(Formatters.kcal(kcalLeft)) kcal left")
                .textStyle(.caption)
                .foregroundStyle(Palette.inkMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("See all ›")
                .textStyle(.label)
                .foregroundStyle(Palette.copperText)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm + 1)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens Eat")
    }
}

enum Burn {
    static func kcal(minutes: Int, training: Bool) -> Int {
        Int((Double(minutes) * (training ? 7.5 : 4.5)).rounded())
    }
}

/// Shown while the plan comes from "Skip to the app".
private struct SampleBanner: View {
    let onBuild: () -> Void

    var body: some View {
        HStack(spacing: Space.sm) {
            VStack(alignment: .leading, spacing: Space.xxs) {
                Text("This is a sample plan").textStyle(.rowTitle).foregroundStyle(Palette.ink)
                Text("Built from example answers. Yours takes about three minutes.")
                    .textStyle(.caption).foregroundStyle(Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onBuild) {
                Text("Build mine")
                    .textStyle(.chip)
                    .foregroundStyle(Palette.onInkFill)
                    .padding(.horizontal, Space.md - 2)
                    .padding(.vertical, Space.sm - 2)
                    .background(Palette.inkFill, in: Capsule())
            }
            .buttonStyle(PressableStyle())
        }
        .padding(Space.md)
        .background(Palette.copperTint, in: RoundedRectangle(cornerRadius: Radius.md))
    }
}
