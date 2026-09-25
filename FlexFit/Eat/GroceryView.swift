import SwiftUI
import SwiftData
import FlexFitEngine

/// Groceries for the rest of this week's meals (mock "Groceries"), with a pantry the list skips.
struct GroceryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [ProfileRecord]
    @Query(sort: \WeeklyTargets.weekOf) private var weekly: [WeeklyTargets]
    @Query private var swaps: [IngredientSwapRecord]
    @Query private var checks: [GroceryCheck]
    @Query(sort: \PantryItem.name) private var pantry: [PantryItem]

    var body: some View {
        NavigationStack {
            if let record = profiles.first {
                content(record.profile())
                    .navigationTitle("Groceries")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            }
        }
    }

    private func content(_ profile: UserProfile) -> some View {
        let context = MealPlanContext(profile: profile, targets: TargetsStore.current(weekly, profile: profile), swaps: swaps)
        let monday = Week.start(of: .now)
        let days = (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: monday) }
        let items = GroceryList.build(from: days.map { context.meals(on: $0) })
        let pantryNames = Set(pantry.map(\.name))
        let needed = items.filter { !pantryNames.contains($0.name) }
        let checked = Set(checks.filter { $0.weekOf == monday }.map(\.name))
        let left = needed.filter { !checked.contains($0.name) }.count

        return ScrollView {
            VStack(alignment: .leading, spacing: Space.md) {
                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text("\(left) of \(needed.count) left · \(profile.shopDay.title)")
                        .textStyle(.caption)
                        .foregroundStyle(Palette.inkMuted)
                    Text(budgetNote(profile.budget))
                        .textStyle(.caption)
                        .foregroundStyle(Palette.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(GroceryCategory.allCases, id: \.self) { category in
                    let rows = needed.filter { $0.category == category }
                    if !rows.isEmpty {
                        Text(category.title)
                            .textStyle(.kicker)
                            .foregroundStyle(Palette.copperText)
                            .padding(.top, Space.xs)
                        CardList {
                            ForEach(rows, id: \.name) { item in
                                GroceryRow(item: item, isChecked: checked.contains(item.name),
                                           onToggle: { toggle(item.name, week: monday) },
                                           onPantry: { modelContext.insert(PantryItem(name: item.name)); try? modelContext.save() })
                            }
                        }
                    }
                }

                if !pantry.isEmpty {
                    Text("In your pantry")
                        .textStyle(.kicker)
                        .foregroundStyle(Palette.copperText)
                        .padding(.top, Space.xs)
                    Text("Left off the list. Tap to add back.")
                        .textStyle(.caption)
                        .foregroundStyle(Palette.inkMuted)
                    FlowLayout {
                        ForEach(pantry) { item in
                            Chip(title: item.name, isSelected: true) {
                                modelContext.delete(item)
                                try? modelContext.save()
                            }
                        }
                    }
                }
            }
            .padding(Space.lg)
            .readableColumn()
        }
        .pageBackground()
    }

    private func toggle(_ name: String, week: Date) {
        if let existing = checks.first(where: { $0.weekOf == week && $0.name == name }) {
            modelContext.delete(existing)
        } else {
            modelContext.insert(GroceryCheck(weekOf: week, name: name))
        }
        try? modelContext.save()
    }

    private func budgetNote(_ budget: GroceryBudget) -> String {
        switch budget {
        case .tight: "Tight budget: buy staples in bulk and batch-cook the grains and dals."
        case .moderate: "Frozen veg and pre-cooked grains are fine where they save time."
        case .comfortable: "Buy whatever makes the macros easiest to hit."
        }
    }
}

private struct GroceryRow: View {
    let item: GroceryItem
    let isChecked: Bool
    let onToggle: () -> Void
    let onPantry: () -> Void

