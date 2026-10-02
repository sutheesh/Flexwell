import SwiftUI
import SwiftData
import FlexFitEngine

/// Train: the week strip, the chosen day's session, one-tap swaps.
///
/// Always dark by design — the mock draws this tab on navy in both appearances.
/// This is the one screen that forces the scheme; don't copy the pattern elsewhere.
struct TrainView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Query private var profiles: [ProfileRecord]
    @Query private var logs: [DailyLog]
    @Query private var swaps: [ExerciseSwap]
    @Query private var painFlags: [PainFlag]
    @Query(sort: \WeeklyTargets.weekOf) private var weekly: [WeeklyTargets]
    @State private var selectedWeekday = TrainView.todayWeekday
    /// Which week the strip shows, relative to this one (-1 last week, 1 next week).
    @State private var weekOffset = 0
    @State private var mode: Mode = .plan
    /// The header ★ opens favourites from either Gym mode; on Exercises it toggles back to the body map.
    @State private var showsFavorites = false

    enum Mode: String, CaseIterable { case plan = "My plan", exercises = "Exercises" }

    static var todayWeekday: Int { (Calendar.current.component(.weekday, from: .now) + 5) % 7 }
    /// How far ahead the strip goes when the plan has no end date (maintaining weight).
    static let openEndedWeeksAhead = 12

    var body: some View {
        Group {
            if let record = profiles.first {
                content(record: record, currentWeek: TodayPlan.weekNumber(since: record.createdAt, now: .now))
            }
        }
        .environment(\.colorScheme, .dark)
    }

    private func content(record: ProfileRecord, currentWeek: Int) -> some View {
        let resolver = PlanResolver(record: record, swaps: swaps, logs: logs, painFlags: painFlags)
        let profile = resolver.profile
        // The plan runs from the week it started in to its last week (open-ended when maintaining).
        let totalWeeks = TargetCalculator.weeksToGoal(for: profile)
        let weeks = (1 - currentWeek)...max(0, totalWeeks.map { $0 - currentWeek } ?? Self.openEndedWeeksAhead)
        let weekNumber = currentWeek + weekOffset
        let planStart = Calendar.current.startOfDay(for: record.createdAt)
        let dates = weekDates(offset: weekOffset)
        let selectedDate = dates[selectedWeekday]
        let isToday = Calendar.current.isDateInToday(selectedDate)
        let day = resolver.week[selectedWeekday]
        let plan = resolver.session(forWeekday: selectedWeekday, on: selectedDate, applyPivot: isToday)
        let done = Set(resolver.log(for: selectedDate)?.completedExercises ?? [])

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: Space.sm) {
                    HeaderButton(name: profile.name,
                                 kicker: "Workout plan · week \(weekNumber)" + (totalWeeks.map { " of \($0)" } ?? ""),
                                 title: mode == .plan ? "Schedule" : (showsFavorites ? "Favourites" : "Exercises"),
                                 showsCart: false)
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if mode == .plan {
                                showsFavorites = true
                                mode = .exercises
                            } else {
                                showsFavorites.toggle()
                            }
                        }
                    } label: {
                        Image(systemName: showsFavorites ? "star.fill" : "star")
                            .font(TextStyle.headline.font)
                            .foregroundStyle(Palette.copper)
                            .frame(width: Size.avatar, height: Size.avatar)
                            .background(Palette.navyRaised, in: RoundedRectangle(cornerRadius: Radius.sm))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(mode == .plan || !showsFavorites ? "Show favourites" : "Show the body map")
                    .accessibilityAddTraits(showsFavorites && mode == .exercises ? .isSelected : [])
                }

                WeekSwitcher(dates: dates, offset: weekOffset, weekNumber: weekNumber,
                             canGoBack: weekOffset > weeks.lowerBound, canGoForward: weekOffset < weeks.upperBound,
                             onChange: { showWeek(weekOffset + $0, planStart: planStart) },
                             onThisWeek: { showWeek(0, planStart: planStart) })
                    .padding(.top, Space.sm)

                WeekStrip(week: resolver.week, dates: dates, firstDay: planStart,
                          cheatDays: Set(profile.cheatDays.activeWeekdays), selected: $selectedWeekday)
                    .padding(.top, Space.xs)
                    // Swipe the strip sideways for the previous or next week.
                    .simultaneousGesture(DragGesture(minimumDistance: 24).onEnded { drag in
                        guard abs(drag.translation.width) > abs(drag.translation.height) * 1.5 else { return }
                        let step = drag.translation.width < 0 ? 1 : -1
                        if weeks.contains(weekOffset + step) { showWeek(weekOffset + step, planStart: planStart) }
                    })

                SessionPanel(day: day, plan: plan, isToday: isToday, travel: resolver.travelKit(on: selectedDate),
                             onStart: { router.workoutDay = selectedDate },
                             onAdapt: { router.isAdaptPresented = true })
                    .padding(.top, Space.md - 2)

                // Below today's session: the plan for the chosen day, or the exercise library.
                GymSegmented(selection: $mode, options: Mode.allCases, title: \.rawValue)
                    .padding(.top, Space.md)

                if mode == .exercises {
                    ExerciseLibraryView(showsFavorites: $showsFavorites)
                        .padding(.top, Space.md)
                } else {

                if let plan, !plan.exercises.isEmpty {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Session plan")
                            .textStyle(.headline)
                            .foregroundStyle(Palette.onPanel)
                            .accessibilityAddTraits(.isHeader)
                        Spacer()
                        Text("\(plan.exercises.filter { done.contains($0.exerciseID) }.count)/\(plan.exercises.count) done")
                            .textStyle(.micro)
                            .foregroundStyle(Palette.onPanelMuted)
                    }
                    .padding(.horizontal, Space.xxs / 2)
                    .padding(.top, Space.xl - 2)
                    .padding(.bottom, Space.sm - 1)

                    VStack(spacing: 0) {
                        ForEach(Array(plan.exercises.enumerated()), id: \.element.exerciseID) { index, planned in
                            if let exercise = ExerciseLibrary.bundled[planned.exerciseID] {
                                ExerciseRow(
                                    index: index + 1,
                                    planned: planned,
                                    exercise: exercise,
                                    owned: resolver.equipment(on: selectedDate),
                                    isDone: done.contains(planned.exerciseID),
                                    wasSwapped: isSwapped(planned.exerciseID, on: selectedDate),
                                    onToggleDone: { toggleDone(planned.exerciseID, on: selectedDate) },
                                    onSwap: { router.sheet = .exerciseSwap(SwapRequest(originalID: exercise.id, day: selectedDate)) }
                                )
                            }
                        }
                    }
                    .background(Palette.navy, in: RoundedRectangle(cornerRadius: Radius.md))
                } else {
                    Text(restNote(for: day, kcal: MealPlanContext(profile: profile, targets: TargetsStore.current(weekly, profile: profile), swaps: []).calories(on: selectedDate)))
                        .textStyle(.body)
                        .foregroundStyle(Palette.onPanelMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Space.xl - 2)
                }

                WeekProgress(week: resolver.week, title: weekOffset == 0 ? "This week" : "Week \(weekNumber)",
                             today: weekOffset == 0 ? Self.todayWeekday : nil,
                             completed: Set((0..<7).filter { resolver.log(for: dates[$0])?.completedExercises.isEmpty == false }))
                    .padding(.top, Space.md - 2)
                }
            }
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.xs)
            .padding(.bottom, Space.xl)
            .readableColumn()
        }
        .overlay(alignment: .top) {
            Color.clear.frame(height: 0).background(Palette.navy.ignoresSafeArea(edges: .top))
        }
        .background(Palette.navy.ignoresSafeArea())
    }

    // MARK: Actions

    /// Shows another week, keeping the selected weekday (today's, back on this week), but never a day before
    /// the plan started.
    private func showWeek(_ offset: Int, planStart: Date) {
        withAnimation(.easeInOut(duration: 0.2)) {
            weekOffset = offset
            if offset == 0 { selectedWeekday = Self.todayWeekday }
            let dates = weekDates(offset: offset)
            if dates[selectedWeekday] < planStart,
               let first = Weekday.displayOrder.first(where: { dates[$0] >= planStart }) {
                selectedWeekday = first
            }
        }
    }

    private func toggleDone(_ id: String, on date: Date) {
        let log = DailyLog.forDay(date, in: modelContext)
        if let i = log.completedExercises.firstIndex(of: id) {
            log.completedExercises.remove(at: i)
        } else {
            log.completedExercises.append(id)
        }
        log.updatedAt = .now
        try? modelContext.save()
    }

    // MARK: Helpers

    /// The dates of the Sunday-to-Saturday week `offset` weeks from this one, indexed by weekday (0 = Monday).
    private func weekDates(offset: Int) -> [Date] {
        let cal = Calendar.current
        let thisSunday = TodayPlan.weekStart(.now)
        let sunday = cal.date(byAdding: .day, value: 7 * offset, to: thisSunday) ?? thisSunday
        return (0..<7).map { cal.date(byAdding: .day, value: ($0 + 1) % 7, to: sunday) ?? sunday }
    }

    private func isSwapped(_ id: String, on date: Date) -> Bool {
        let start = Calendar.current.startOfDay(for: date)
        return swaps.contains { $0.replacementID == id && ($0.day == nil || $0.day == start) }
    }

    private func restNote(for day: PlannedDay, kcal: Int) -> String {
        day.kind == .rest
            ? "Rest day. 7,000 easy steps, 10 minutes of stretching, and food at \(Formatters.kcal(kcal)) kcal — \(CalorieWeek.restDayReduction) lower than training days."
            : "25-minute brisk walk plus hips and T-spine mobility. Keeps the legs fresh for tomorrow."
    }
}

