import SwiftUI
import SwiftData
import WidgetKit
import FlexFitEngine

/// Today: the day's targets and protein check, the energy check-in, and the session it shapes.
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
        let totalWeeks = TargetCalculator.weeksToGoal(for: profile)
        let streak = Streak.weeks(sessionsPerWeek: sessionsPerWeek(now: now), planned: profile.trainingDays)
        let doneToday = sessions.contains { Calendar.current.isDate($0.day, inSameDayAs: now) }
        let mealContext = MealPlanContext(profile: profile, targets: targets, swaps: ingredientSwaps)
        let meals = mealContext.meals(on: now)
        let dayTarget = mealContext.calories(on: now)
        let eatenIdx = Set(todayLog?.eatenMeals ?? [])
        let eatenMeals = meals.filter { eatenIdx.contains($0.index) }
        // An eating-out order counts toward today (logged from Restaurant mode in place of dinner).
        let eaten = (kcal: eatenMeals.reduce(0) { $0 + $1.kcal } + (todayLog?.eatenOutKcal ?? 0),
                     protein: eatenMeals.reduce(0) { $0 + $1.proteinG } + (todayLog?.eatenOutProteinG ?? 0),
                     carbs: eatenMeals.reduce(0) { $0 + $1.carbsG }, fat: eatenMeals.reduce(0) { $0 + $1.fatG })
        let groceryCount = GroceryList.build(from: (0..<7).compactMap {
            Calendar.current.date(byAdding: .day, value: $0, to: Week.start(of: now)).map { mealContext.meals(on: $0) }
        }).count
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
                          kicker: "\(now.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))) · week \(week)",
                          title: profile.name.isEmpty ? "Hi there" : "Hi \(profile.name)")

                if record.isSample {
                    SampleBanner { startOver() }
                }

                TargetsCard(
                    targets: DailyTargets(calories: dayTarget, proteinG: targets.proteinG, carbsG: targets.carbsG,
                                          fatG: targets.fatG, expenditure: targets.expenditure, floorApplied: targets.floorApplied),
                    date: now,
                    weekLabel: streak > 0 ? "🔥 \(streak)-week streak"
                        : (totalWeeks.map { "Week \(min(week, $0)) of \($0)" } ?? "Week \(week)"),
                    eaten: eaten,
                    protein: todayLog?.proteinValue,
                    onProtein: { answer in setProtein(answer, on: now) }
                )

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
                            onAdapt: { router.isAdaptPresented = true })

                if !meals.isEmpty {
                    HStack(alignment: .firstTextBaseline) {
                        SectionHeader(title: "Today's food")
                        Spacer()
                        Button("See all") { router.tab = .eat }
                            .textStyle(.label)
                            .foregroundStyle(Palette.copperText)
                    }
                    CardList {
                        if let out = todayLog?.eatenOutName {
                            EatingOutRow(name: out, kcal: todayLog?.eatenOutKcal ?? 0, protein: todayLog?.eatenOutProteinG ?? 0) {
                                clearEatingOut(now)
                            }
                        }
                        ForEach(meals.filter { todayLog?.eatenOutName == nil || $0.slot != .dinner }) { meal in
                            Button { mealDetail = MealSelection(date: now, planned: meal) } label: {
                                TodayMealRow(meal: meal, target: dayTarget,
                                             status: eatenIdx.contains(meal.index) ? .eaten : (meal.id == next?.id ? .upNext : .planned))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                SectionHeader(title: "Quick adjustments")
                CardList {
                    let noGymOn = record.activeTravelKit(now: now) == TravelKit.none
                    ActionRow(icon: "house", tint: .navy, title: "Can’t make it to the gym",
                              subtitle: noGymOn ? "On — today is a zero-equipment session" : "Converts today to zero equipment",
                              badge: entitlements.canUseTravelMode ? nil : "Pro", toggle: noGymOn) {
                        toggleNoGym(record, now: now)
                    }
                    ActionRow(icon: "fork.knife", tint: .copper, title: "Eating out tonight",
                              subtitle: "3 safe orders for \(Formatters.kcal(max(0, dayTarget - eaten.kcal))) kcal left") {
                        router.isRestaurantPresented = true
                    }
                    ActionRow(icon: "checklist", tint: .blue, title: "Grocery list",
                              subtitle: "\(groceryCount) items for this week’s meals") { router.isGroceryPresented = true }
                    ActionRow(icon: "airplane", tint: .navy, title: "Travel mode",
                              subtitle: record.activeTravelKit(now: now).map { "On · \($0.title.lowercased())" }
                                  ?? "Same muscles with bodyweight or bands",
                              badge: entitlements.canUseTravelMode ? nil : "Pro") {
                        if entitlements.canUseTravelMode { router.isAdaptPresented = true } else { router.paywall = .travel }
                    }
                    ActionRow(icon: "scalemass", tint: .blue, title: "Weekly weigh-in",
                              subtitle: "Keeps your targets honest") { router.tab = .eat }
                }
            }
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.xs)
            .padding(.bottom, Space.xl)
            .readableColumn()
        }
        .statusBarBackdrop()
        .pageBackground()
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
    private func toggleNoGym(_ record: ProfileRecord, now: Date) {
        guard entitlements.canUseTravelMode else { router.paywall = .travel; return }
        if record.activeTravelKit(now: now) == TravelKit.none {
            record.travelKit = nil
            record.travelUntil = nil
            router.toast("Back to your normal session.")
        } else {
            record.travelKit = TravelKit.none.rawValue
            record.travelUntil = Calendar.current.date(bySettingHour: 23, minute: 59, second: 0, of: now)
            router.toast("No-gym mode on — zero-equipment session, same muscles.")
        }
        try? modelContext.save()
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

    private func clearEatingOut(_ date: Date) {
        let log = DailyLog.forDay(date, in: modelContext)
        log.eatenOutName = nil
        log.eatenOutKcal = 0
        log.eatenOutProteinG = 0
        try? modelContext.save()
        router.toast("Back to your planned dinner.")
    }

    /// "Build my plan" from a sample: clear the sample so onboarding starts.
    private func startOver() {
        for model in [ProfileRecord.self, DailyLog.self, ExerciseSwap.self, SessionLog.self, WeighIn.self, WeeklyTargets.self,
                      PainFlag.self, IngredientSwapRecord.self, GroceryCheck.self, PantryItem.self, SavedMeal.self] as [any PersistentModel.Type] {
            try? modelContext.delete(model: model)
        }
        try? modelContext.save()
    }

    private func sessionsPerWeek(now: Date) -> [Int] {
        let thisWeek = Week.start(of: now)
        var counts = Array(repeating: 0, count: 53)
        for s in sessions {
            let weeksAgo = (Calendar.current.dateComponents([.day], from: Week.start(of: s.day), to: thisWeek).day ?? 0) / 7
            if (0..<counts.count).contains(weeksAgo) { counts[weeksAgo] += 1 }
        }
        return counts
    }

    private func setEnergy(_ energy: Energy?, on date: Date) {
        withAnimation(.easeInOut(duration: 0.2)) {
            DailyLog.forDay(date, in: modelContext).energyValue = energy
        }
        try? modelContext.save()
    }

    private func setProtein(_ answer: ProteinCheck?, on date: Date) {
        withAnimation(.easeInOut(duration: 0.2)) {
            DailyLog.forDay(date, in: modelContext).proteinValue = answer
        }
        try? modelContext.save()
    }
}

enum TodayPlan {
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

// MARK: - Targets + protein check

/// Navy panel: dark in both appearances, so its content uses fixed tokens.
/// The mock's calorie arc: 13 segments filling as meals are marked eaten.
private struct TargetsCard: View {
    let targets: DailyTargets
    let date: Date
    let weekLabel: String
    let eaten: (kcal: Int, protein: Int, carbs: Int, fat: Int)
    let protein: ProteinCheck?
    let onProtein: (ProteinCheck?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .textStyle(.micro)
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
                .overlay(alignment: .bottom) {
                    VStack(spacing: Space.xs - 1) {
                        Image(systemName: "bolt.fill")
                            .font(TextStyle.label.font)
                            .foregroundStyle(Palette.copper)
                        Text("\(Formatters.kcal(eaten.kcal)) kcal")
                            .textStyle(.metric)
                            .foregroundStyle(Palette.onPanel)
                        Text("Goal \(Formatters.kcal(targets.calories)) kcal")
                            .textStyle(.micro)
                            .foregroundStyle(Palette.copper)
                    }
                    .padding(.bottom, Space.xs)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(eaten.kcal) of \(targets.calories) kilocalories eaten today")
                .padding(.top, Space.xxs)

            HStack(spacing: 0) {
                MacroStat(label: "Protein", eaten: eaten.protein, target: targets.proteinG, fill: Palette.ice)
                MacroStat(label: "Carbs", eaten: eaten.carbs, target: targets.carbsG, fill: Palette.copper)
                MacroStat(label: "Fat", eaten: eaten.fat, target: targets.fatG, fill: Palette.sand)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, Space.md - 1)
            .overlay(alignment: .top) { Rectangle().fill(Palette.onPanelHairline).frame(height: 1) }

            ProteinCheckRow(grams: targets.proteinG, answer: protein, onAnswer: onProtein)
                .padding(.top, Space.md)
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.md + 2)
        .padding(.bottom, Space.lg)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Palette.panelEdge))
    }
}