    var body: some View {
        HStack(spacing: Space.sm) {
            Button(action: onToggle) {
                HStack(spacing: Space.sm) {
                    SelectionRing(isSelected: isChecked)
                    Text(item.name)
                        .textStyle(.rowTitle)
                        .foregroundStyle(isChecked ? Palette.inkMuted : Palette.ink)
                        .strikethrough(isChecked, color: Palette.inkMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(item.grams >= 1000 ? (Double(item.grams) / 1000).formatted(.number.precision(.fractionLength(1))) + " kg" : "\(item.grams) g")
                        .textStyle(.caption)
                        .foregroundStyle(Palette.inkMuted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isChecked ? .isSelected : [])
            Menu {
                Button("I always have this", systemImage: "cabinet", action: onPantry)
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(Palette.inkMuted)
                    .frame(width: Size.checkRing + 6, height: Size.checkRing + 6)
            }
            .accessibilityLabel("More for \(item.name)")
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
    }
}

extension GroceryCategory {
    var title: String {
        switch self {
        case .protein: "Protein"
        case .produce: "Produce"
        case .dairy: "Dairy"
        case .pantry: "Pantry"
        }
    }
}

/// "Eating out tonight": three safe orders for what's left today (mock restaurant mode, PRD guide).
struct RestaurantSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [ProfileRecord]
    @Query(sort: \WeeklyTargets.weekOf) private var weekly: [WeeklyTargets]
    @Query private var logs: [DailyLog]
    @Query private var swaps: [IngredientSwapRecord]
    @State private var cuisine = RestaurantGuide.cuisines.first ?? ""
    @State private var logged: String?

    var body: some View {
        NavigationStack {
            if let record = profiles.first {
                content(record.profile())
                    .navigationTitle("Order without guessing")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            }
        }
        .presentationDetents([.large])
    }

    private func content(_ profile: UserProfile) -> some View {
        let targets = TargetsStore.current(weekly, profile: profile)
        let meals = MealPlanContext(profile: profile, targets: targets, swaps: swaps).meals(on: .now)
        let eaten = Set(logs.first { Calendar.current.isDateInToday($0.day) }?.eatenMeals ?? [])
        let kcalLeft = targets.calories - meals.filter { eaten.contains($0.index) }.reduce(0) { $0 + $1.kcal }
        let picks = RestaurantGuide.picks(cuisine: cuisine, profile: profile, kcalLeft: kcalLeft)

        return ScrollView {
            VStack(alignment: .leading, spacing: Space.md) {
                Text("You have \(Formatters.kcal(max(0, kcalLeft))) kcal left today.")
                    .textStyle(.body)
                    .foregroundStyle(Palette.inkMuted)
                FlowLayout {
                    ForEach(RestaurantGuide.cuisines, id: \.self) { c in
                        Chip(title: c, isSelected: c == cuisine) { cuisine = c }
                    }
                }
                if picks.isEmpty {
                    InlineNote(text: "Nothing here fits your allergies and diet. Try another cuisine.")
                } else {
                    CardList {
                        ForEach(Array(picks.enumerated()), id: \.element.name) { i, pick in
                            Button {
                                logged = pick.name
                            } label: {
                                HStack(alignment: .top, spacing: Space.sm) {
                                    Text("\(i + 1)")
                                        .textStyle(.label)
                                        .foregroundStyle(Palette.onInkFill)
                                        .frame(width: Size.checkRing + 6, height: Size.checkRing + 6)
                                        .background(Palette.inkFill, in: Circle())
                                    VStack(alignment: .leading, spacing: Space.xxs) {
                                        Text(pick.name).textStyle(.rowTitle).foregroundStyle(Palette.ink)
                                            .fixedSize(horizontal: false, vertical: true)
                                        Text("\(pick.kcal) kcal · \(pick.proteinG) g protein · \(pick.tip)")
                                            .textStyle(.caption).foregroundStyle(Palette.inkMuted)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    if logged == pick.name {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.blueText)
                                    }
                                }
                                .padding(Space.md)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Text("Order the first one you can find on the menu. Don't optimise at the table. Portions vary: these are estimates, and allergens depend on the kitchen, so always ask.")
                    .textStyle(.caption)
                    .foregroundStyle(Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Space.lg)
            .readableColumn()
        }
        .pageBackground()
        .onAppear {
            if let liked = profile.cuisines.map(\.rawValue).first(where: RestaurantGuide.cuisines.contains) { cuisine = liked }
        }
    }
}
