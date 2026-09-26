import SwiftUI
import SwiftData
import FlexFitEngine

/// Groceries (mock "7 days ahead"): Restaurant mode on top, then this week's list aggregated
/// from all 7 days of meals, with a pantry the list skips.
struct GroceryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router
    @Query private var profiles: [ProfileRecord]
    @Query(sort: \WeeklyTargets.weekOf) private var weekly: [WeeklyTargets]
    @Query private var swaps: [IngredientSwapRecord]
    @Query private var checks: [GroceryCheck]
    @Query(sort: \PantryItem.name) private var pantry: [PantryItem]
    @Query private var logs: [DailyLog]
    @Query private var foodEntries: [FoodEntry]

    var body: some View {
        if let record = profiles.first {
            let profile = record.profile()
            MockSheet(kicker: "7 days ahead", title: "Groceries") {
                content(profile)
            }
            .presentationDetents([.large])
        }
    }

    @ViewBuilder
    private func content(_ profile: UserProfile) -> some View {
        let context = MealPlanContext(profile: profile, targets: TargetsStore.current(weekly, profile: profile), swaps: swaps)
        let monday = Week.start(of: .now)
        let days = (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: monday) }
        let items = GroceryList.build(from: days.map { context.meals(on: $0) })
        let pantryNames = Set(pantry.map(\.name))
        let needed = items.filter { !pantryNames.contains($0.name) }
        let checked = Set(checks.filter { $0.weekOf == monday }.map(\.name))
        let left = needed.filter { !checked.contains($0.name) }.count
        let kcalLeft = DayIntake(context: context, date: .now, logs: logs, entries: foodEntries).kcalLeft

        Button {
            dismiss()
            Task { @MainActor in try? await Task.sleep(for: .milliseconds(450)); router.isRestaurantPresented = true }
        } label: {
            HStack(spacing: Space.md - 2) {
                VStack(alignment: .leading, spacing: Space.xs - 2) {
                    Text("Restaurant mode").textStyle(.statValue).foregroundStyle(Palette.onPanel)
                    Text("Order well with \(Formatters.kcal(max(0, kcalLeft))) kcal left today")
                        .textStyle(.caption).foregroundStyle(Palette.onPanelMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "arrow.right")
                    .font(TextStyle.button.font)
                    .foregroundStyle(Palette.navy)
                    .frame(width: Size.control, height: Size.control)
                    .background(Palette.copper, in: Circle())
            }
            .padding(.horizontal, Space.lg)
            .padding(.vertical, Space.lg - 2)
            .background(Palette.panel, in: RoundedRectangle(cornerRadius: Radius.lg))
        }
        .buttonStyle(PressableStyle())

        VStack(alignment: .leading, spacing: Space.xxs) {
            HStack(alignment: .firstTextBaseline) {
                Text("This week’s list").textStyle(.headline).foregroundStyle(Palette.ink)
                Spacer()
                Text("\(left) left").textStyle(.label).foregroundStyle(Palette.copperText)
            }
            Text("Aggregated from all 7 days of your meal plan. \(budgetNote(profile.budget)) Shopping day: \(profile.shopDay.title.lowercased()).")
                .textStyle(.caption).foregroundStyle(Palette.inkMuted).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, Space.sm)

        ForEach(GroceryCategory.allCases, id: \.self) { category in
            let rows = needed.filter { $0.category == category }
            if !rows.isEmpty {
                VStack(alignment: .leading, spacing: Space.xs + 1) {
                    Text(category.title).textStyle(.kicker).foregroundStyle(Palette.inkMuted)
                    CardList {
                        ForEach(rows, id: \.name) { item in
                            GroceryRow(item: item, isChecked: checked.contains(item.name),
                                       onToggle: { toggle(item.name, week: monday) },
                                       onPantry: {
                                           modelContext.insert(PantryItem(name: item.name))
                                           try? modelContext.save()
                                           router.toast("\(item.name) moved to your pantry.")
                                       })
                        }
                    }
                }
            }
        }

        if !pantry.isEmpty {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("In your pantry").textStyle(.kicker).foregroundStyle(Palette.inkMuted)
                Text("Left off the list. Tap to add back.").textStyle(.caption).foregroundStyle(Palette.inkMuted)
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
        case .tight: "Tight budget: buy staples in bulk and batch-cook grains and dals."
        case .moderate: "Frozen veg and pre-cooked grains are fine where they save time."
        case .comfortable: "Buy whatever makes the macros easiest."
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
                HStack(spacing: Space.sm + 1) {
                    // The mock's rounded-square checkbox.
                    RoundedRectangle(cornerRadius: Radius.xs - 1)
                        .fill(isChecked ? Palette.inkFill : Color.clear)
                        .overlay(RoundedRectangle(cornerRadius: Radius.xs - 1).strokeBorder(isChecked ? Color.clear : Palette.track, lineWidth: 1.5))
                        .overlay { if isChecked { Image(systemName: "checkmark").font(TextStyle.micro.font.weight(.heavy)).foregroundStyle(Palette.onInkFill) } }
                        .frame(width: Size.checkRing, height: Size.checkRing)
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
        .padding(.vertical, Space.sm + 1)
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

/// "Eating out tonight" (mock "Restaurant mode"): three safe orders for what's left today.
/// Tapping one logs it in place of dinner.
struct RestaurantSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Query private var profiles: [ProfileRecord]
    @Query(sort: \WeeklyTargets.weekOf) private var weekly: [WeeklyTargets]
    @Query private var logs: [DailyLog]
    @Query private var swaps: [IngredientSwapRecord]
    @Query private var foodEntries: [FoodEntry]
    @State private var cuisine = RestaurantGuide.cuisines.first ?? ""

    var body: some View {
        if let record = profiles.first {
            let profile = record.profile()
            let left = remaining(profile)
            MockSheet(kicker: "Restaurant mode", title: "Order without guessing",
                      subtitle: "You have \(Formatters.kcal(max(0, left.kcal))) kcal and \(max(0, left.protein)) g protein left today.",
                      footer: "Order the first one you can find on the menu. Don’t optimise at the table. These are estimates, and allergens depend on the kitchen: always ask.") {
                FlowLayout {
                    ForEach(RestaurantGuide.cuisines, id: \.self) { c in
                        Chip(title: c, isSelected: c == cuisine) { cuisine = c }
                    }
                }
                let picks = RestaurantGuide.picks(cuisine: cuisine, profile: profile, kcalLeft: left.kcal)
                if picks.isEmpty {
                    InlineNote(text: "Nothing here fits your allergies and diet. Try another cuisine.")
                } else {
                    CardList {
                        ForEach(Array(picks.enumerated()), id: \.element.name) { i, pick in
                            SheetRow(badge: "\(i + 1)", title: pick.name,
                                     subtitle: "\(pick.kcal) kcal · \(pick.proteinG) g protein · \(pick.tip)") {
                                log(pick)
                            }
                        }
                    }
                }
            }
            .presentationDetents([.large])
            .onAppear {
                if let liked = profile.cuisines.map(\.rawValue).first(where: RestaurantGuide.cuisines.contains) { cuisine = liked }
            }
        }
    }

    private func remaining(_ profile: UserProfile) -> (kcal: Int, protein: Int) {
        let context = MealPlanContext(profile: profile, targets: TargetsStore.current(weekly, profile: profile), swaps: swaps)
        let intake = DayIntake(context: context, date: .now, logs: logs, entries: foodEntries)
        return (intake.kcalLeft, intake.proteinLeft)
    }

    private func log(_ pick: RestaurantPick) {
        // One restaurant dinner per day: a new pick replaces the previous one.
        for old in foodEntries where old.replacesDinner && Calendar.current.isDateInToday(old.day) { modelContext.delete(old) }
        let entry = FoodEntry(day: .now, name: pick.name)
        entry.kcal = pick.kcal
        entry.proteinG = Double(pick.proteinG)
        entry.source = "restaurant"
        entry.category = cuisine
        entry.replacesDinner = true
        modelContext.insert(entry)
        try? modelContext.save()
        dismiss()
        router.toast("Logged \(cuisine) — dinner adjusted.")
    }
}
