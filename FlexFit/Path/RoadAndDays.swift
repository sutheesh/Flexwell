import SwiftUI
import SwiftData
import FlexFitEngine

/// "The road to X": the mock's four phases, described by what the app actually does in each.
struct RoadSection: View {
    let profile: UserProfile
    let targets: DailyTargets
    let weeks: Int?
    let currentWeek: Int

    struct Phase: Hashable {
        let name: String
        let range: String
        let text: String
        let state: State
        enum State { case done, now, next }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(phases, id: \.self) { phase in
                HStack(alignment: .top, spacing: Space.md - 2) {
                    VStack(spacing: Space.xxs) {
                        Circle()
                            .fill(dot(phase.state))
                            .frame(width: Space.md, height: Space.md)
                            .overlay(Circle().strokeBorder(ring(phase.state), lineWidth: 3))
                        Rectangle().fill(Palette.track).frame(width: 2)
                    }
                    VStack(alignment: .leading, spacing: Space.xxs + 1) {
                        HStack(spacing: Space.xs) {
                            Text(phase.name).textStyle(.rowTitle).foregroundStyle(Palette.ink)
                            if phase.state == .now {
                                Text("YOU ARE HERE")
                                    .textStyle(.badge)
                                    .foregroundStyle(Palette.ice)
                                    .padding(.horizontal, Space.xs)
                                    .padding(.vertical, Space.xxs)
                                    .background(Palette.navy, in: Capsule())
                            }
                            Spacer()
                            Text(phase.range).textStyle(.micro).foregroundStyle(Palette.inkMuted)
                        }
                        Text(phase.text)
                            .textStyle(.caption)
                            .foregroundStyle(Palette.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.bottom, Space.md)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.leading, Space.xxs)
    }

    private var phases: [Phase] {
        guard let w = weeks, w >= 3 else {
            return [Phase(name: "Hold the line", range: "Ongoing",
                          text: "Train \(profile.trainingDays) days a week at about \(Formatters.kcal(targets.calories)) kcal. Targets follow your weight trend.",
                          state: .now)]
        }
        let fEnd = max(2, Int((Double(w) * 0.27).rounded()))
        let bEnd = max(fEnd + 1, Int((Double(w) * 0.67).rounded()))
        let defs: [(String, Int, Int?, String)] = [
            ("Foundation", 1, fEnd, "Learn the lifts. Loads start conservative and reps climb week to week."),
            ("Build momentum", fEnd + 1, bEnd, "Full \(profile.trainingDays)-day split at \(Formatters.kcal(targets.calories)) kcal. Loads go up once you hit the top of each rep range."),
            ("Sharpen", bEnd + 1, w, "Protein stays at \(targets.proteinG) g. Targets keep adjusting to your weight trend every week."),
            ("Hold the line", w + 1, nil, "At your goal, switch the goal to Maintain in Profile. Targets move to about \(Formatters.kcal(targets.expenditure)) kcal."),
        ]
        return defs.map { name, from, to, text in
            let state: Phase.State = if let to, currentWeek > to { .done }
                else if currentWeek >= from && (to == nil || currentWeek <= to!) { .now }
                else { .next }
            return Phase(name: name, range: to.map { "Wk \(from)–\($0)" } ?? "After wk \(w)", text: text, state: state)
        }
    }

    private func dot(_ s: Phase.State) -> Color {
        switch s { case .done: Palette.blueText; case .now: Palette.copper; case .next: Palette.card }
    }
    private func ring(_ s: Phase.State) -> Color {
        switch s { case .done: Palette.blueText; case .now: Palette.copper.opacity(0.35); case .next: Palette.ink.opacity(0.18) }
    }
}

/// "Day by day": tap any day for its session, steps, sleep window and meals.
struct DayByDaySection: View {
    let profile: UserProfile
    let targets: DailyTargets
    let swaps: [IngredientSwapRecord]
    let onOpenMeal: (MealSelection) -> Void
    @Environment(AppRouter.self) private var router
    @State private var selected = MealPlanContext.weekday(of: .now)

