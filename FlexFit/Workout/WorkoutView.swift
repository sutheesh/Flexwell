import SwiftUI
import SwiftData
import FlexFitEngine

/// Logging a session (PRD F6): pre-filled sets, one tap to confirm, tap the numbers to edit,
/// rest timer on confirm, "This hurts", then save + Apple Health.
struct WorkoutView: View {
    let date: Date

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router
    @Environment(EntitlementService.self) private var entitlements
    @Query private var profiles: [ProfileRecord]
    @Query private var logs: [DailyLog]
    @Query private var swaps: [ExerciseSwap]
    @Query private var painFlags: [PainFlag]
    @Query(sort: \SessionLog.finishedAt, order: .reverse) private var sessions: [SessionLog]

    @State private var rows: [Row] = []
    @State private var startedAt = Date.now
    @State private var restEndsAt: Date?
    @State private var editing: SetRef?
    @State private var painNotice: String?
    @State private var confirmExit = false
    @State private var loaded = false

    struct Row: Identifiable, Hashable {
        var planned: PlannedExercise
        var sets: [SetResult]
        var confirmed: [Bool]
        var id: String { planned.exerciseID }
    }

    struct SetRef: Identifiable, Hashable {
        let row: Int
        let set: Int
        var id: String { "\(row)-\(set)" }
    }

