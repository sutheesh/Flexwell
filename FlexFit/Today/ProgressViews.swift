import SwiftUI
import SwiftData
import Charts
import FlexFitEngine

// MARK: - Data

/// Everything the progress tile and page show, gathered from the store for a window starting at `since`.
struct ProgressSnapshot {
    let since: Date
    let units: DisplayUnits
    let weight: ProgressReport.Change?
    let weightTrend: [WeightEntry]
    let body: [ProgressReport.BodyMetric: [(date: Date, value: Double)]]
    let weeks: [ProgressReport.WeekCalories]
    let daysOnTarget: Int
    let dailyTarget: Int
    let training: ProgressReport.Training
    let weeklyHours: [WeekValue]

    func change(_ metric: ProgressReport.BodyMetric) -> ProgressReport.Change? {
        ProgressReport.change(body[metric] ?? [])
    }

    @MainActor
    static func make(record: ProgressRecordInputs, since: Date) -> ProgressSnapshot {
        let profile = record.profile
        let entries = TargetsStore.weightEntries(record.weighIns).filter { $0.date >= since }
        var body: [ProgressReport.BodyMetric: [(date: Date, value: Double)]] = [:]
        for m in record.measurements where m.date >= since {
            if let kind = ProgressReport.BodyMetric(rawValue: m.kind) { body[kind, default: []].append((m.date, m.value)) }
        }

        // Calories: every day since `since` that has something eaten.
        let targets = TargetsStore.current(record.weekly, profile: profile)
        let context = MealPlanContext(profile: profile, targets: targets, swaps: record.swaps)
        let cal = Calendar.current
        var days: [(date: Date, kcal: Int, target: Int)] = []
        var day = cal.startOfDay(for: since)
        let today = cal.startOfDay(for: .now)
        let loggedDays = Set(record.logs.filter { !$0.eatenMeals.isEmpty }.map { cal.startOfDay(for: $0.day) })
            .union(record.foodEntries.map { cal.startOfDay(for: $0.day) })
        while day <= today {
            if loggedDays.contains(day) {
                let intake = DayIntake(context: context, date: day, logs: record.logs, entries: record.foodEntries)
                days.append((day, intake.kcal, intake.target))
            }
            day = cal.date(byAdding: .day, value: 1, to: day) ?? today.addingTimeInterval(86_400)
        }

        let sessions = record.sessions.filter { $0.day >= since }
        let training = ProgressReport.training(sessions.map { ($0.startedAt, $0.finishedAt, $0.entries.flatMap(\.sets)) })
        var hoursByWeek: [Date: Double] = [:]
        for s in sessions {
            hoursByWeek[Week.start(of: s.day), default: 0] += min(3, max(0, s.finishedAt.timeIntervalSince(s.startedAt)) / 3600)
        }

        return ProgressSnapshot(
            since: since, units: profile.displayUnits,
            weight: ProgressReport.weightChange(startKg: profile.weightKg, entries: entries),
            weightTrend: WeightTrend.series(entries),
            body: body,
            weeks: ProgressReport.weeklyCalories(days.map { ($0.date, $0.kcal) }),
            daysOnTarget: ProgressReport.daysOnTarget(days.map { ($0.kcal, $0.target) }),
            dailyTarget: targets.calories,
            training: training,
            weeklyHours: hoursByWeek.keys.sorted().map { WeekValue(weekOf: $0, value: hoursByWeek[$0] ?? 0) }
        )
    }
}

/// The stored records a snapshot is built from.
struct ProgressRecordInputs {
    let profile: UserProfile
    let weighIns: [WeighIn]
    let measurements: [BodyMeasurement]
    let sessions: [SessionLog]
    let logs: [DailyLog]
    let foodEntries: [FoodEntry]
    let weekly: [WeeklyTargets]
    let swaps: [IngredientSwapRecord]
}

// MARK: - Today tile

/// Today's first tile: growth since the start — weight, muscle, calories, gym and walking. Opens the Progress page.
struct ProgressTile: View {
    let snapshot: ProgressSnapshot
    let walking: HealthService.Walking?
    let healthOn: Bool