/// 13 rounded segments on a 204° arc, as drawn in the mock.
private struct CalorieArc: View {
    let fraction: Double
    private let segments = 13

    var body: some View {
        let filled = Int((min(1, max(0, fraction)) * Double(segments)).rounded())
        ZStack {
            ForEach(0..<segments, id: \.self) { i in
                Capsule()
                    .fill(i < filled ? Palette.copper : Palette.onPanelHairline)
                    .frame(width: Size.segment.width, height: Size.segment.height)
                    .offset(y: -Size.arcRadius)
                    .rotationEffect(.degrees(-102 + Double(i) * 204 / Double(segments - 1)))
            }
        }
        .frame(width: Size.arcRadius * 2 + Size.segment.width, height: Size.arcRadius + Size.segment.height)
        .offset(y: Size.arcRadius / 2 - Space.xs)
        .frame(maxWidth: .infinity)
        .frame(height: Size.arcRadius * 1.3)
        .clipped()
    }
}

private struct MacroStat: View {
    let label: String
    let eaten: Int
    let target: Int
    let fill: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(label)
                .textStyle(.micro)
                .foregroundStyle(Palette.onPanelMuted)
            Text("\(eaten) / \(target)g")
                .textStyle(.label)
                .foregroundStyle(Palette.onPanel)
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
        .padding(.trailing, Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct ProteinCheckRow: View {
    let grams: Int
    let answer: ProteinCheck?
    let onAnswer: (ProteinCheck?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm - 2) {
            Text(answer == nil ? "Did you hit roughly \(grams) g of protein today?" : "Protein logged for today")
                .textStyle(.caption)
                .foregroundStyle(Palette.onPanel)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Space.xs - 2) {
                ForEach(ProteinCheck.allCases, id: \.self) { option in
                    let selected = answer == option
                    Button {
                        onAnswer(selected ? nil : option)
                    } label: {
                        Text(option.title)
                            .textStyle(.chip)
                            .lineLimit(1)
                            .foregroundStyle(selected ? Palette.navy : Palette.onPanel)
                            .frame(maxWidth: .infinity, minHeight: Size.control - 4)
                            .background(selected ? Palette.ice : Color.clear, in: Capsule())
                            .overlay(Capsule().strokeBorder(selected ? Color.clear : Palette.onPanelOutline))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Protein: \(option.title)")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
        .padding(Space.sm)
        .background(Palette.onPanelHairline, in: RoundedRectangle(cornerRadius: Radius.md))
    }
}

extension ProteinCheck {
    var title: String {
        switch self {
        case .yes: "Yes"
        case .close: "Close"
        case .no: "No"
        }
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
                    .foregroundStyle(Palette.onInkFill)
                    .frame(width: Size.checkRing + 8, height: Size.checkRing + 8)
                    .background(Palette.inkFill, in: Circle())
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
private struct SessionCard: View {
    let day: PlannedDay
    let pivot: PivotResult?
    let plan: SessionPlan?
    let travel: TravelKit?
    let isDone: Bool
    /// On-device (or template) intro for today's session.
    var intro: String?
    let onStart: () -> Void
    let onAdapt: () -> Void

    private var isTraining: Bool { day.kind == .training }
    private var minutes: Int { plan?.minutes ?? pivot?.minutes ?? day.minutes }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .aspectRatio(2.05, contentMode: .fit)
                .overlay {
                    Image(isTraining ? "Illustration-lift" : "Illustration-walk")
                        .resizable()
                        .scaledToFill()
                }
                .overlay {
                    LinearGradient(
                        stops: [
                            // Stronger than the mock's fade: white titles cross the drawn art.
                            .init(color: Palette.navy.opacity(0.96), location: 0),
                            .init(color: Palette.navy.opacity(0.85), location: 0.55),
                            .init(color: Palette.navy.opacity(0.25), location: 1),
                        ],
                        startPoint: .leading, endPoint: .trailing
                    )
                }
                .overlay(alignment: .topLeading) { summary }
                .background(Palette.panelRaised)
                .clipped()

            if isTraining {
                HStack(spacing: Space.xs + 1) {
                    Button(action: onStart) {
                        Text(isDone ? "Log another" : "Start workout")
                            .textStyle(.button)
                            .foregroundStyle(Palette.navy)
                            .frame(maxWidth: .infinity, minHeight: Size.button)
                            .background(Palette.ice, in: Capsule())
                    }
                    .buttonStyle(PressableStyle())
                    Button(action: onAdapt) {
                        Text("Adapt")
                            .textStyle(.chip)
                            .foregroundStyle(Palette.onPanel)
                            .padding(.horizontal, Space.md)
                            .frame(minHeight: Size.button)
                            .overlay(Capsule().strokeBorder(Palette.onPanelOutline))
                    }
                    .buttonStyle(PressableStyle())
                }
                .padding(.horizontal, Space.md)
                .padding(.top, Space.md - 2)
            }

            Text(intro ?? EnergyCopy.sessionNote(day: day, pivot: pivot))
                .textStyle(.caption)
                .foregroundStyle(Palette.onPanelMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Space.md)
                .padding(.top, isTraining ? Space.sm : Space.md)
                .padding(.bottom, Space.md - 2)
        }
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: Radius.lg))
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Palette.panelEdge))
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Space.xs - 2) {
                Circle().fill(Palette.ice).frame(width: Size.dot, height: Size.dot)
                Text(badge)
                    .textStyle(.micro)
                    .foregroundStyle(Palette.ice)
            }
            .padding(.horizontal, Space.sm - 2)
            .padding(.vertical, Space.xs - 2)
            .background(Palette.ice.opacity(0.16), in: Capsule())

