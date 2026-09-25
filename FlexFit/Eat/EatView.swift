import SwiftUI
import SwiftData
import Charts
import FlexFitEngine

/// Eat: the day's meals from your food answers, scaled to your target (mock "Discover meals"),
/// meal detail, ingredient swaps, plus targets, the weekly weigh-in and the protein check (PRD F7).
struct EatView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Environment(EntitlementService.self) private var entitlements
    @Query private var profiles: [ProfileRecord]
    @Query(sort: \WeighIn.date) private var weighIns: [WeighIn]
    @Query(sort: \WeeklyTargets.weekOf) private var weekly: [WeeklyTargets]
    @Query private var logs: [DailyLog]
    @Query private var ingredientSwaps: [IngredientSwapRecord]
    @State private var isLoggingWeight = false
    @State private var selectedWeekday = MealPlanContext.weekday(of: .now)
    @State private var detail: MealSelection?
    @State private var swapping: MealSelection?
    @State private var search = ""
    @Query(sort: \SavedMeal.savedAt, order: .reverse) private var savedMeals: [SavedMeal]

    var body: some View {
        if let record = profiles.first {
            content(record: record, profile: record.profile())
                .sheet(item: $detail) { selection in
                    MealDetailView(
                        planned: selection.planned,
                        isEaten: eaten(on: selection.date).contains(selection.planned.index),
                        onToggleEaten: { toggleEaten(selection) },
                        onMissingIngredient: {
                            detail = nil
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(450))
                                swapping = selection
                            }
                        }
                    )
                }
                .sheet(item: $swapping) { selection in
                    IngredientSwapSheet(planned: selection.planned, profile: record.profile()) { from, to in
                        modelContext.insert(IngredientSwapRecord(day: Calendar.current.startOfDay(for: selection.date),
                                                                 mealIndex: selection.planned.index, from: from, to: to))
                        try? modelContext.save()
                        router.toast("\(from) → \(to). Macros held close.")
                    }
                }
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

        let context = MealPlanContext(profile: profile, targets: targets, swaps: ingredientSwaps)
        let dates = weekDates()
        let selectedDate = dates[selectedWeekday]
        let dayMeals = context.meals(on: selectedDate)
        let todayMeals = context.meals(on: .now)
        let eatenToday = eaten(on: .now)
        let kcalLeft = targets.calories - todayMeals.filter { eatenToday.contains($0.index) }.reduce(0) { $0 + $1.kcal }
        let cuisineLine = profile.cuisines.isEmpty ? "All cuisines" : profile.cuisines.map(\.rawValue).sorted().joined(separator: " + ")

        return ScrollView {
            VStack(alignment: .leading, spacing: Space.md - 2) {
                HeaderButton(name: profile.name, kicker: "\(profile.diet.title) · \(cuisineLine)", title: "Discover meals")

                HStack(spacing: Space.sm - 2) {
                    SearchField(text: $search)
                    Button { router.isAdaptPresented = true } label: {
                        Image(systemName: "bolt")
                            .font(TextStyle.rowTitle.font)
                            .foregroundStyle(Palette.ink)
                            .frame(width: Size.button + 2, height: Size.button + 2)
                            .background(Palette.card, in: Circle())
                            .cardShadow()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Adapt today")
                }

                if !search.trimmingCharacters(in: .whitespaces).isEmpty {
                    SearchResults(query: search, profile: profile, targets: targets) { meal in
                        detail = MealSelection(date: .now, planned: meal)
                    }
                } else {
                    if let next = MealPlanContext.nextMeal(todayMeals, eaten: eatenToday) {
                        PickedForYouCard(planned: next, kcalLeft: kcalLeft, diet: profile.diet) {
                            detail = MealSelection(date: .now, planned: next)
                        }
                    }

                    DayChips(dates: dates, selected: $selectedWeekday)

                    HStack(alignment: .firstTextBaseline) {
                        SectionHeader(title: dayTitle(selectedDate))
                        Spacer()
                        Text("\(Formatters.kcal(dayMeals.reduce(0) { $0 + $1.kcal })) kcal")
                            .textStyle(.label)
                            .foregroundStyle(Palette.copperText)
                    }

                    if dayMeals.isEmpty {
                        InlineNote(text: "No meals match every allergy and diet rule you set. Loosen a dislike or the cooking time in Settings, or check the allergies.")
                    } else {
                        CardList {
                            ForEach(dayMeals) { meal in
                                MealCard(planned: meal, isEaten: eaten(on: selectedDate).contains(meal.index),
                                         onOpen: { detail = MealSelection(date: selectedDate, planned: meal) },
                                         onSwap: { swapping = MealSelection(date: selectedDate, planned: meal) })
                            }
                        }
                    }
                    if !savedMeals.isEmpty {
                        SectionHeader(title: "Saved meals")
                        CardList {
                            ForEach(savedMeals.compactMap { MealLibrary.bundled[$0.mealID] }) { meal in
                                let planned = PlannedMeal(meal: meal, slot: meal.slot, index: 200 + meal.id, kcal: meal.kcal,
                                                          proteinG: meal.proteinG, carbsG: meal.carbsG, fatG: meal.fatG,
                                                          ingredients: meal.ingredients, swapped: nil)
                                MealCard(planned: planned, isEaten: false,
                                         onOpen: { detail = MealSelection(date: .now, planned: planned) },
                                         onSwap: { swapping = MealSelection(date: .now, planned: planned) })
                            }
                        }
                    }
                    Text("Meals come from \(cuisineLine.lowercased()) kitchens, \(profile.diet.title.lowercased())\(profile.allergens.isEmpty ? "" : ", never containing " + profile.allergens.map { $0.title.lowercased() }.sorted().joined(separator: ", ")).")
                        .textStyle(.caption)
                        .foregroundStyle(Palette.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                SectionHeader(title: "Your targets")
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

    // MARK: Meals

    private func weekDates() -> [Date] {
        let monday = Week.start(of: .now)
        return (0..<7).map { Calendar.current.date(byAdding: .day, value: $0, to: monday) ?? monday }
    }

    private func dayTitle(_ date: Date) -> String {
        Calendar.current.isDateInToday(date) ? "Today" : date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
    }

    private func eaten(on date: Date) -> Set<Int> {
        Set(logs.first { Calendar.current.isDate($0.day, inSameDayAs: date) }?.eatenMeals ?? [])
    }

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

/// Avatar + title header (opens Settings) with the cart button on the right.
typealias HeaderButton = TabHeader

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

private struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: Space.sm - 2) {
            Image(systemName: "magnifyingglass").foregroundStyle(Palette.inkMuted).accessibilityHidden(true)
            TextField("Search meals, ingredients…", text: $text)
                .textStyle(.chip)
                .foregroundStyle(Palette.ink)
                .submitLabel(.search)
            if !text.isEmpty {
                Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.inkMuted) }
                    .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, Space.md + 2)
        .frame(minHeight: Size.button + 2)
        .background(Palette.card, in: Capsule())
        .cardShadow()
    }
}

/// Meals that are safe for you (allergens and diet) whose name or ingredients match the search.
private struct SearchResults: View {
    let query: String
    let profile: UserProfile
    let targets: DailyTargets
    let onOpen: (PlannedMeal) -> Void

    var body: some View {
        let q = query.lowercased()
        let pool = MealPlanner.pool(for: profile).values.flatMap { $0 }
        let matches = Dictionary(grouping: pool, by: \.id).compactMap { $0.value.first }
            .filter { $0.name.lowercased().contains(q) || $0.ingredients.contains { $0.name.lowercased().contains(q) } }
            .sorted { $0.name < $1.name }
        if matches.isEmpty {
            Text("Nothing safe for you matches “\(query)”.")
                .textStyle(.caption)
                .foregroundStyle(Palette.inkMuted)
        } else {
            CardList {
                ForEach(matches) { meal in
                    let planned = PlannedMeal(meal: meal, slot: meal.slot, index: 100 + meal.id, kcal: meal.kcal,
                                              proteinG: meal.proteinG, carbsG: meal.carbsG, fatG: meal.fatG,
                                              ingredients: meal.ingredients, swapped: nil)
                    MealCard(planned: planned, isEaten: false, onOpen: { onOpen(planned) }, onSwap: { onOpen(planned) })
                }
            }
        }
    }
}

private struct DayChips: View {
    let dates: [Date]
    @Binding var selected: Int

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.xs - 1) {
                ForEach(dates.indices, id: \.self) { i in
                    let isSelected = i == selected
                    Button { selected = i } label: {
                        Text(Calendar.current.isDateInToday(dates[i]) ? "Today" : "\(Weekday.shortName(i)) \(dates[i].formatted(.dateTime.day()))")
                            .textStyle(.chip)
                            .foregroundStyle(isSelected ? Palette.onInkFill : Palette.ink)
                            .padding(.horizontal, Space.md - 1)
                            .padding(.vertical, Space.sm)
                            .background(isSelected ? Palette.inkFill : Palette.card, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .id(i)
                }
            }
            .padding(.vertical, Space.xxs)
        }
        // Keep the selected day (usually today) in view.
        .onAppear { proxy.scrollTo(selected, anchor: .center) }
        .onChange(of: selected) { withAnimation { proxy.scrollTo(selected, anchor: .center) } }
        }
    }
}