    var body: some View {
        let units = snapshot.units
        VStack(alignment: .leading, spacing: Space.md) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your progress").textStyle(.headline).foregroundStyle(Palette.ink)
                Spacer()
                Text("since \(DayMonth.text(snapshot.since)) ›").textStyle(.micro).foregroundStyle(Palette.blueText)
            }

            HStack(alignment: .bottom, spacing: Space.md) {
                VStack(alignment: .leading, spacing: Space.xxs + 1) {
                    if let w = snapshot.weight {
                        Text(signed(Mass.display(kilograms: w.delta, in: units), unit: units == .metric ? "kg" : "lb"))
                            .textStyle(.goalValue).foregroundStyle(Palette.ink)
                        Text("\(Formatters.mass(w.first, units: units)) → \(Formatters.mass(w.latest, units: units))")
                            .textStyle(.micro).foregroundStyle(Palette.inkMuted)
                    } else {
                        Text("—").textStyle(.goalValue).foregroundStyle(Palette.ink)
                        Text("Log a weigh-in to start the line").textStyle(.micro).foregroundStyle(Palette.inkMuted)
                    }
                    Text("weight").textStyle(.micro).foregroundStyle(Palette.copperText)
                }
                Spacer(minLength: 0)
                if snapshot.weightTrend.count >= 2 {
                    Sparkline(values: snapshot.weightTrend.map(\.kg), color: Palette.copperText)
                        .frame(width: Size.sparkline.width, height: Size.sparkline.height)
                }
            }

            Rectangle().fill(Palette.hairline).frame(height: 1)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: Space.md), GridItem(.flexible())], alignment: .leading, spacing: Space.md) {
                muscleCell(units)
                caloriesCell
                gymCell(units)
                walkingCell
            }
        }
        .padding(Space.md + 2)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.lg))
        .cardShadow()
        .contentShape(RoundedRectangle(cornerRadius: Radius.lg))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens your progress")
    }

    @ViewBuilder
    private func muscleCell(_ units: DisplayUnits) -> some View {
        if let lean = snapshot.change(.leanMassKg), lean.first != lean.latest {
            ProgressCell(value: signed(Mass.display(kilograms: lean.delta, in: units), unit: units == .metric ? "kg" : "lb"),
                         label: "lean mass",
                         detail: snapshot.change(.bodyFatPercent).map { "body fat " + signed($0.delta, unit: "%") })
        } else if let fat = snapshot.change(.bodyFatPercent), fat.first != fat.latest {
            ProgressCell(value: signed(fat.delta, unit: "%"), label: "body fat",
                         detail: "\(fat.latest.formatted(.number.precision(.fractionLength(1))))% now")
        } else if let lean = snapshot.change(.leanMassKg) {
            ProgressCell(value: Formatters.mass(lean.latest, units: units), label: "lean mass", detail: "log again to see the change")
        } else if let fat = snapshot.change(.bodyFatPercent) {
            ProgressCell(value: "\(fat.latest.formatted(.number.precision(.fractionLength(1))))%", label: "body fat",
                         detail: "log again to see the change")
        } else {
            ProgressCell(value: "Add", label: "muscle", detail: "body fat or lean mass, via Log progress", isPrompt: true)
        }
    }

    private var caloriesCell: some View {
        let avg = snapshot.weeks.isEmpty ? nil
            : snapshot.weeks.reduce(0) { $0 + $1.averageKcal * $1.daysLogged } / max(1, snapshot.weeks.reduce(0) { $0 + $1.daysLogged })
        return ProgressCell(value: avg.map { Formatters.kcal($0) } ?? "—", label: "avg kcal / day",
                            detail: "\(snapshot.daysOnTarget) days on target") {
            if snapshot.weeks.count >= 2 {
                MiniBars(values: snapshot.weeks.suffix(8).map { Double($0.averageKcal) }, target: Double(snapshot.dailyTarget))
            }
        }
    }

    private func gymCell(_ units: DisplayUnits) -> some View {
        let t = snapshot.training
        let hours = t.hours.formatted(.number.precision(.fractionLength(t.hours < 10 ? 1 : 0)))
        return ProgressCell(value: "\(t.sessions) · \(hours) h", label: "sessions · hours",
                            detail: t.liftedKg > 0 ? "\(liftedText(t.liftedKg, units)) lifted" : nil)
    }

    @ViewBuilder
    private var walkingCell: some View {
        if let walking, walking.km > 0 || walking.steps > 0 {
            let miles = snapshot.units == .imperial
            let distance = miles ? walking.km / 1.609 : walking.km
            ProgressCell(value: "\(distance.formatted(.number.precision(.fractionLength(0)))) \(miles ? "mi" : "km")",
                         label: "walked", detail: "\(Int(walking.steps / 1000))k steps")
        } else {
            ProgressCell(value: healthOn ? "—" : "Connect", label: "walked",
                         detail: healthOn ? "No walks in Health yet" : "Apple Health, in Profile", isPrompt: !healthOn)
        }
    }

    private func liftedText(_ kg: Double, _ units: DisplayUnits) -> String {
        let v = Mass.display(kilograms: kg, in: units)
        let unit = units == .metric ? "kg" : "lb"
        return v >= 10_000 ? "\((v / 1000).formatted(.number.precision(.fractionLength(1))))t" + (units == .metric ? "" : " \(unit)")
            : "\(Int(v).formatted()) \(unit)"
    }
}

