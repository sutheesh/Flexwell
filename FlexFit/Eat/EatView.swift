import SwiftUI
import SwiftData
import Charts
import FlexFitEngine

/// Eat: the day's meals from your food answers, scaled to your target (mock "Discover meals"),
/// meal detail, ingredient swaps and the food you logged, under today's calorie card. The weigh-in is on Path.
struct EatView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Query private var profiles: [ProfileRecord]
    @Query(sort: \WeeklyTargets.weekOf) private var weekly: [WeeklyTargets]
    @Query private var logs: [DailyLog]
    @Query private var ingredientSwaps: [IngredientSwapRecord]
    @Query private var foodEntries: [FoodEntry]
    @Query private var sessions: [SessionLog]
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
        }
    }

    private func content(record: ProfileRecord, profile: UserProfile) -> some View {
        let targets = TargetsStore.current(weekly, profile: profile)

        let context = MealPlanContext(profile: profile, targets: targets, swaps: ingredientSwaps)
        let dates = weekDates()
        let selectedDate = dates[selectedWeekday]
        let dayIntake = DayIntake(context: context, date: selectedDate, logs: logs, entries: foodEntries)
        let dayMeals = dayIntake.visibleMeals
        let todayIntake = DayIntake(context: context, date: .now, logs: logs, entries: foodEntries)
        let todayMeals = todayIntake.visibleMeals
        let eatenToday = todayIntake.eatenMealIndices
        let kcalLeft = todayIntake.kcalLeft
        let cuisineLine = profile.cuisines.isEmpty ? "All cuisines" : profile.cuisines.map(\.rawValue).sorted().joined(separator: " + ")

        return ScrollView {
            VStack(alignment: .leading, spacing: Space.md - 2) {
                HeaderButton(name: profile.name, kicker: "\(profile.diet.title) · \(cuisineLine)", title: "Discover meals")

                // Today's calories and macros (moved here from Today).
                TargetsCard(
                    targets: DailyTargets(calories: todayIntake.target, proteinG: targets.proteinG, carbsG: targets.carbsG,
                                          fatG: targets.fatG, expenditure: targets.expenditure, floorApplied: targets.floorApplied),
                    date: .now,
                    weekLabel: weekLabel(record: record, profile: profile),
                    eaten: (kcal: todayIntake.kcal, protein: todayIntake.protein, carbs: todayIntake.carbs, fat: todayIntake.fat)
                )

                HStack(spacing: Space.sm - 2) {
                    SearchField(text: $search)
                    Button { router.isScannerPresented = true } label: {
                        Image(systemName: "viewfinder")
                            .font(TextStyle.headline.font)
                            .foregroundStyle(Palette.ink)
                            .frame(width: Size.button + 2, height: Size.button + 2)
                            .background(Palette.card, in: Circle())
                            .cardShadow()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Scan food")
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

                    DayChips(dates: dates, selected: $selectedWeekday,
                             cheatDays: Set((0..<7).filter { context.week.days[$0].cheat != nil }))

                    HStack(alignment: .firstTextBaseline) {
                        SectionHeader(title: dayTitle(selectedDate))
                        Spacer()
                        Text("\(Formatters.kcal(dayMeals.reduce(0) { $0 + $1.kcal } + dayIntake.entries.reduce(0) { $0 + $1.kcal })) kcal")
                            .textStyle(.label)
                            .foregroundStyle(Palette.copperText)
                    }
                    .padding(.horizontal, Space.xxs / 2)
                    .padding(.top, Space.xs)

                    CheatDayBanner(day: context.day(on: selectedDate), proteinG: targets.proteinG,
                                   isToday: Calendar.current.isDateInToday(selectedDate))

                    if !dayIntake.entries.isEmpty {
                        CardList {
                            ForEach(dayIntake.entries) { entry in
                                FoodEntryRow(entry: entry) {
                                    modelContext.delete(entry)
                                    try? modelContext.save()
                                    router.toast("Removed.")
                                }
                            }
                        }
                    }
                    if dayMeals.isEmpty {
                        InlineNote(text: "No meals match every allergy and diet rule you set. Loosen a dislike or the cooking time in Profile, or check the allergies.")
                    } else {
                        CardList {
                            ForEach(dayMeals) { meal in
                                MealCard(planned: meal, isEaten: eaten(on: selectedDate).contains(meal.index),
                                         onOpen: { detail = MealSelection(date: selectedDate, planned: meal) },
                                         onSwap: { swapping = MealSelection(date: selectedDate, planned: meal) })
                            }
                            if let free = context.day(on: selectedDate).cheatMealKcal, !dayIntake.dinnerReplaced {
                                CheatMealCard(kcal: free)
                            }
                        }
                    }
                    if !savedMeals.isEmpty {
                        SectionHeader(title: "Saved meals")
                        CardList {
                            ForEach(savedMeals.compactMap { MealLibrary.bundled[$0.mealID] }) { meal in
                                let planned = PlannedMeal(meal: meal, moment: MealMoment(slot: meal.slot), index: 200 + meal.id, kcal: meal.kcal,
                                                          proteinG: meal.proteinG, carbsG: meal.carbsG, fatG: meal.fatG,
                                                          ingredients: meal.ingredients, swapped: nil)
                                MealCard(planned: planned, isEaten: false,
                                         onOpen: { detail = MealSelection(date: .now, planned: planned) },
                                         onSwap: { swapping = MealSelection(date: .now, planned: planned) })
                            }
                        }
                    }
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

    private func weekLabel(record: ProfileRecord, profile: UserProfile) -> String {
        let streak = TodayPlan.streak(sessions: sessions, planned: profile.trainingDays)
        if streak > 0 { return "🔥 \(streak)-week streak" }
        let week = TodayPlan.weekNumber(since: record.createdAt, now: .now)
        return TargetCalculator.weeksToGoal(for: profile).map { "Week \(min(week, $0)) of \($0)" } ?? "Week \(week)"
    }

    // MARK: Meals

    private func weekDates() -> [Date] {
        let monday = Week.start(of: .now)
        return (0..<7).map { Calendar.current.date(byAdding: .day, value: $0, to: monday) ?? monday }
    }

    private func dayTitle(_ date: Date) -> String {
        // Mock: "Today, 22 Sep" / "Wed, 23 Sep".
        let dayMonth = "\(date.formatted(.dateTime.day())) \(date.formatted(.dateTime.month(.abbreviated)))"
        return Calendar.current.isDateInToday(date) ? "Today, \(dayMonth)" : "\(date.formatted(.dateTime.weekday(.abbreviated))), \(dayMonth)"
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

}

/// Avatar + title header (opens Settings) with the cart button on the right.
typealias HeaderButton = TabHeader

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
                    let planned = PlannedMeal(meal: meal, moment: MealMoment(slot: meal.slot), index: 100 + meal.id, kcal: meal.kcal,
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
    /// Weekdays (0 = Monday) that are cheat days.
    var cheatDays: Set<Int> = []
    @State private var leadingDay: Int?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.xs - 1) {
                ForEach(dates.indices, id: \.self) { i in
                    let isSelected = i == selected
                    Button { selected = i } label: {
                        HStack(spacing: Space.xxs) {
                            Text(Calendar.current.isDateInToday(dates[i]) ? "Today" : "\(Weekday.shortName(i)) \(dates[i].formatted(.dateTime.day()))")
                            if cheatDays.contains(i) {
                                Image(systemName: "birthday.cake").imageScale(.small).accessibilityLabel("cheat day")
                            }
                        }
                            .textStyle(.label)
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
            .scrollTargetLayout()
            .padding(.top, Space.xs - 2)
        }
        // As in the mock: the day before today on the left edge, so today is always in view.
        .scrollPosition(id: $leadingDay, anchor: .leading)
        .onAppear { leadingDay = max(0, selected - 1) }
    }
}