    private var units: DisplayUnits { profiles.first?.profile().displayUnits ?? .metric }
    private var confirmedCount: Int { rows.reduce(0) { $0 + $1.confirmed.filter { $0 }.count } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.md) {
                    if let painNotice {
                        InlineNote(text: painNotice, systemImage: "cross.case")
                    }
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        if let exercise = ExerciseLibrary.bundled[row.planned.exerciseID] {
                            ExerciseLogCard(
                                row: row,
                                exercise: exercise,
                                units: units,
                                onConfirm: { confirm(row: index, set: $0) },
                                onEdit: { editing = SetRef(row: index, set: $0) },
                                onHurts: { hurts(row: index) }
                            )
                        }
                    }
                }
                .padding(Space.lg)
                .padding(.bottom, Space.xxl * 2)
                .readableColumn()
            }
            .pageBackground()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        if confirmedCount > 0 { confirmExit = true } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish", action: finish)
                        .disabled(confirmedCount == 0)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let restEndsAt {
                    RestTimer(endsAt: restEndsAt) { self.restEndsAt = nil }
                        .padding(.horizontal, Space.lg)
                        .padding(.bottom, Space.xs)
                        .readableColumn()
                }
            }
            .confirmationDialog("Leave this session?", isPresented: $confirmExit, titleVisibility: .visible) {
                Button("Save and finish", action: finish)
                Button("Discard sets", role: .destructive) { dismiss() }
            } message: {
                Text("You've logged \(confirmedCount) set\(confirmedCount == 1 ? "" : "s").")
            }
            .sheet(item: $editing) { ref in
                SetEditor(set: binding(for: ref), measure: rows[ref.row].planned.measure,
                          loadable: ExerciseLibrary.bundled[rows[ref.row].planned.exerciseID]?.isLoadable == true,
                          units: units)
            }
        }
        .task { if !loaded { load(); loaded = true } }
    }

    private var title: String {
        guard let record = profiles.first else { return "Workout" }
        let resolver = PlanResolver(record: record, swaps: swaps, logs: logs, painFlags: painFlags)
        let weekday = (Calendar.current.component(.weekday, from: date) + 5) % 7
        return resolver.week[weekday].focus?.title ?? "Workout"
    }

    // MARK: Setup

    private func load() {
        guard let record = profiles.first else { return }
        let resolver = PlanResolver(record: record, swaps: swaps, logs: logs, painFlags: painFlags)
        let weekday = (Calendar.current.component(.weekday, from: date) + 5) % 7
        guard let plan = resolver.session(forWeekday: weekday, on: date, applyPivot: true) else { return }
        rows = plan.exercises.map { planned in
            let exercise = ExerciseLibrary.bundled[planned.exerciseID]
            let sets = exercise.map { Progression.prefill(planned, exercise: $0, last: lastPerformance(of: planned.exerciseID)) }
                ?? []
            return Row(planned: planned, sets: sets, confirmed: Array(repeating: false, count: sets.count))
        }
    }

    private func lastPerformance(of id: String) -> [SetResult]? {
        for session in sessions {
            if let entry = session.entries.first(where: { $0.exerciseID == id }), !entry.sets.isEmpty {
                return entry.sets
            }
        }
        return nil
    }

    private func binding(for ref: SetRef) -> Binding<SetResult> {
        Binding(get: { rows[ref.row].sets[ref.set] }, set: { rows[ref.row].sets[ref.set] = $0 })
    }

    // MARK: Actions

    private func confirm(row: Int, set: Int) {
        rows[row].confirmed[set].toggle()
        guard rows[row].confirmed[set] else { return }
        let compound = ExerciseLibrary.bundled[rows[row].planned.exerciseID]?.compound == true
        restEndsAt = .now.addingTimeInterval(compound ? 120 : 75)
    }

    private func hurts(row: Int) {
        guard let record = profiles.first, let exercise = ExerciseLibrary.bundled[rows[row].planned.exerciseID] else { return }
        let until = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
        modelContext.insert(PainFlag(exerciseID: exercise.id, until: until))
        try? modelContext.save()

        let profile = record.profile()
        let owned = record.activeTravelKit()?.equipment ?? profile.equipment
        let used = Set(rows.map(\.planned.exerciseID))
        if let pick = SwapRanker.alternatives(for: exercise, equipment: owned, limitations: profile.limitations,
                                              excluding: used, limit: 1).first {
            var planned = rows[row].planned
            planned.exerciseID = pick.exercise.id
            planned.measure = pick.exercise.measure
            planned.targetLow = pick.exercise.targetLow
            planned.targetHigh = pick.exercise.targetHigh
            let sets = Progression.prefill(planned, exercise: pick.exercise, last: lastPerformance(of: pick.exercise.id))
            rows[row] = Row(planned: planned, sets: sets, confirmed: Array(repeating: false, count: sets.count))
            painNotice = "Swapped \(exercise.name) for \(pick.exercise.name). It stays out of your plan for 7 days. If the pain continues, check with a clinician."
        } else {
            rows.remove(at: row)
            painNotice = "\(exercise.name) is out for 7 days. If the pain continues, check with a clinician."
        }
    }

    private func finish() {
        guard confirmedCount > 0, let record = profiles.first else { dismiss(); return }
        let wasFirstSession = sessions.isEmpty
        let day = Calendar.current.startOfDay(for: date)
        let session = SessionLog(day: day)
        session.startedAt = startedAt
        session.finishedAt = .now
        let weekday = (Calendar.current.component(.weekday, from: date) + 5) % 7
        session.focus = WeekPlanner.week(for: record.profile())[weekday].focus?.rawValue ?? ""
        session.variant = PlanResolver(record: record, swaps: swaps, logs: logs, painFlags: painFlags)
            .pivot(on: date, plannedMinutes: 0)?.variant.rawValue ?? SessionVariant.full.rawValue
        session.entries = rows.compactMap { row in
            let done = zip(row.sets, row.confirmed).filter(\.1).map(\.0)
            return done.isEmpty ? nil : LoggedExerciseRecord(exerciseID: row.planned.exerciseID, sets: done)
        }
        modelContext.insert(session)

        let log = DailyLog.forDay(date, in: modelContext)
        for entry in session.entries where !log.completedExercises.contains(entry.exerciseID) {
            log.completedExercises.append(entry.exerciseID)
        }
        try? modelContext.save()

        if record.healthSyncEnabled {
            let start = session.startedAt, end = session.finishedAt
            Task {
                let saved = await HealthService.shared.saveStrengthWorkout(start: start, end: end)
                await MainActor.run { session.savedToHealth = saved; try? modelContext.save() }
            }
        }
        dismiss()
        // PRD: the paywall shows after the first completed session, never during onboarding.
        if wasFirstSession && !entitlements.isPro {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                router.paywall = .firstSession
            }
        }
    }
}

// MARK: - Exercise card

private struct ExerciseLogCard: View {
    let row: WorkoutView.Row
    let exercise: Exercise
    let units: DisplayUnits
    let onConfirm: (Int) -> Void
    let onEdit: (Int) -> Void
    let onHurts: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: Space.sm) {
                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text(exercise.name)
                        .textStyle(.rowTitle)
                        .foregroundStyle(Palette.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text(ExerciseCopy.prescription(row.planned))
                        .textStyle(.caption)
                        .foregroundStyle(Palette.inkMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button(action: onHurts) {
                    Label("This hurts", systemImage: "bandage")
                        .textStyle(.micro)
                        .foregroundStyle(Palette.copperText)
                        .padding(.horizontal, Space.sm - 2)
                        .padding(.vertical, Space.xs - 2)
                        .background(Palette.copperTint, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(exercise.name) hurts")
            }
            .padding(Space.md)

            ForEach(row.sets.indices, id: \.self) { i in
                Rectangle().fill(Palette.hairline).frame(height: 1)
                SetRow(index: i, set: row.sets[i], measure: row.planned.measure, loadable: exercise.isLoadable, units: units,
                       confirmed: row.confirmed[i], exerciseName: exercise.name,
                       onConfirm: { onConfirm(i) }, onEdit: { onEdit(i) })
            }
        }
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.md))
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .cardShadow()
    }
}

