import SwiftUI
import SwiftData
import Charts
import FlexFitEngine

/// Eat (MVP): this week's calorie and protein targets, the weekly weigh-in, the protein check (PRD F7).
/// Meal plans and groceries are Phase 2.
struct EatView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Environment(EntitlementService.self) private var entitlements
    @Query private var profiles: [ProfileRecord]
    @Query(sort: \WeighIn.date) private var weighIns: [WeighIn]
    @Query(sort: \WeeklyTargets.weekOf) private var weekly: [WeeklyTargets]
    @Query private var logs: [DailyLog]
    @State private var isLoggingWeight = false

    var body: some View {
        if let record = profiles.first {
            content(record: record, profile: record.profile())
                .sheet(isPresented: $isLoggingWeight) {
                    WeighInSheet(units: record.profile().displayUnits) { kg in
                        modelContext.insert(WeighIn(date: .now, kg: kg))
                        try? modelContext.save()
                    }
                }
        }
    }

    private func content(record: ProfileRecord, profile: UserProfile) -> some View {
        let targets = TargetsStore.current(weekly, profile: profile)
        let thisWeek = weekly.last { $0.weekOf <= .now }
        let entries = TargetsStore.weightEntries(weighIns)
        let trend = WeightTrend.series(entries)
        let change = WeightTrend.weeklyChange(entries, asOf: .now)
        let lowToday = logs.first { Calendar.current.isDateInToday($0.day) }?.energyValue == .low
        let lowYesterday = logs.first { Calendar.current.isDateInYesterday($0.day) }?.energyValue == .low

        return ScrollView {
            VStack(alignment: .leading, spacing: Space.md - 2) {
                HeaderButton(name: profile.name, kicker: "Daily targets", title: "Fuel")

                TargetsPanel(targets: targets, adaptive: entitlements.hasAdaptiveTargets, weekOf: thisWeek?.weekOf)

                if !entitlements.hasAdaptiveTargets {
                    Button { router.paywall = .adaptiveTargets } label: {
                        ActionRowContent(icon: "arrow.triangle.2.circlepath", title: "Make targets adaptive",
                                         subtitle: "Pro recalculates calories and protein every week from your weight trend")
                    }
                    .buttonStyle(.plain)
                    .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.md))
                    .cardShadow()
                }

                notices(targets: targets, week: thisWeek, maintenanceDay: lowToday && lowYesterday)

                SectionHeader(title: "Weekly weigh-in")
                WeightCard(entries: entries, trend: trend, change: change, units: profile.displayUnits,
                           target: profile.targetWeightKg, onLog: { isLoggingWeight = true })

                SectionHeader(title: "Protein this week")
                ProteinWeek(logs: logs, grams: targets.proteinG)
            }
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.xs)
            .padding(.bottom, Space.xl)
            .readableColumn()
        }
        .statusBarBackdrop()
        .pageBackground()
    }

    @ViewBuilder
    private func notices(targets: DailyTargets, week: WeeklyTargets?, maintenanceDay: Bool) -> some View {
        if week?.rapidLossWarning == true {
            InlineNote(text: "Your weight has dropped faster than 1.5% a week for two weeks, so your targets went up. It's worth a check-in with a doctor or dietitian.",
                       systemImage: "exclamationmark.triangle")
        }
        if week?.skippedForIntake == true {
            InlineNote(text: "Protein was a \"No\" on 3 or more days last week, so this week's adjustment was skipped. Targets stay as they were.")
        }
        if targets.floorApplied {
            InlineNote(text: "Your target is held at a safe minimum. The scale may move a little slower than the pace you picked.")
        }
        if maintenanceDay {
            InlineNote(text: "Second low-energy day in a row. Eating at maintenance today is fine: about \(Formatters.kcal(targets.expenditure)) kcal.",
                       systemImage: "fork.knife")
        }
    }
}

/// Avatar + title header whose avatar opens Settings.
struct HeaderButton: View {
    let name: String
    let kicker: String
    let title: String
    @Environment(AppRouter.self) private var router

    var body: some View {
        Button { router.isSettingsPresented = true } label: {
            ScreenHeader(initial: name, kicker: kicker, title: title)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens settings")
    }
}

/// Navy targets panel. Fixed-dark content.
private struct TargetsPanel: View {
    let targets: DailyTargets
    let adaptive: Bool
    let weekOf: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(adaptive ? "Adaptive · recalculated weekly" : "Static targets")
                    .textStyle(.micro)
                    .foregroundStyle(Palette.onPanelMuted)
                Spacer()
                if let weekOf {
                    Text("Week of \(weekOf.formatted(.dateTime.day().month(.abbreviated)))")
                        .textStyle(.micro)
                        .foregroundStyle(Palette.ice)
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: Space.xs - 2) {
                Text(Formatters.kcal(targets.calories))
                    .textStyle(.metric)
                    .foregroundStyle(Palette.onPanel)
                Text("kcal a day")
                    .textStyle(.label)
                    .foregroundStyle(Palette.copper)
            }
            .padding(.top, Space.sm)
            Text("Estimated maintenance: \(Formatters.kcal(targets.expenditure)) kcal")
                .textStyle(.caption)
                .foregroundStyle(Palette.onPanelMuted)
                .padding(.top, Space.xxs)