    var body: some View {
        let monday = Week.start(of: .now)
        let dates = (0..<7).map { Calendar.current.date(byAdding: .day, value: $0, to: monday) ?? monday }
        let week = WeekPlanner.week(for: profile)
        let day = week[selected]
        let meals = MealPlanContext(profile: profile, targets: targets, swaps: swaps).meals(on: dates[selected])

        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(spacing: Space.xxs + 1) {
                ForEach(0..<7, id: \.self) { i in
                    let isSelected = i == selected
                    Button { selected = i } label: {
                        VStack(spacing: Space.xxs + 1) {
                            Text(Weekday.shortName(i)).textStyle(.micro).opacity(0.7)
                            Text(dates[i].formatted(.dateTime.day())).textStyle(.statValue)
                            Circle()
                                .fill(week[i].kind == .training ? (isSelected ? Palette.ice : Palette.copper)
                                      : week[i].kind == .activeRecovery ? (isSelected ? Palette.onInkFill.opacity(0.4) : Palette.ink.opacity(0.25)) : .clear)
                                .frame(width: Size.dot - 1, height: Size.dot - 1)
                        }
                        .foregroundStyle(isSelected ? Palette.onInkFill : Palette.ink)
                        .frame(maxWidth: .infinity, minHeight: Size.row + 10)
                        .background(isSelected ? Palette.inkFill : Palette.card, in: RoundedRectangle(cornerRadius: Radius.sm))
                        .cardShadow()
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(Calendar.current.isDateInToday(dates[selected]) ? "Today" : dates[selected].formatted(.dateTime.weekday(.abbreviated))), \(DayMonth.text(dates[selected]))")
                        .textStyle(.mealName).foregroundStyle(Palette.ink)
                    Spacer()
                    Text(kindTitle(day)).textStyle(.micro).foregroundStyle(Palette.inkMuted)
                }
                .padding(.horizontal, Space.md)
                .padding(.top, Space.md - 1)
                .padding(.bottom, Space.sm)
                Rectangle().fill(Palette.hairline).frame(height: 1)

                if day.kind == .training {
                    activityRow(glyph: "▲", tile: Palette.navy, ink: Palette.ice,
                                title: day.focus?.title ?? "Training",
                                subtitle: (day.focus.map { $0.moves + "\n" } ?? "") + "\(SessionBuilder.slotCount(forMinutes: day.minutes)) movements · ~\(Burn.kcal(minutes: day.minutes, training: true)) kcal burn",
                                value: "\(day.minutes) min") { router.tab = .train }
                } else {
                    activityRow(glyph: "◐", tile: Palette.blueTint, ink: Palette.blueText,
                                title: day.kind == .rest ? "Full rest" : "Brisk walk + mobility",
                                subtitle: day.kind == .rest ? "Let the week land" : "Hips, T-spine, calves",
                                value: day.minutes > 0 ? "\(day.minutes) min" : "—") { router.tab = .train }
                }
                activityRow(glyph: "⋯", tile: Palette.copperTint, ink: Palette.copperText, title: "Steps", subtitle: "Spread across the day",
                            value: stepTarget(day).formatted(.number)) {}
                activityRow(glyph: "☾", tile: Palette.chipFill, ink: Palette.ink, title: "Sleep window", subtitle: sleepNote,
                            value: profile.sleep.isShort ? "8 h" : "7.5 h") {}

                Text("Food · \(Formatters.kcal(meals.reduce(0) { $0 + $1.kcal })) kcal")
                    .textStyle(.kicker)
                    .foregroundStyle(Palette.inkMuted)
                    .padding(.horizontal, Space.md)
                    .padding(.top, Space.sm)
                    .padding(.bottom, Space.xs - 2)
                ForEach(meals) { meal in
                    Button { onOpenMeal(MealSelection(date: dates[selected], planned: meal)) } label: {
                        HStack(spacing: Space.sm) {
                            Text(meal.moment.clock).textStyle(.micro).foregroundStyle(Palette.inkMuted)
                                .frame(width: Size.avatar + 16, alignment: .leading)
                            VStack(alignment: .leading, spacing: Space.xxs) {
                                Text(meal.meal.name).textStyle(.label).foregroundStyle(Palette.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("\(meal.moment.title) · \(meal.proteinG)g protein").textStyle(.micro).foregroundStyle(Palette.inkMuted)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(meal.kcal)").textStyle(.macroValue).foregroundStyle(Palette.copperText)
                        }
                        .padding(.horizontal, Space.md)
                        .padding(.vertical, Space.sm - 1)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .bottom) { Rectangle().fill(Palette.hairline).frame(height: 1) }
                }
            }
            .padding(.bottom, Space.xs)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.lg))
            .cardShadow()
        }
    }

    /// Mock: a 38 pt glyph tile, title + note, and the value on the right; a hairline under each row.
    private func activityRow(glyph: String, tile: Color, ink: Color, title: String, subtitle: String, value: String,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Space.sm + 1) {
                Text(glyph)
                    .textStyle(.label)
                    .foregroundStyle(ink)
                    .frame(width: Size.iconTile, height: Size.iconTile)
                    .background(tile, in: RoundedRectangle(cornerRadius: Radius.xs))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Space.xxs - 1) {
                    Text(title).textStyle(.label).foregroundStyle(Palette.ink)
                    Text(subtitle).textStyle(.micro).foregroundStyle(Palette.inkMuted).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(value).textStyle(.macroValue).foregroundStyle(Palette.ink)
            }
            .padding(.horizontal, Space.md)
            .padding(.vertical, Space.sm + 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.hairline).frame(height: 1) }
    }

    private func kindTitle(_ day: PlannedDay) -> String {
        switch day.kind { case .training: "Training day"; case .activeRecovery: "Active recovery"; case .rest: "Rest day" }
    }

    /// The mock's step targets: 8k on training days, 10k on recovery days, 7k on rest days.
    private func stepTarget(_ day: PlannedDay) -> Int {
        switch day.kind { case .training: 8_000; case .activeRecovery: 10_000; case .rest: 7_000 }
    }

    private var sleepNote: String {
        profile.sleep.isShort ? "You said sleep runs short: aim for lights out by 10:30 pm" : "Lights out by 11:00 pm"
    }
}