private struct SetRow: View {
    let index: Int
    let set: SetResult
    let measure: Measure
    let loadable: Bool
    let units: DisplayUnits
    let confirmed: Bool
    let exerciseName: String
    let onConfirm: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: Space.sm) {
            Text("Set \(index + 1)")
                .textStyle(.caption)
                .foregroundStyle(Palette.inkMuted)
                .frame(width: Size.avatar + Space.sm, alignment: .leading)
            Button(action: onEdit) {
                Text(SetCopy.describe(set, measure: measure, loadable: loadable, units: units))
                    .textStyle(.rowTitle)
                    .foregroundStyle(confirmed ? Palette.inkMuted : Palette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit set \(index + 1): \(SetCopy.describe(set, measure: measure, loadable: loadable, units: units))")
            Button(action: onConfirm) {
                ZStack {
                    Circle().fill(confirmed ? Palette.inkFill : Color.clear)
                    Circle().strokeBorder(confirmed ? Color.clear : Palette.track, lineWidth: 1.5)
                    Image(systemName: "checkmark")
                        .font(TextStyle.label.font.weight(.heavy))
                        .foregroundStyle(confirmed ? Palette.onInkFill : Palette.inkMuted)
                }
                .frame(width: Size.control - 4, height: Size.control - 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(confirmed ? "Undo set \(index + 1) of \(exerciseName)" : "Confirm set \(index + 1) of \(exerciseName)")
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.xs + 2)
    }
}

enum SetCopy {
    static func describe(_ set: SetResult, measure: Measure, loadable: Bool, units: DisplayUnits) -> String {
        let value = measure == .seconds ? "\(set.value) s" : "\(set.value) reps"
        // Only prompt for a load where the exercise takes one and none is known yet.
        guard let kg = set.loadKg else { return loadable ? "\(value) · add load" : value }
        return "\(value) · \(Formatters.mass(kg, units: units))"
    }
}

// MARK: - Editing

private struct SetEditor: View {
    @Binding var set: SetResult
    let measure: Measure
    let loadable: Bool
    let units: DisplayUnits
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: Space.md) {
                Stepper(value: $set.value, in: 0...600, step: measure == .seconds ? 5 : 1) {
                    Text(measure == .seconds ? "\(set.value) seconds" : "\(set.value) reps")
                        .textStyle(.rowTitle)
                        .foregroundStyle(Palette.ink)
                }
                if loadable {
                    Stepper(value: loadBinding, in: 0...500, step: units == .imperial ? 5 : 2.5) {
                        Text(set.loadKg.map { Formatters.mass($0, units: units) } ?? "No load yet")
                            .textStyle(.rowTitle)
                            .foregroundStyle(Palette.ink)
                    }
                }
                Spacer()
            }
            .padding(Space.lg)
            .pageBackground()
            .navigationTitle("Edit set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.height(Size.row * 4)])
    }

    /// Steps in the user's units; stored in kg.
    private var loadBinding: Binding<Double> {
        Binding(
            get: { Mass.display(kilograms: set.loadKg ?? 0, in: units) },
            set: { set.loadKg = $0 <= 0 ? nil : Mass.kilograms(from: $0, in: units) }
        )
    }
}

// MARK: - Rest timer

private struct RestTimer: View {
    let endsAt: Date
    let onDone: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let left = max(0, Int(endsAt.timeIntervalSince(context.date).rounded(.up)))
            HStack(spacing: Space.sm) {
                Image(systemName: "timer")
                    .foregroundStyle(Palette.copper)
                    .accessibilityHidden(true)
                Text("Rest \(left / 60):\(String(format: "%02d", left % 60))")
                    .textStyle(.button)
                    .monospacedDigit()
                    .foregroundStyle(Palette.onPanel)
                Spacer()
                Button(left == 0 ? "Go" : "Skip", action: onDone)
                    .textStyle(.chip)
                    .foregroundStyle(Palette.navy)
                    .padding(.horizontal, Space.md)
                    .padding(.vertical, Space.xs)
                    .background(Palette.ice, in: Capsule())
            }
            .padding(.horizontal, Space.md + 2)
            .padding(.vertical, Space.sm)
            .background(Palette.panel, in: Capsule())
            .overlay(Capsule().strokeBorder(Palette.panelEdge))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Rest, \(left) seconds left")
        }
    }
}