            HStack(spacing: 0) {
                stat("\(targets.proteinG)g", "Protein")
                stat("\(targets.carbsG)g", "Carbs")
                stat("\(targets.fatG)g", "Fat")
            }
            .padding(.top, Space.md)
            .overlay(alignment: .top) { Rectangle().fill(Palette.onPanelHairline).frame(height: 1).offset(y: Space.xs) }
        }
        .padding(Space.lg)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).strokeBorder(Palette.panelEdge))
        .accessibilityElement(children: .combine)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: Space.xxs + 2) {
            Text(label).textStyle(.micro).foregroundStyle(Palette.onPanelMuted)
            Text(value).textStyle(.statValue).foregroundStyle(Palette.onPanel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Space.md)
    }
}

private struct WeightCard: View {
    let entries: [WeightEntry]
    let trend: [WeightEntry]
    let change: Double?
    let units: DisplayUnits
    let target: Double
    let onLog: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text("Trend weight")
                        .textStyle(.micro)
                        .foregroundStyle(Palette.inkMuted)
                    Text(trend.last.map { Formatters.mass($0.kg, units: units) } ?? "No weigh-ins yet")
                        .textStyle(.title2)
                        .foregroundStyle(Palette.ink)
                }
                Spacer()
                if let change {
                    Text((change > 0 ? "+" : "") + Formatters.mass(change, units: units) + " / wk")
                        .textStyle(.label)
                        .foregroundStyle(Palette.copperText)
                }
            }

            if trend.count >= 2 {
                Chart {
                    ForEach(entries, id: \.date) { e in
                        PointMark(x: .value("Date", e.date), y: .value("Weight", Mass.display(kilograms: e.kg, in: units)))
                            .foregroundStyle(Palette.track)
                            .symbolSize(18)
                    }
                    ForEach(trend, id: \.date) { e in
                        LineMark(x: .value("Date", e.date), y: .value("Trend", Mass.display(kilograms: e.kg, in: units)))
                            .foregroundStyle(Palette.copperText)
                            .interpolationMethod(.monotone)
                    }
                    RuleMark(y: .value("Target", Mass.display(kilograms: target, in: units)))
                        .foregroundStyle(Palette.blueText.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: Size.row * 2.5)
                .accessibilityLabel("Weight trend chart")
            } else {
                Text("Weigh in once a week, same time of day. Two weigh-ins start the trend line.")
                    .textStyle(.caption)
                    .foregroundStyle(Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            PrimaryButton(title: "Log weight", showsArrow: false, action: onLog)
        }
        .padding(Space.md)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.md))
        .cardShadow()
    }
}

private struct ProteinWeek: View {
    let logs: [DailyLog]
    let grams: Int

    var body: some View {
        let monday = Week.start(of: .now)
        HStack(spacing: Space.xs - 2) {
            ForEach(0..<7, id: \.self) { i in
                let day = Calendar.current.date(byAdding: .day, value: i, to: monday) ?? monday
                let answer = logs.first { Calendar.current.isDate($0.day, inSameDayAs: day) }?.proteinValue
                VStack(spacing: Space.xxs + 1) {
                    Text(Weekday.shortName(i))
                        .textStyle(.micro)
                        .foregroundStyle(Palette.inkMuted)
                    Circle()
                        .fill(color(answer))
                        .frame(width: Size.checkRing, height: Size.checkRing)
                        .overlay {
                            if let answer {
                                Text(answer.title.prefix(1))
                                    .textStyle(.micro)
                                    .foregroundStyle(answer == .no ? Palette.ink : Palette.onInkFill)
                            }
                        }
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(Weekday.shortName(i)): \(answer?.title ?? "not answered")")
            }
        }
        .padding(Space.md)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.md))
        .cardShadow()
        .overlay(alignment: .bottomLeading) { EmptyView() }
    }

    private func color(_ a: ProteinCheck?) -> Color {
        switch a {
        case .yes?: Palette.inkFill
        case .close?: Palette.blueText
        case .no?: Palette.track
        case nil: Palette.hairline
        }
    }
}

private struct WeighInSheet: View {
    let units: DisplayUnits
    let onSave: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Space.md) {
                Text("Same time of day each week, ideally after waking. It's the trend that matters, not one reading.")
                    .textStyle(.caption)
                    .foregroundStyle(Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                UnitField(text: $text, placeholder: units == .metric ? "82.5" : "182", unit: units == .metric ? "kg" : "lb",
                          accessibilityLabel: "Weight")
                    .focused($focused)
                Spacer()
            }
            .padding(Space.lg)
            .pageBackground()
            .navigationTitle("Log weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let v = OnboardingDraft.number(text) {
                            let kg = Mass.kilograms(from: v, in: units)
                            if (30...300).contains(kg) { onSave(kg); dismiss() }
                        }
                    }
                    .disabled(OnboardingDraft.number(text) == nil)
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium])
    }
}
