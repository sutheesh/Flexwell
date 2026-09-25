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
    @State private var swapTarget: SwapTarget?

    struct SwapTarget: Identifiable {
        let exercise: Exercise
        var id: String { exercise.id }
    }

    static var todayWeekday: Int { (Calendar.current.component(.weekday, from: .now) + 5) % 7 }

    var body: some View {
        Group {
            if let record = profiles.first {
                content(record: record, week: TodayPlan.weekNumber(since: record.createdAt, now: .now))
            }
        }
        .environment(\.colorScheme, .dark)
    }

    private func content(record: ProfileRecord, week weekNumber: Int) -> some View {
        let resolver = PlanResolver(record: record, swaps: swaps, logs: logs, painFlags: painFlags)
        let profile = resolver.profile
        let dates = weekDates()
        let selectedDate = dates[selectedWeekday]
        let isToday = selectedWeekday == Self.todayWeekday
        let day = resolver.week[selectedWeekday]
        let plan = resolver.session(forWeekday: selectedWeekday, on: selectedDate, applyPivot: isToday)
        let done = Set(resolver.log(for: selectedDate)?.completedExercises ?? [])

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HeaderButton(name: profile.name, kicker: "Workout plan · week \(weekNumber)", title: "Schedule")

                WeekStrip(week: resolver.week, dates: dates, selected: $selectedWeekday)
                    .padding(.top, Space.sm)

                SessionPanel(day: day, plan: plan, isToday: isToday, travel: resolver.travelKit(on: selectedDate),
                             onStart: { router.workoutDay = selectedDate },
                             onAdapt: { router.isAdaptPresented = true })
                    .padding(.top, Space.md - 2)

                if let plan, !plan.exercises.isEmpty {
                    HStack(alignment: .firstTextBaseline) {
                        SectionHeader(title: "Session plan")
                        Spacer()
                        Text("\(plan.exercises.filter { done.contains($0.exerciseID) }.count) done")
                            .textStyle(.micro)
                            .foregroundStyle(Palette.inkMuted)
                    }
                    .padding(.top, Space.xl - 2)
                    .padding(.bottom, Space.sm - 1)

                    CardList {
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
                                    onSwap: { swapTarget = SwapTarget(exercise: exercise) }
                                )
                            }
                        }
                    }
                } else {
                    Text(restNote(for: day, kcal: MealPlanContext.calories(base: TargetsStore.current(weekly, profile: profile).calories, kind: day.kind)))
                        .textStyle(.body)
                        .foregroundStyle(Palette.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Space.xl - 2)
                }

                WeekProgress(week: resolver.week, today: Self.todayWeekday,
                             completed: Set((0..<7).filter { resolver.log(for: dates[$0])?.completedExercises.isEmpty == false }))
                    .padding(.top, Space.md - 2)
            }
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.xs)
            .padding(.bottom, Space.xl)
            .readableColumn()
        }
        .statusBarBackdrop()
        .pageBackground()
        .sheet(item: $swapTarget) { target in
            SwapSheet(
                exercise: target.exercise,
                profile: profile,
                equipment: resolver.equipment(on: selectedDate),
                history: resolver.history,
                usedThisWeek: resolver.usedThisWeek(on: selectedDate),
                onChoose: { replacement, scope in
                    saveSwap(original: target.exercise.id, replacement: replacement.id, scope: scope, on: selectedDate)
                }
            )
        }
    }

    // MARK: Actions

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

    private func saveSwap(original: String, replacement: String, scope: SwapScope, on date: Date) {
        modelContext.insert(ExerciseSwap(
            day: scope == .today ? Calendar.current.startOfDay(for: date) : nil,
            originalID: original,
            replacementID: replacement
        ))
        try? modelContext.save()
        swapTarget = nil
        router.toast("Swapped in \(ExerciseLibrary.bundled[replacement]?.name ?? "the alternative").")
    }

    // MARK: Helpers

    private func weekDates() -> [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let monday = cal.date(byAdding: .day, value: -Self.todayWeekday, to: today) ?? today
        return (0..<7).map { cal.date(byAdding: .day, value: $0, to: monday) ?? monday }
    }

    private func isSwapped(_ id: String, on date: Date) -> Bool {
        let start = Calendar.current.startOfDay(for: date)
        return swaps.contains { $0.replacementID == id && ($0.day == nil || $0.day == start) }
    }

    private func restNote(for day: PlannedDay, kcal: Int) -> String {
        day.kind == .rest
            ? "Rest day. 7,000 easy steps, 10 minutes of stretching, and food at \(Formatters.kcal(kcal)) kcal — \(MealPlanContext.restDayReduction) lower than training days."
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
    @Environment(AppRouter.self) private var router

    var body: some View {
        HStack(spacing: Space.sm) {
            Button { router.isSettingsPresented = true } label: {
                ScreenHeader(initial: name, kicker: kicker, title: title)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens settings")
            CartButton()
        }
    }
}

// MARK: - Week strip

private struct WeekStrip: View {
    let week: [PlannedDay]
    let dates: [Date]
    @Binding var selected: Int

    var body: some View {
        HStack(spacing: Space.xxs + 1) {
            ForEach(0..<7, id: \.self) { i in
                let isSelected = i == selected
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
                    .foregroundStyle(isSelected ? Palette.onInkFill : Palette.ink)
                    .frame(maxWidth: .infinity, minHeight: Size.row + 12)
                    .background(isSelected ? Palette.inkFill : Palette.card, in: RoundedRectangle(cornerRadius: Radius.sm))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(dates[i].formatted(.dateTime.weekday(.wide).day())), \(label(week[i]))")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    private func dotColor(_ day: PlannedDay, selected: Bool) -> Color {
        switch day.kind {
        case .training: selected ? Palette.onInkFill : Palette.copper
        case .activeRecovery: selected ? Palette.onInkFill.opacity(0.5) : Palette.track
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
                Text(meta)
                    .textStyle(.micro)
                    .foregroundStyle(Palette.onPanelMuted)
                    .padding(.top, Space.sm - 2)
                if isToday, day.kind == .training {
                    Button(action: onAdapt) {
                        Text("Adapt session ›")
                            .textStyle(.chip)
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
            .frame(maxWidth: .infinity, alignment: .leading)

            Color.clear
                .frame(maxWidth: Size.panelTextWidth / 2)
                .overlay {
                    Image(day.kind == .training ? "Illustration-lift" : "Illustration-walk")
                        .resizable()
                        .scaledToFill()
                }
                .overlay {
                    LinearGradient(colors: [Palette.panel, Palette.panel.opacity(0)], startPoint: .leading, endPoint: .init(x: 0.6, y: 0.5))
                }
                .clipped()
                .accessibilityHidden(true)
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: Radius.lg))
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Palette.panelEdge))
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

    private var meta: String {
        if let plan {
            return "🔥 \(Burn.kcal(minutes: plan.minutes, training: true)) kcal · ⏱ \(plan.minutes) min"
        }
        return day.minutes > 0 ? "🔥 \(Burn.kcal(minutes: day.minutes, training: false)) kcal · ⏱ \(day.minutes) min" : "Recover"
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
                ZStack {
                    Circle().fill(isDone ? Palette.inkFill : Palette.track)
                    if isDone {
                        Image(systemName: "checkmark")
                            .font(TextStyle.micro.font.weight(.heavy))
                            .foregroundStyle(Palette.onInkFill)
                    } else {
                        Text("\(index)")
                            .textStyle(.label)
                            .foregroundStyle(Palette.ink)
                    }
                }
                .frame(width: Size.checkRing + 8, height: Size.checkRing + 8)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isDone ? "Mark \(exercise.name) not done" : "Mark \(exercise.name) done")

            VStack(alignment: .leading, spacing: Space.xxs + 1) {
                Text(exercise.name)
                    .textStyle(.rowTitle)
                    .foregroundStyle(isDone ? Palette.inkMuted : Palette.ink)
                    .strikethrough(isDone, color: Palette.inkMuted)
                Text(ExerciseCopy.prescription(planned) + " · " + ExerciseCopy.equipment(exercise, owned: owned))
                    .textStyle(.caption)
                    .foregroundStyle(Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                if wasSwapped {
                    Label("Swapped · same movement", systemImage: "arrow.triangle.2.circlepath")
                        .textStyle(.micro)
                        .foregroundStyle(Palette.ice)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onSwap) {
                Text("Swap")
                    .textStyle(.chip)
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, Space.sm)
                    .padding(.vertical, Space.xs + 1)
                    .overlay(Capsule().strokeBorder(Palette.track))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Swap \(exercise.name)")
        }
        .padding(.horizontal, Space.md - 2)
        .padding(.vertical, Space.sm + 1)
    }
}

enum ExerciseCopy {
    static func prescription(_ p: PlannedExercise) -> String {
        let target = p.targetLow == p.targetHigh ? "\(p.targetLow)" : "\(p.targetLow)–\(p.targetHigh)"
        let unit = p.measure == .seconds ? " s" : ""
        var text = "\(p.sets) × \(target)\(unit)"
        if let tempo = p.tempoNote { text += ", \(tempo)" }
        return text + " · RPE \(p.rpeCap)"
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
    let today: Int
    /// Weekdays with at least one exercise ticked off.
    let completed: Set<Int>

    var body: some View {
        let sessions = week.filter { $0.kind == .training }.count
        let done = (0..<7).filter { week[$0].kind == .training && completed.contains($0) }.count
        VStack(alignment: .leading, spacing: Space.sm + 1) {
            HStack(alignment: .firstTextBaseline) {
                Text("This week")
                    .textStyle(.label)
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text("\(done) of \(sessions) sessions")
                    .textStyle(.micro)
                    .foregroundStyle(Palette.inkMuted)
            }
            HStack(spacing: Space.xxs) {
                ForEach(0..<7, id: \.self) { i in
                    Capsule()
                        .fill(fill(for: i))
                        .frame(height: Size.dot)
                }
            }
            .accessibilityHidden(true)
        }
        .padding(.horizontal, Space.md + 2)
        .padding(.vertical, Space.md)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.md))
    }

    private func fill(for i: Int) -> Color {
        let isSession = week[i].kind == .training
        if isSession && completed.contains(i) { return Palette.inkFill }
        if i == today && isSession { return Palette.inkFill.opacity(0.4) }
        return isSession ? Palette.track : Palette.hairline
    }
}