/// "−0.6 kg", "+1.2%".
func signed(_ v: Double, unit: String) -> String {
    let text = abs(v).formatted(.number.precision(.fractionLength(0...1)))
    return (v > 0.05 ? "+" : v < -0.05 ? "−" : "") + text + (unit == "%" ? "%" : " \(unit)")
}

private struct ProgressCell<Mini: View>: View {
    let value: String
    let label: String
    var detail: String?
    var isPrompt = false
    @ViewBuilder var mini: () -> Mini

    init(value: String, label: String, detail: String? = nil, isPrompt: Bool = false, @ViewBuilder mini: @escaping () -> Mini) {
        self.value = value; self.label = label; self.detail = detail; self.isPrompt = isPrompt; self.mini = mini
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            Text(value)
                .textStyle(.statValue)
                .foregroundStyle(isPrompt ? Palette.blueText : Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label).textStyle(.micro).foregroundStyle(Palette.copperText)
            if let detail {
                Text(detail).textStyle(.micro).foregroundStyle(Palette.inkMuted).lineLimit(2)
            }
            mini().frame(height: Size.miniBars).padding(.top, Space.xxs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension ProgressCell where Mini == EmptyView {
    init(value: String, label: String, detail: String? = nil, isPrompt: Bool = false) {
        self.init(value: value, label: label, detail: detail, isPrompt: isPrompt) { EmptyView() }
    }
}

private struct Sparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        Chart(Array(values.enumerated()), id: \.offset) { i, v in
            LineMark(x: .value("i", i), y: .value("v", v)).foregroundStyle(color).interpolationMethod(.monotone)
            if i == values.count - 1 {
                PointMark(x: .value("i", i), y: .value("v", v)).foregroundStyle(color).symbolSize(30)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: .automatic(includesZero: false))
        .accessibilityHidden(true)
    }
}

private struct MiniBars: View {
    let values: [Double]
    let target: Double

    var body: some View {
        Chart {
            ForEach(Array(values.enumerated()), id: \.offset) { i, v in
                BarMark(x: .value("week", i), y: .value("kcal", v))
                    .foregroundStyle(abs(v - target) <= target * 0.1 ? Palette.blueText : Palette.copperText)
            }
            RuleMark(y: .value("target", target)).foregroundStyle(Palette.track).lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 2]))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .accessibilityHidden(true)
    }
}

// MARK: - Weekly check-in

