import SwiftUI
import FlexFitEngine

/// "Your plan is ready": targets, goal date and the typical week, built from the answers.
struct PlanReadyView: View {
    let profile: UserProfile
    let onStart: () -> Void

    private var targets: DailyTargets { TargetCalculator.initialTargets(for: profile) }
    private var weeks: Int? { TargetCalculator.weeksToGoal(for: profile) }
    private var week: [PlannedDay] { WeekPlanner.week(for: profile) }
    private var calorieWeek: CalorieWeek.Week {
        CalorieWeek.week(for: profile, base: targets.calories, expenditure: targets.expenditure)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Your path is ready")
                    .textStyle(.kicker)
                    .foregroundStyle(Palette.copperText)
                Text(title)
                    .textStyle(.title1)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Space.sm - 2)
                    .padding(.bottom, Space.xs - 2)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .textStyle(.body)
                    .foregroundStyle(Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, Space.lg - 2)

                TargetsPanel(targets: targets, weeks: weeks)

                if targets.floorApplied {
                    InlineNote(text: "Your target is held at a safe minimum, so the scale may move a little slower than the pace you picked.")
                        .padding(.top, Space.sm)
                }

                Text("The road")
                    .textStyle(.headline)
                    .foregroundStyle(Palette.ink)
                    .padding(.top, Space.xl + 2)
                    .padding(.bottom, Space.md - 2)
                    .accessibilityAddTraits(.isHeader)
                RoadSection(profile: profile, targets: targets, weeks: weeks, currentWeek: 1)

                Text("A typical week")
                    .textStyle(.headline)
                    .foregroundStyle(Palette.ink)
                    .padding(.top, Space.xl + 2)
                    .padding(.bottom, Space.sm)
                    .accessibilityAddTraits(.isHeader)

                CardList {
                    ForEach(week, id: \.weekday) { day in
                        WeekRow(day: day, foodKcal: calorieWeek.days[day.weekday].calories)
                    }
                }
                Text(foodLine)
                    .textStyle(.caption)
                    .foregroundStyle(Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Space.sm)
            }
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.xl)
            .padding(.bottom, Space.lg)
            .readableColumn()
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(title: "Start today", action: onStart)
                .padding(.horizontal, Space.lg)
                .padding(.top, Space.sm)
                .padding(.bottom, Space.xs)
                .readableColumn()
                .bottomBarBackground()
        }
        .statusBarBackdrop()
        .pageBackground()
    }

    private var title: String {
        switch profile.goal {
        case .maintain:
            "\(profile.name), here's your week"
        case .lose, .gain:
            if let weeks {
                "\(profile.name), \(weeks) weeks to \(Formatters.mass(profile.targetWeightKg, units: profile.displayUnits))"
            } else {
                "\(profile.name), here's your week"
            }
        }
    }

    private var foodLine: String {
        let kitchens = profile.cuisines.isEmpty ? "all" : profile.cuisines.map(\.rawValue).sorted().joined(separator: " + ")
        let never = profile.allergens.isEmpty ? "" : ", never containing " + profile.allergens.map { $0.title.lowercased() }.sorted().joined(separator: ", ")
        return "Meals come from \(kitchens) kitchens, \(profile.diet.title.lowercased())\(never). \(profile.mealPattern.title) a day\(profile.snacksBetweenMeals ? ", with light snacks between" : "")."
    }

    private var subtitle: String {
        let place = profile.environment.title.lowercased()
        return "\(profile.trainingDays) days of training a week, \(profile.sessionMinutes) minutes each, \(place)."
    }
}

/// The navy target card. Panels are dark in both appearances, so content uses fixed tokens.
private struct TargetsPanel: View {
    let targets: DailyTargets
    let weeks: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: Space.xs + 1) {
                    Text("Daily food target")
                        .textStyle(.micro)
                        .foregroundStyle(Palette.onPanelMuted)
                    HStack(alignment: .firstTextBaseline, spacing: Space.xs - 2) {
                        Text(Formatters.kcal(targets.calories))
                            .textStyle(.metric)
                            .foregroundStyle(Palette.onPanel)
                        Text("kcal")
                            .textStyle(.label)
                            .foregroundStyle(Palette.copper)
                    }
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: Space.sm)
                VStack(alignment: .trailing, spacing: Space.xs + 1) {
                    Text("Goal date")
                        .textStyle(.micro)
                        .foregroundStyle(Palette.onPanelMuted)
                    Text(goalDate)
                        .textStyle(.title2)
                        .foregroundStyle(Palette.ice)
                }
                .accessibilityElement(children: .combine)
            }

            Rectangle()
                .fill(Palette.onPanelHairline)
                .frame(height: 1)
                .padding(.top, Space.lg - 2)
                .padding(.bottom, Space.md)

            HStack(spacing: 0) {
                stat("\(targets.proteinG)g", "Protein")
                divider
                stat("\(targets.carbsG)g", "Carbs")
                divider
                stat("\(targets.fatG)g", "Fat")
                divider
                stat(weeks.map(String.init) ?? "—", "Weeks")
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.lg)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Palette.panelEdge))
    }

    private var goalDate: String {
        guard let weeks, let date = Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: .now) else {
            return "Ongoing"
        }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }

    private var divider: some View {
        Rectangle().fill(Palette.onPanelHairline).frame(width: 1)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: Space.xs - 2) {
            Text(value)
                .textStyle(.statValue)
                .foregroundStyle(Palette.onPanel)
            Text(label)
                .textStyle(.micro)
                .foregroundStyle(Palette.onPanelMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, label == "Protein" ? 0 : Space.md - 2)
        .accessibilityElement(children: .combine)
    }
}

private struct WeekRow: View {
    let day: PlannedDay
    let foodKcal: Int

    var body: some View {
        HStack(spacing: Space.sm + 1) {
            Text(Weekday.shortName(day.weekday))
                .textStyle(.label)
                .foregroundStyle(Palette.inkMuted)
                .frame(width: Size.control - 2, alignment: .leading)
            Circle()
                .fill(dotColor)
                .frame(width: Space.xs, height: Space.xs)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .textStyle(.rowTitle)
                    .foregroundStyle(Palette.ink)
                Text(meta)
                    .textStyle(.caption)
                    .foregroundStyle(Palette.inkMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: Space.xxs) {
                Text(Formatters.kcal(foodKcal)).textStyle(.label).foregroundStyle(Palette.copperText)
                Text("kcal").textStyle(.micro).foregroundStyle(Palette.inkMuted)
            }
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm + 1)
        .accessibilityElement(children: .combine)
    }

    private var name: String {
        switch day.kind {
        case .training: day.focus?.title ?? "Training"
        case .activeRecovery: "Walk + mobility"
        case .rest: "Rest day"
        }
    }

    private var meta: String {
        switch day.kind {
        case .training: "\(day.minutes) min · " + (day.focus?.moves.lowercased() ?? "strength")
        case .activeRecovery: "\(day.minutes) min · easy, keeps legs fresh"
        case .rest: "Recover"
        }
    }

    private var dotColor: Color {
        switch day.kind {
        case .training: Palette.copper
        case .activeRecovery: Palette.blueText
        case .rest: Palette.track
        }
    }
}

#Preview {
    PlanReadyView(profile: .demo) {}
}