// MARK: - Header

struct ScreenHeader: View {
    let initial: String
    let kicker: String
    let title: String
    var showsCart = true

    var body: some View {
        HStack(spacing: Space.sm) {
            Text(String(initial.prefix(1)).uppercased())
                .textStyle(.button)
                .foregroundStyle(Palette.navy)
                .frame(width: Size.avatar, height: Size.avatar)
                .background(Palette.copper, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.xxs + 1) {
                Text(kicker)
                    .textStyle(.caption)
                    .foregroundStyle(Palette.inkMuted)
                Text(title)
                    .textStyle(.title2)
                    .foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, Space.xs)
    }
}

/// Avatar + title (opens Settings) with the mock's cart button (opens Groceries) on the right.
struct TabHeader: View {
    let name: String
    let kicker: String
    let title: String
    /// Groceries live with food: Eat and Profile show the cart, Gym and Today don't.
    var showsCart = true
    @Environment(AppRouter.self) private var router

    var body: some View {
        HStack(spacing: Space.sm) {
            Button { router.tab = .profile } label: {
                ScreenHeader(initial: name, kicker: kicker, title: title)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens your profile")
            if showsCart { CartButton() }
        }
    }
}

// MARK: - Week strip

private struct WeekStrip: View {
    let week: [PlannedDay]
    /// Indexed by weekday, 0 = Monday.
    let dates: [Date]
    /// Days before the plan started can't be picked.
    let firstDay: Date
    /// Weekdays (0 = Monday) that are cheat days.
    var cheatDays: Set<Int> = []
    @Binding var selected: Int