/// Shown on Today when a weigh-in is 7+ days old or body measurements 14+; "Later" hides it until tomorrow.
struct WeeklyCheckInCard: View {
    /// Nil when there has never been a weigh-in.
    let daysSinceWeighIn: Int?
    let onLog: () -> Void
    let onLater: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: Space.sm) {
            Image(systemName: "calendar.badge.checkmark")
                .font(TextStyle.headline.font)
                .foregroundStyle(Palette.copperText)
                .frame(width: Size.iconTile, height: Size.iconTile)
                .background(Palette.copperTint, in: RoundedRectangle(cornerRadius: Radius.xs))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.xxs) {
                Text("Weekly check-in").textStyle(.rowTitle).foregroundStyle(Palette.ink)
                Text(message)
                    .textStyle(.caption).foregroundStyle(Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Space.sm) {
                    Button(action: onLog) {
                        Text("Log now")
                            .textStyle(.pill).foregroundStyle(Palette.onInkFill)
                            .padding(.horizontal, Space.md - 2).padding(.vertical, Space.xs + 1)
                            .background(Palette.inkFill, in: Capsule())
                    }
                    .buttonStyle(PressableStyle())
                    Button("Later", action: onLater)
                        .textStyle(.label).foregroundStyle(Palette.inkMuted)
                }
                .padding(.top, Space.xs - 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Space.md)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.md))
        .overlay(RoundedRectangle(cornerRadius: Radius.md).strokeBorder(Palette.copperTint, lineWidth: 1.5))
        .cardShadow()
    }

    private var message: String {
        guard let days = daysSinceWeighIn else { return "Log your weight, and body fat or waist if you track them." }
        if days >= 7 { return "No weigh-in for \(days) days. Add body fat or waist too if you track them." }
        return "Weight is up to date. Add body fat, lean mass or waist to see muscle change."
    }
}

// MARK: - Log progress

/// Weight, body fat, lean mass and waist in one place. Any field left empty is skipped.
struct LogProgressSheet: View {
    let units: DisplayUnits
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @State private var weight = ""
    @State private var bodyFat = ""
    @State private var lean = ""
    @State private var waist = ""

    private var massUnit: String { units == .metric ? "kg" : "lb" }
    private var lengthUnit: String { units == .metric ? "cm" : "in" }

    private func number(_ s: String) -> Double? { s.isEmpty ? nil : OnboardingDraft.number(s) }
    private var weightKg: Double? { number(weight).map { Mass.kilograms(from: $0, in: units) } }
    private var leanKg: Double? { number(lean).map { Mass.kilograms(from: $0, in: units) } }
    private var waistCm: Double? { number(waist).map { units == .metric ? $0 : $0 * 2.54 } }

