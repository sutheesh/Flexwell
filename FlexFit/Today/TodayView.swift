import SwiftUI
import SwiftData
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

        return ScrollView {
            VStack(alignment: .leading, spacing: Space.md - 2) {
                Button { router.isSettingsPresented = true } label: {
                    TodayHeader(name: profile.name, date: now, week: week)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens settings")

                TargetsCard(
                    targets: targets,
                    date: now,
                    weekLabel: streak > 0 ? "🔥 \(streak)-week streak"
                        : (totalWeeks.map { "Week \(min(week, $0)) of \($0)" } ?? "Week \(week)"),
                    protein: todayLog?.proteinValue,
                    onProtein: { answer in setProtein(answer, on: now) }
                )

                if plannedToday.kind == .training {
                    EnergyCheckIn(energy: todayLog?.energyValue, pivot: pivot,
                                  onPick: { pick($0, on: now) },
                                  onChange: { setEnergy(nil, on: now) })
                }

                SessionCard(day: plannedToday, pivot: pivot, plan: plan, travel: record.activeTravelKit(now: now),
                            isDone: doneToday,
                            onStart: { router.workoutDay = Calendar.current.startOfDay(for: now) },
                            onAdapt: { router.isAdaptPresented = true })

                SectionHeader(title: "Quick adjustments")
                CardList {
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

// MARK: - Header

private struct TodayHeader: View {
    let name: String
    let date: Date
    let week: Int

    var body: some View {
        HStack(spacing: Space.sm) {
            Text(String(name.prefix(1)).uppercased())
                .textStyle(.button)
                .foregroundStyle(Palette.navy)
                .frame(width: Size.avatar, height: Size.avatar)
                .background(Palette.copper, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.xxs + 1) {
                Text("\(date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))) · week \(week)")
                    .textStyle(.caption)
                    .foregroundStyle(Palette.inkMuted)
                Text("Hi \(name)")
                    .textStyle(.title2)
                    .foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, Space.xs)
    }
}

// MARK: - Targets + protein check

/// Navy panel: dark in both appearances, so its content uses fixed tokens.
private struct TargetsCard: View {
    let targets: DailyTargets
    let date: Date
    let weekLabel: String
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

            VStack(spacing: Space.xs) {
                Image(systemName: "bolt.fill")
                    .font(TextStyle.label.font)
                    .foregroundStyle(Palette.copper)
                    .accessibilityHidden(true)
                HStack(alignment: .firstTextBaseline, spacing: Space.xs - 2) {
                    Text(Formatters.kcal(targets.calories))
                        .textStyle(.metric)
                        .foregroundStyle(Palette.onPanel)
                    Text("kcal")
                        .textStyle(.label)
                        .foregroundStyle(Palette.copper)
                }
                Text("Today's target")
                    .textStyle(.micro)
                    .foregroundStyle(Palette.onPanelMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Space.lg)
            .accessibilityElement(children: .combine)

            HStack(spacing: 0) {
                MacroStat(label: "Protein", grams: targets.proteinG, fill: Palette.ice, leading: true)
                MacroStat(label: "Carbs", grams: targets.carbsG, fill: Palette.copper)
                MacroStat(label: "Fat", grams: targets.fatG, fill: Palette.sand)
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

private struct MacroStat: View {
    let label: String
    let grams: Int
    let fill: Color
    var leading = false

    var body: some View {
        HStack(spacing: Space.xs) {
            Capsule().fill(fill).frame(width: Size.progressBar)
            VStack(alignment: .leading, spacing: Space.xxs + 2) {
                Text(label)
                    .textStyle(.micro)
                    .foregroundStyle(Palette.onPanelMuted)
                Text("\(grams)g")
                    .textStyle(.statValue)
                    .foregroundStyle(Palette.onPanel)
            }
        }
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
                Button("Change", action: onChange)
                    .textStyle(.label)
                    .foregroundStyle(Palette.copperText)
                    .buttonStyle(.plain)
                    .padding(.vertical, Space.xs)
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

            Text(EnergyCopy.sessionNote(day: day, pivot: pivot))
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

            Label(meta, systemImage: "clock")
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
        case .training: "\(minutes) min · \(plan?.exercises.count ?? 0) exercises · RPE ≤ \(pivot?.rpeCap ?? 8)"
        case .activeRecovery: "\(minutes) min · easy"
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
                Image(systemName: "chevron.right")
                    .font(TextStyle.chip.font)
                    .foregroundStyle(Palette.inkMuted)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.md - 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