    var body: some View {
        HStack(spacing: Space.xxs + 1) {
            ForEach(Weekday.displayOrder, id: \.self) { i in
                let isSelected = i == selected
                let beforePlan = dates[i] < firstDay
                Button { selected = i } label: {
                    VStack(spacing: Space.xxs + 1) {
                        Text(Weekday.shortName(i))
                            .textStyle(.micro)
                            .opacity(0.75)
                        Text(dates[i].formatted(.dateTime.day()))
                            .textStyle(.statValue)
                        Circle()
                            .fill(dotColor(week[i], selected: isSelected))
                            .frame(width: Size.dot - 1, height: Size.dot - 1)
                    }
                    .foregroundStyle(isSelected ? Palette.navy : Palette.onPanel)
                    .frame(maxWidth: .infinity, minHeight: Size.row + 12)
                    .overlay(alignment: .topTrailing) {
                        if cheatDays.contains(i) {
                            Image(systemName: "birthday.cake.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(isSelected ? Palette.navy : Palette.copper)
                                .padding(Space.xxs)
                                .accessibilityHidden(true)
                        }
                    }
                    .background(isSelected ? Palette.ice : Palette.navy, in: RoundedRectangle(cornerRadius: Radius.sm))
                    .contentShape(RoundedRectangle(cornerRadius: Radius.sm))
                }
                .buttonStyle(.plain)
                .disabled(beforePlan)
                .opacity(beforePlan ? 0.35 : 1)
                .accessibilityLabel("\(dates[i].formatted(.dateTime.weekday(.wide).day())), \(beforePlan ? "before your plan" : label(week[i]))\(cheatDays.contains(i) ? ", cheat day" : "")")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    private func dotColor(_ day: PlannedDay, selected: Bool) -> Color {
        switch day.kind {
        case .training: selected ? Palette.navy : Palette.copper
        case .activeRecovery: selected ? Palette.navy.opacity(0.3) : Palette.onPanel.opacity(0.3)
        case .rest: .clear
        }
    }

    private func label(_ day: PlannedDay) -> String {
        switch day.kind {
        case .training: day.focus?.title ?? "Training"
        case .activeRecovery: "Walk and mobility"
        case .rest: "Rest"
        }
    }
}

// MARK: - Week switcher

/// Previous / next week around the week's dates; tapping the dates goes back to this week.
private struct WeekSwitcher: View {
    /// Indexed by weekday, 0 = Monday.
    let dates: [Date]
    let offset: Int
    let weekNumber: Int
    let canGoBack: Bool
    let canGoForward: Bool
    let onChange: (Int) -> Void
    let onThisWeek: () -> Void

    var body: some View {
        HStack(spacing: Space.sm) {
            arrow("chevron.left", enabled: canGoBack, label: "Previous week") { onChange(-1) }
            Spacer(minLength: 0)
            Button(action: onThisWeek) {
                VStack(spacing: Space.xxs / 2) {
                    Text(range)
                        .textStyle(.label)
                        .foregroundStyle(Palette.onPanel)
                    Text(caption)
                        .textStyle(.micro)
                        .foregroundStyle(offset == 0 ? Palette.copper : Palette.onPanelMuted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(offset == 0)
            .accessibilityLabel("\(caption), \(range)")
            .accessibilityHint(offset == 0 ? "" : "Goes back to this week")
            Spacer(minLength: 0)
            arrow("chevron.right", enabled: canGoForward, label: "Next week") { onChange(1) }
        }
    }

    /// "Sep 21 – 27", or "Sep 28 – Oct 4" across months.
    private var range: String {
        let sunday = dates[6], saturday = dates[5]
        let sameMonth = Calendar.current.isDate(sunday, equalTo: saturday, toGranularity: .month)
        let end = sameMonth ? saturday.formatted(.dateTime.day()) : saturday.formatted(.dateTime.month(.abbreviated).day())
        return "\(sunday.formatted(.dateTime.month(.abbreviated).day())) – \(end)"
    }

    private var caption: String {
        switch offset {
        case 0: "This week · week \(weekNumber)"
        case -1: "Last week · week \(weekNumber)"
        case 1: "Next week · week \(weekNumber)"
        default: "Week \(weekNumber)"
        }
    }

    private func arrow(_ symbol: String, enabled: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(TextStyle.label.font)
                .foregroundStyle(Palette.onPanel)
                .frame(width: Size.button, height: Size.button)
                .background(Palette.navyRaised, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .accessibilityLabel(label)
    }
}

// MARK: - Session panel

/// Navy panel with the lift illustration on the right. Fixed-dark content.
private struct SessionPanel: View {
    let day: PlannedDay
    let plan: SessionPlan?
    let isToday: Bool
    let travel: TravelKit?
    let onStart: () -> Void
    let onAdapt: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: Space.xs - 2) {
                    Circle().fill(Palette.ice).frame(width: Size.dot, height: Size.dot)
                    Text(tag)
                        .textStyle(.micro)
                        .foregroundStyle(Palette.ice)
                }
                Text(title)
                    .textStyle(.title2)
                    .foregroundStyle(Palette.onPanel)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Space.sm - 2)
                    .accessibilityAddTraits(.isHeader)
                if day.kind == .training, let focus = day.focus {
                    Text(focus.summary)
                        .textStyle(.caption)
                        .foregroundStyle(Palette.onPanelMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Space.xs - 2)
                }
                HStack(spacing: Space.sm) {
                    ForEach(meta, id: \.self) { Text($0) }
                }
                .textStyle(.micro)
                .foregroundStyle(Palette.onPanelMuted)
                .padding(.top, Space.sm - 2)
                if isToday, day.kind == .training {
                    Button(action: onAdapt) {
                        Text("Adapt session ›")
                            .textStyle(.label)
                            .foregroundStyle(Palette.navy)
                            .padding(.horizontal, Space.md - 1)
                            .padding(.vertical, Space.sm - 1)
                            .background(Palette.ice, in: Capsule())
                    }
                    .buttonStyle(PressableStyle())
                    .padding(.top, Space.md - 2)
                }
            }
            .padding(Space.md + 2)
            // Text stays clear of the picture on the right 46% (the mock's image slot).
            .containerRelativeFrame(.horizontal, alignment: .leading) { width, _ in (width - Space.lg * 2) * 0.58 }
            Spacer(minLength: 0)
        }
        // The mock's image slot: the right 46% of the card, faded into navy from the left.
        .background(alignment: .trailing) {
            GeometryReader { geo in
                Image(day.kind == .training ? "Illustration-lift" : "Illustration-walk")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width * 0.46, height: geo.size.height)
                    .clipped()
                    .overlay {
                        LinearGradient(colors: [Palette.navy, Palette.navy.opacity(0)], startPoint: .leading, endPoint: .init(x: 0.6, y: 0.5))
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .accessibilityHidden(true)
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(Palette.navy, in: RoundedRectangle(cornerRadius: Radius.lg))
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        // A hairline just lighter than the navy page, so the card reads as a card.
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Palette.onPanel.opacity(0.08)))
        .accessibilityElement(children: .contain)
    }

    private var tag: String {
        if travel != nil && day.kind == .training { return isToday ? "Today’s focus · Travel mode" : "Travel mode" }
        let base: String = switch plan?.variant {
        case .trimmed?: "Adapted · low energy"
        case .minimum?: "Minimum session"
        default: day.kind == .training ? "Training day" : day.kind == .rest ? "Rest" : "Active recovery"
        }
        return isToday ? "Today’s focus · \(base)" : base
    }

    private var title: String {
        switch day.kind {
        case .training: day.focus?.title ?? "Training"
        case .activeRecovery: "Walk + mobility"
        case .rest: "Rest day"
        }
    }

    /// "🔥 338 kcal", "⏱ 45 min" — the mock's two spans.
    private var meta: [String] {
        if let plan {
            return ["🔥 \(Burn.kcal(minutes: plan.minutes, training: true)) kcal", "⏱ \(plan.minutes) min"]
        }
        return day.minutes > 0
            ? ["🔥 \(Burn.kcal(minutes: day.minutes, training: false)) kcal", "⏱ \(day.minutes) min"]
            : ["🔥 0 kcal", "⏱ Steps only"]
    }
}

// MARK: - Exercise row

private struct ExerciseRow: View {
    let index: Int
    let planned: PlannedExercise
    let exercise: Exercise
    let owned: Set<Equipment>
    let isDone: Bool
    let wasSwapped: Bool
    let onToggleDone: () -> Void
    let onSwap: () -> Void

    var body: some View {
        HStack(spacing: Space.sm) {
            Button(action: onToggleDone) {
                Text(isDone ? "✓" : "\(index)")
                    .textStyle(.label)
                    .foregroundStyle(isDone ? Palette.navy : Palette.ice)
                    .frame(width: Size.checkRing + 8, height: Size.checkRing + 8)
                    .background(isDone ? Palette.ice : Palette.ice.opacity(0.14), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isDone ? "Mark \(exercise.name) not done" : "Mark \(exercise.name) done")

            NavigationLink(value: GymRoute.exercise(exercise.id)) {
            VStack(alignment: .leading, spacing: 0) {
                Text(exercise.name)
                    .textStyle(.rowTitle)
                    .foregroundStyle(isDone ? Palette.onPanelMuted : Palette.onPanel)
                    .strikethrough(isDone, color: Palette.onPanelMuted)
                Text(ExerciseCopy.prescription(planned, includeRPE: false) + " · " + ExerciseCopy.equipment(exercise, owned: owned))
                    .textStyle(.caption)
                    .foregroundStyle(Palette.onPanelMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Space.xxs + 1)
                if wasSwapped {
                    Text("↺ Swapped · same muscle group")
                        .textStyle(.micro)
                        .foregroundStyle(Palette.ice)
                        .padding(.top, Space.xs - 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens how to do it and your history")

            Button(action: onSwap) {
                Text("Swap")
                    .textStyle(.micro)
                    .foregroundStyle(Palette.onPanel)
                    .padding(.horizontal, Space.sm)
                    .padding(.vertical, Space.xs + 1)
                    .overlay(Capsule().strokeBorder(Palette.onPanelOutline))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Swap \(exercise.name)")
        }
        .padding(.horizontal, Space.md - 2)
        .padding(.vertical, Space.sm + 1)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.onPanelHairline.opacity(0.6)).frame(height: 1)
        }
    }
}

enum ExerciseCopy {
    static func prescription(_ p: PlannedExercise, includeRPE: Bool = true) -> String {
        let target = p.targetLow == p.targetHigh ? "\(p.targetLow)" : "\(p.targetLow)–\(p.targetHigh)"
        let unit = p.measure == .seconds ? " s" : ""
        var text = "\(p.sets) × \(target)\(unit)"
        if let tempo = p.tempoNote { text += ", \(tempo)" }
        return includeRPE ? text + " · RPE \(p.rpeCap)" : text
    }

    /// The implements this user will actually use for it: "Dumbbells + Flat bench", or "Bodyweight".
    static func equipment(_ exercise: Exercise, owned: Set<Equipment>) -> String {
        let picks = exercise.equipment.compactMap { group in group.first { owned.contains($0) } ?? group.first }
        return picks.isEmpty ? "Bodyweight" : picks.map(\.title).joined(separator: " + ")
    }
}

// MARK: - Week progress

private struct WeekProgress: View {
    let week: [PlannedDay]
    let title: String
    /// Today's weekday, when the week shown is this one.
    let today: Int?
    /// Weekdays with at least one exercise ticked off.
    let completed: Set<Int>

    var body: some View {
        let sessions = week.filter { $0.kind == .training }.count
        let done = (0..<7).filter { week[$0].kind == .training && completed.contains($0) }.count
        VStack(alignment: .leading, spacing: Space.sm + 1) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .textStyle(.label)
                    .foregroundStyle(Palette.onPanel)
                Spacer()
                Text("\(done) of \(sessions) sessions")
                    .textStyle(.micro)
                    .foregroundStyle(Palette.ice)
            }
            HStack(spacing: Space.xxs) {
                ForEach(Weekday.displayOrder, id: \.self) { i in
                    Capsule()
                        .fill(fill(for: i))
                        .frame(height: Size.dot)
                }
            }
            .accessibilityHidden(true)
        }
        .padding(.horizontal, Space.md + 2)
        .padding(.vertical, Space.md)
        .background(Palette.navy, in: RoundedRectangle(cornerRadius: Radius.md))
    }

    /// Mock: done sessions ice, today ice at 45%, other sessions white 14%, non-session days white 5%.
    private func fill(for i: Int) -> Color {
        let isSession = week[i].kind == .training
        if isSession && completed.contains(i) { return Palette.ice }
        if i == today { return Palette.ice.opacity(0.45) }
        return isSession ? Palette.onPanelTrack : Palette.onPanelHairline.opacity(0.5)
    }
}