    private var problems: [String] {
        var out: [String] = []
        if !weight.isEmpty, !(30...300).contains(weightKg ?? 0) { out.append("weight") }
        if !bodyFat.isEmpty, !(3...60).contains(number(bodyFat) ?? 0) { out.append("body fat (3–60%)") }
        if !lean.isEmpty, !(20...150).contains(leanKg ?? 0) { out.append("lean mass") }
        if !waist.isEmpty, !(40...200).contains(waistCm ?? 0) { out.append("waist") }
        return out
    }
    private var canSave: Bool { problems.isEmpty && !(weight + bodyFat + lean + waist).isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.md) {
                HStack {
                    Button("Cancel") { dismiss() }.textStyle(.chip).foregroundStyle(Palette.ink)
                    Spacer()
                    Text("Log progress").textStyle(.headline).foregroundStyle(Palette.ink)
                    Spacer()
                    Button(action: save) {
                        Text("Save")
                            .textStyle(.chip).foregroundStyle(Palette.onInkFill)
                            .padding(.horizontal, Space.md).padding(.vertical, Space.xs + 1)
                            .background(Palette.inkFill, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSave)
                    .opacity(canSave ? 1 : 0.5)
                }
                Text("Fill in what you have. Same time of day each week, ideally after waking. Values from Apple Health come in on their own.")
                    .textStyle(.caption).foregroundStyle(Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                field("Weight", $weight, unit: massUnit, placeholder: units == .metric ? "82.5" : "182")
                field("Body fat", $bodyFat, unit: "%", placeholder: "21")
                field("Lean mass", $lean, unit: massUnit, placeholder: units == .metric ? "62" : "137")
                field("Waist", $waist, unit: lengthUnit, placeholder: units == .metric ? "88" : "35")
                if !problems.isEmpty {
                    Text("Check " + problems.joined(separator: ", ") + ".")
                        .textStyle(.caption).foregroundStyle(Palette.copperText)
                }
            }
            .padding(Space.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .pageBackground()
        .presentationDetents([.large])
    }

    private func field(_ title: String, _ text: Binding<String>, unit: String, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: Space.xs - 2) {
            Text(title).textStyle(.label).foregroundStyle(Palette.ink)
            UnitField(text: text, placeholder: placeholder, unit: unit, accessibilityLabel: title)
        }
    }

    private func save() {
        let now = Date.now
        if let kg = weightKg { modelContext.insert(WeighIn(date: now, kg: kg)) }
        if let bf = number(bodyFat) { modelContext.insert(BodyMeasurement(date: now, kind: .bodyFatPercent, value: bf)) }
        if let kg = leanKg { modelContext.insert(BodyMeasurement(date: now, kind: .leanMassKg, value: kg)) }
        if let cm = waistCm { modelContext.insert(BodyMeasurement(date: now, kind: .waistCm, value: cm)) }
        try? modelContext.save()
        router.toast("Logged. Your progress is up to date.")
        dismiss()
    }
}

// MARK: - Progress page

/// The full picture behind the tile: a chart per metric over 4 weeks, 3 months or everything (Pro).
struct ProgressDetailView: View {
    enum Range: String, CaseIterable { case month = "4 weeks", quarter = "3 months", all = "All" }

    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router
    @Environment(EntitlementService.self) private var entitlements
    @Query private var profiles: [ProfileRecord]
    @Query(sort: \WeighIn.date) private var weighIns: [WeighIn]
    @Query(sort: \BodyMeasurement.date) private var measurements: [BodyMeasurement]
    @Query(sort: \SessionLog.day) private var sessions: [SessionLog]
    @Query private var logs: [DailyLog]
    @Query private var foodEntries: [FoodEntry]
    @Query(sort: \WeeklyTargets.weekOf) private var weekly: [WeeklyTargets]
    @Query private var swaps: [IngredientSwapRecord]
    @State private var range: Range = .all
    @State private var walking: HealthService.Walking?
    @State private var isLogging = false