            Text(title)
                .textStyle(.title2)
                .foregroundStyle(Palette.onPanel)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Space.sm)
                .accessibilityAddTraits(.isHeader)

            Text(meta)
                .textStyle(.micro)
                .foregroundStyle(Palette.onPanelMuted)
                .padding(.top, Space.sm - 2)
        }
        .padding(Space.md + 2)
        .frame(maxWidth: Size.panelTextWidth, alignment: .leading)
        .accessibilityElement(children: .combine)
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
        case .training: "🔥 \(Burn.kcal(minutes: minutes, training: true)) kcal · ⏱ \(minutes) min · RPE ≤ \(pivot?.rpeCap ?? 8)"
        case .activeRecovery: "🔥 \(Burn.kcal(minutes: minutes, training: false)) kcal · ⏱ \(minutes) min"
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

/// Tonight's restaurant order, logged in place of dinner.
private struct EatingOutRow: View {
    let name: String
    let kcal: Int
    let protein: Int
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: Space.sm + 1) {
            Image(systemName: "fork.knife")
                .font(TextStyle.rowTitle.font)
                .foregroundStyle(Palette.copperText)
                .frame(width: Size.avatar + 10, height: Size.avatar + 10)
                .background(Palette.copperTint, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.xxs + 2) {
                HStack(spacing: Space.xs - 1) {
                    Text("Dinner · eating out").textStyle(.micro).foregroundStyle(Palette.inkMuted)
                    Text("Logged").textStyle(.micro).foregroundStyle(Palette.blueText)
                        .padding(.horizontal, Space.xs - 1).padding(.vertical, Space.xxs)
                        .background(Palette.blueTint, in: Capsule())
                }
                Text(name).textStyle(.rowTitle).foregroundStyle(Palette.ink).fixedSize(horizontal: false, vertical: true)
                Text("\(protein)g protein").textStyle(.micro).foregroundStyle(Palette.inkMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: Space.xs - 2) {
                Text("\(kcal)").textStyle(.statValue).foregroundStyle(Palette.ink)
                Button("Undo", action: onUndo).textStyle(.micro).foregroundStyle(Palette.copperText)
            }
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm + 1)
    }
}