    var body: some View {
        if let record = profiles.first {
            let limit = entitlements.historyStart()
            // Free is held to the last 30 days, so "4 weeks" is the range that's actually showing.
            let shown: Range = limit == nil ? range : .month
            let since = start(record: record, limit: limit, range: shown)
            let snap = ProgressSnapshot.make(record: ProgressRecordInputs(
                profile: record.profile(), weighIns: weighIns, measurements: measurements, sessions: sessions,
                logs: logs, foodEntries: foodEntries, weekly: weekly, swaps: swaps), since: since)
            ScrollView {
                VStack(alignment: .leading, spacing: Space.md) {
                    HStack(spacing: Space.sm) {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.left")
                                .font(TextStyle.headline.font).foregroundStyle(Palette.ink)
                                .frame(width: Size.avatar, height: Size.avatar)
                                .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.sm))
                                .cardShadow()
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Back")
                        VStack(alignment: .leading, spacing: Space.xxs + 1) {
                            Text("Since \(DayMonth.text(since))").textStyle(.caption).foregroundStyle(Palette.inkMuted)
                            Text("Progress").textStyle(.title2).foregroundStyle(Palette.ink).accessibilityAddTraits(.isHeader)
                        }
                        Spacer()
                    }
                    .padding(.vertical, Space.xs)

                    HStack(spacing: Space.xs) {
                        ForEach(Range.allCases, id: \.self) { r in
                            Chip(title: r.rawValue, isSelected: shown == r) {
                                if limit != nil && r != .month { router.paywall = .history } else { range = r }
                            }
                        }
                    }
                    if limit != nil {
                        InlineNote(text: "Free shows the last 30 days. Pro shows everything since you started; nothing older is deleted.",
                                   systemImage: "clock.arrow.circlepath")
                    }

                    weightCard(snap)
                    bodyCard(snap)
                    caloriesCard(snap)
                    trainingCard(snap)
                    walkingCard(snap, healthOn: record.healthSyncEnabled)

                    Button { isLogging = true } label: {
                        ActionRowContent(icon: "square.and.pencil", title: "Log progress", subtitle: "Weight, body fat, lean mass, waist")
                    }
                    .buttonStyle(.plain)
                    .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.md))
                    .cardShadow()
                }
                .padding(.horizontal, Space.lg)
                .padding(.top, Space.xs)
                .padding(.bottom, Space.xl)
                .readableColumn()
                .containerRelativeFrame(.horizontal)
            }
            .statusBarBackdrop()
            .pageBackground()
            .toolbar(.hidden, for: .navigationBar)
            .task(id: since) {
                if record.healthSyncEnabled { walking = await HealthService.shared.walking(since: since) }
            }
            .sheet(isPresented: $isLogging) { LogProgressSheet(units: record.profile().displayUnits) }
        }
    }

    private func start(record: ProfileRecord, limit: Date?, range: Range) -> Date {
        let cal = Calendar.current
        let begin = record.createdAt
        let window: Date = switch range {
        case .month: cal.date(byAdding: .day, value: -28, to: .now) ?? begin
        case .quarter: cal.date(byAdding: .month, value: -3, to: .now) ?? begin
        case .all: begin
        }
        return max(begin, max(window, limit ?? .distantPast))
    }

    private func card<C: View>(_ title: String, _ summary: String?, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).textStyle(.headline).foregroundStyle(Palette.ink)
                Spacer()
                if let summary { Text(summary).textStyle(.label).foregroundStyle(Palette.copperText) }
            }
            content()
        }
        .padding(Space.md)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.md))
        .cardShadow()
    }

    private func empty(_ text: String) -> some View {
        Text(text).textStyle(.caption).foregroundStyle(Palette.inkMuted).fixedSize(horizontal: false, vertical: true)
    }

    private func weightCard(_ s: ProgressSnapshot) -> some View {
        let unit = s.units == .metric ? "kg" : "lb"
        return card("Weight", s.weight.map { signed(Mass.display(kilograms: $0.delta, in: s.units), unit: unit) }) {
            if s.weightTrend.count >= 2 {
                Chart(s.weightTrend, id: \.date) { e in
                    LineMark(x: .value("Date", e.date), y: .value("Weight", Mass.display(kilograms: e.kg, in: s.units)))
                        .foregroundStyle(Palette.copperText).interpolationMethod(.monotone)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: Size.row * 2.4)
                .accessibilityLabel("Weight trend")
            } else {
                empty("Two weigh-ins start the trend line.")
            }
        }
    }

    private func bodyCard(_ s: ProgressSnapshot) -> some View {
        let lean = s.change(.leanMassKg), fat = s.change(.bodyFatPercent), waist = s.change(.waistCm)
        let unit = s.units == .metric ? "kg" : "lb"
        return card("Muscle and body composition", lean.map { signed(Mass.display(kilograms: $0.delta, in: s.units), unit: unit) + " lean" }) {
            if lean == nil && fat == nil && waist == nil {
                empty("Add body fat %, lean mass or waist with Log progress, or from a smart scale through Apple Health.")
            } else {
                HStack(spacing: Space.md) {
                    if let fat { stat("Body fat", "\(fat.latest.formatted(.number.precision(.fractionLength(1))))%", signed(fat.delta, unit: "%")) }
                    if let lean { stat("Lean mass", Formatters.mass(lean.latest, units: s.units), signed(Mass.display(kilograms: lean.delta, in: s.units), unit: unit)) }
                    if let waist {
                        let inches = s.units == .imperial
                        stat("Waist", "\((inches ? waist.latest / 2.54 : waist.latest).formatted(.number.precision(.fractionLength(0...1)))) \(inches ? "in" : "cm")",
                             signed(inches ? waist.delta / 2.54 : waist.delta, unit: inches ? "in" : "cm"))
                    }
                }
                let series = (s.body[.bodyFatPercent] ?? []).sorted { $0.date < $1.date }
                if series.count >= 2 {
                    Chart(Array(series.enumerated()), id: \.offset) { _, p in
                        LineMark(x: .value("Date", p.date), y: .value("Body fat", p.value))
                            .foregroundStyle(Palette.blueText).interpolationMethod(.monotone)
                        PointMark(x: .value("Date", p.date), y: .value("Body fat", p.value)).foregroundStyle(Palette.blueText)
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(height: Size.row * 2)
                    .accessibilityLabel("Body fat over time")
                }
            }
        }
    }

    private func caloriesCard(_ s: ProgressSnapshot) -> some View {
        card("Calories", "\(s.daysOnTarget) days on target") {
            if s.weeks.isEmpty {
                empty("Tick off meals on Eat or scan what you eat, and your weekly average shows here.")
            } else {
                Chart {
                    ForEach(s.weeks, id: \.weekOf) { w in
                        BarMark(x: .value("Week", w.weekOf, unit: .weekOfYear), y: .value("Average kcal", w.averageKcal))
                            .foregroundStyle(Palette.copperText)
                    }
                    RuleMark(y: .value("Target", s.dailyTarget))
                        .foregroundStyle(Palette.blueText).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
                .frame(height: Size.row * 2.4)
                .accessibilityLabel("Average daily calories by week against your target")
                Text("Average per logged day, each week. Dashed line: your target.").textStyle(.micro).foregroundStyle(Palette.inkMuted)
            }
        }
    }

    private func trainingCard(_ s: ProgressSnapshot) -> some View {
        let t = s.training
        return card("Gym", "\(t.sessions) sessions") {
            HStack(spacing: Space.md) {
                stat("Hours", t.hours.formatted(.number.precision(.fractionLength(1))), nil)
                stat("Lifted", Formatters.mass(t.liftedKg, units: s.units), nil)
            }
            if !s.weeklyHours.isEmpty {
                Chart(s.weeklyHours) { w in
                    BarMark(x: .value("Week", w.weekOf, unit: .weekOfYear), y: .value("Hours", w.value)).foregroundStyle(Palette.inkFill)
                }
                .frame(height: Size.row * 2)
                .accessibilityLabel("Hours trained by week")
            }
        }
    }

    private func walkingCard(_ s: ProgressSnapshot, healthOn: Bool) -> some View {
        let miles = s.units == .imperial
        return card("Walking", walking.map { "\((miles ? $0.km / 1.609 : $0.km).formatted(.number.precision(.fractionLength(0)))) \(miles ? "mi" : "km")" }) {
            if !healthOn {
                empty("Turn on Apple Health in Profile to see your steps and distance here.")
            } else if let walking, !walking.weeklyKm.isEmpty {
                Text("\(Int(walking.steps).formatted()) steps").textStyle(.caption).foregroundStyle(Palette.inkMuted)
                Chart(walking.weeklyKm) { w in
                    BarMark(x: .value("Week", w.weekOf, unit: .weekOfYear), y: .value("Distance", miles ? w.value / 1.609 : w.value))
                        .foregroundStyle(Palette.blueText)
                }
                .frame(height: Size.row * 2)
                .accessibilityLabel("Distance walked by week")
            } else {
                empty("No steps in Apple Health for this period yet.")
            }
        }
    }

    private func stat(_ label: String, _ value: String, _ change: String?) -> some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            Text(value).textStyle(.statValue).foregroundStyle(Palette.ink)
            Text(label).textStyle(.micro).foregroundStyle(Palette.inkMuted)
            if let change { Text(change).textStyle(.micro).foregroundStyle(Palette.copperText) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
