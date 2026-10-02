import SwiftUI
import SwiftData
import FlexFitEngine

// MARK: - Cheat days

/// The day's cheat note: the whole day at a higher target, or a free meal in place of dinner.
struct CheatDayBanner: View {
    let day: CalorieWeek.Day
    let proteinG: Int
    var isToday = true

    var body: some View {
        if let cheat = day.cheat {
            InlineNote(text: text(cheat), systemImage: "birthday.cake")
        }
    }

    private func text(_ cheat: CheatDays.Style) -> String {
        switch cheat {
        case .day:
            "\(isToday ? "Today is" : "It's") your cheat day: about \(Formatters.kcal(day.calories)) kcal, so enjoy it. "
                + "Keep protein near \(proteinG) g; the meals below are only suggestions."
        case .meal:
            "Cheat meal \(isToday ? "tonight" : "that evening"): about \(Formatters.kcal(day.cheatMealKcal ?? 0)) kcal for anything "
                + "you like, in place of dinner. The rest of the day runs as planned."
        }
    }
}

/// The free meal that stands in for dinner on a cheat-meal day.
struct CheatMealCard: View {
    let kcal: Int

    var body: some View {
        HStack(alignment: .top, spacing: Space.sm + 1) {
            Image(systemName: "birthday.cake")
                .font(TextStyle.headline.font)
                .foregroundStyle(Palette.copperText)
                .frame(width: Size.mealThumb.width, height: Size.mealThumb.height)
                .background(Palette.copperTint, in: RoundedRectangle(cornerRadius: Radius.sm))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.xs - 2) {
                Text("Cheat meal · \(MealMoment.dinner.clock)")
                    .textStyle(.micro)
                    .foregroundStyle(Palette.inkMuted)
                Text("Your free meal")
                    .textStyle(.mealName)
                    .foregroundStyle(Palette.ink)
                Text("About \(Formatters.kcal(kcal)) kcal — anything you like. Log it with the scanner or Restaurant mode so the day stays honest.")
                    .textStyle(.caption)
                    .foregroundStyle(Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Space.md)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Meal card (Eat day list)

struct MealCard: View {
    let planned: PlannedMeal
    let isEaten: Bool
    let onOpen: () -> Void
    let onSwap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Space.sm + 1) {
            Button(action: onOpen) {
                Rectangle().fill(Palette.page)
                    .overlay { Image(planned.meal.picture).resizable().scaledToFill() }
                    .frame(width: Size.mealThumb.width, height: Size.mealThumb.height)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: Space.xs) {
                    Button(action: onOpen) {
                        VStack(alignment: .leading, spacing: Space.xs - 2) {
                            Text("\(planned.moment.title) · \(planned.moment.clock)")
                                .textStyle(.micro)
                                .foregroundStyle(Palette.inkMuted)
                            Text(planned.meal.name)
                                .textStyle(.mealName)
                                .foregroundStyle(Palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Button(action: onSwap) {
                        Image(systemName: "ellipsis")
                            .rotationEffect(.degrees(90))
                            .font(TextStyle.label.font)
                            .foregroundStyle(Palette.inkMuted)
                            .frame(width: Size.checkRing + 6, height: Size.checkRing + 6)
                            .background(Palette.page, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Swap an ingredient in \(planned.meal.name)")
                }

                HStack(spacing: 0) {
                    macro("\(planned.kcal)", "kcal", accent: true)
                    divider
                    macro("\(planned.proteinG)g", "Protein")
                    divider
                    macro("\(planned.carbsG)g", "Carbs")
                    divider
                    macro("\(planned.fatG)g", "Fat")
                }
                .padding(.top, Space.sm - 1)

                HStack(spacing: Space.xs - 1) {
                    Text("★ \(planned.meal.rating.formatted(.number.precision(.fractionLength(1))))")
                        .textStyle(.micro)
                        .foregroundStyle(Palette.ink)
                    MealTagPill(tag: planned.meal.tag)
                    Text("\(planned.meal.cookMinutes) min · \(planned.meal.cuisine)")
                        .textStyle(.micro)
                        .foregroundStyle(Palette.inkMuted)
                    if isEaten {
                        Label("Eaten", systemImage: "checkmark")
                            .textStyle(.micro)
                            .foregroundStyle(Palette.blueText)
                    }
                }
                .padding(.top, Space.sm - 2)

                if let swap = planned.swapped {
                    Label("\(swap.from) → \(swap.to), similar macros", systemImage: "arrow.triangle.2.circlepath")
                        .textStyle(.micro)
                        .foregroundStyle(Palette.blueText)
                        .padding(.top, Space.xs)
                }
            }
        }
        .padding(Space.md - 2)
        .accessibilityElement(children: .contain)
    }

    private var divider: some View {
        Rectangle().fill(Palette.hairline).frame(width: 1, height: Space.xl)
    }

    private func macro(_ value: String, _ label: String, accent: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            Text(value)
                .textStyle(accent ? .mealName : .macroValue)
                .foregroundStyle(accent ? Palette.copperText : Palette.ink)
                .lineLimit(1)
            Text(label)
                .textStyle(.tiny)
                .foregroundStyle(Palette.inkMuted)
        }
        // Mock: the kcal column is a touch wider (flex 1.1 vs 1).
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(accent ? 1 : 0)
        .padding(.leading, accent ? 0 : Space.xs)
        .accessibilityElement(children: .combine)
    }
}

struct MealTagPill: View {
    let tag: Meal.Tag

    var body: some View {
        Text(tag.title)
            .textStyle(.micro)
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(fg)
            .padding(.horizontal, Space.xs)
            .padding(.vertical, Space.xxs + 1)
            .background(bg, in: Capsule())
    }

    private var fg: Color {
        switch tag {
        case .highProtein: Palette.copperText
        case .balanced: Palette.inkMuted
        default: Palette.blueText
        }
    }

    private var bg: Color {
        switch tag {
        case .highProtein: Palette.copperTint
        case .balanced: Palette.hairline
        default: Palette.blueTint
        }
    }
}

// MARK: - Picked for you

/// Fixed peach surface with fixed dark content (reads the same in both appearances).
struct PickedForYouCard: View {
    let planned: PlannedMeal
    let kcalLeft: Int
    let diet: DietStyle
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: Space.md - 2) {
            VStack(alignment: .leading, spacing: 0) {
                Text("✦ Picked for you")
                    .textStyle(.micro)
                    .foregroundStyle(Palette.copperInk)
                Text(planned.meal.name)
                    .textStyle(.cardTitle)
                    .foregroundStyle(Palette.navy)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Space.xs + 1)
                Text("Fits your \(Formatters.kcal(max(0, kcalLeft))) kcal left and \(diet.title.lowercased()) style.")
                    .textStyle(.caption)
                    .foregroundStyle(Palette.navy.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, Space.xs - 2)
                Button(action: onOpen) {
                    Text("View meal")
                        .textStyle(.pill)
                        .foregroundStyle(Palette.white)
                        .padding(.horizontal, Space.md - 2)
                        .padding(.vertical, Space.sm)
                        .background(Palette.navy, in: Capsule())
                }
                .buttonStyle(PressableStyle())
                .padding(.top, Space.sm + 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Circle()
                .fill(Palette.white.opacity(0.4))
                .overlay { Image(planned.meal.picture).resizable().scaledToFill() }
                .frame(width: Size.mealHero + 4, height: Size.mealHero + 4)
                .clipShape(Circle())
                .accessibilityHidden(true)
        }
        .padding(Space.lg - 2)
        .background(
            LinearGradient(colors: [Palette.peach, Palette.peachDeep], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: Radius.lg)
        )
    }
}

// MARK: - Meal detail (reference design)

struct MealDetailView: View {
    let planned: PlannedMeal
    let isEaten: Bool
    let onToggleEaten: () -> Void
    let onMissingIngredient: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var saved: [SavedMeal]

    private var isSaved: Bool { saved.contains { $0.mealID == planned.meal.id } }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack {
                    squareButton(systemImage: "chevron.left", tint: Palette.ink, label: "Back") { dismiss() }
                    Spacer()
                    squareButton(systemImage: isSaved ? "bookmark.fill" : "bookmark", tint: Palette.amber,
                                 label: isSaved ? "Remove from saved meals" : "Save meal", action: toggleSaved)
                }
                .padding(.horizontal, Space.lg)
                .padding(.top, Space.md)

                IngredientFlower(planned: planned)
                    .padding(.top, Space.xs)

                Text(planned.meal.name)
                    .textStyle(.title1)
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, Space.lg)
                    .accessibilityAddTraits(.isHeader)
                Text("\(planned.totalGrams) g")
                    .textStyle(.title2)
                    .foregroundStyle(Palette.inkMuted)
                    .padding(.top, Space.xxs)
                    .padding(.bottom, Space.xl)

                IngredientCard(planned: planned, isEaten: isEaten, allergens: allergens,
                               onMissingIngredient: onMissingIngredient, onToggleEaten: onToggleEaten)
            }
            .readableColumn()
        }
        .background(Palette.canvas.ignoresSafeArea())
        .scrollBounceBehavior(.basedOnSize)
    }

    private func squareButton(systemImage: String, tint: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(TextStyle.headline.font)
                .foregroundStyle(tint)
                .frame(width: Size.detailButton, height: Size.detailButton)
                .background(Palette.card.opacity(0.7), in: RoundedRectangle(cornerRadius: Radius.tile - 4))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// The recipe's tags plus anything a swapped-in ingredient brings (conservative: nothing is removed).
    private var allergens: Set<Allergen> {
        Set(planned.meal.allergens).union(planned.swapped.map { IngredientRules.allergens(in: $0.to) } ?? [])
    }

    private func toggleSaved() {
        if let existing = saved.first(where: { $0.mealID == planned.meal.id }) {
            modelContext.delete(existing)
        } else {
            // The filled bookmark is the confirmation; a toast would sit hidden behind this sheet.
            modelContext.insert(SavedMeal(mealID: planned.meal.id))
        }
        try? modelContext.save()
    }
}

/// One petal per ingredient (up to 6) around the dish, labelled with its share of the dish by weight.
/// Petals are rounded wedges that fill the circle, split by thin white seams, with one warm-to-green-to-white
/// gradient centred on the dish (reference design).
private struct IngredientFlower: View {
    let planned: PlannedMeal

    private var items: [Ingredient] { Array(planned.ingredients.sorted { $0.grams > $1.grams }.prefix(6)) }
    private var total: Int { max(1, planned.totalGrams) }

    var body: some View {
        let count = max(3, items.count)
        GeometryReader { geo in
            let d = min(geo.size.width - Space.md * 2, Size.flower)
            let r = d / 2
            let center = CGPoint(x: geo.size.width / 2, y: r)
            ZStack {
                ForEach(items.indices, id: \.self) { i in
                    let start = Double(i) / Double(count) * 360 - 90 - 180 / Double(count)
                    let end = start + 360 / Double(count)
                    PetalWedge(center: center, radius: r, start: start, end: end)
                        .fill(RadialGradient(stops: [
                            .init(color: Palette.petalCore, location: 0.30),
                            .init(color: Palette.petalWarm, location: 0.46),
                            .init(color: Palette.petalGreen, location: 0.66),
                            .init(color: Palette.white, location: 0.93),
                        ], center: UnitPoint(x: center.x / geo.size.width, y: 0.5), startRadius: 0, endRadius: r))
                    PetalWedge(center: center, radius: r, start: start, end: end)
                        .stroke(Palette.white, lineWidth: 3)
                        // The reference's soft white bloom at the rim.
                        .shadow(color: Palette.white.opacity(0.9), radius: 6)
                    let mid = (start + end) / 2 * .pi / 180
                    PetalLabel(ingredient: items[i], share: Double(items[i].grams) / Double(total))
                        .position(x: center.x + cos(mid) * r * 0.64, y: center.y + sin(mid) * r * 0.64)
                }
                Circle()
                    .fill(Palette.white)
                    .frame(width: r * 0.6, height: r * 0.6)
                    .overlay {
                        Image(planned.meal.picture)
                            .resizable()
                            .scaledToFill()
                            .frame(width: r * 0.5, height: r * 0.5)
                            .clipShape(Circle())
                    }
                    .shadow(color: Palette.navy.opacity(0.12), radius: 8, y: 4)
                    .position(center)
            }
            .frame(width: geo.size.width, height: d)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: Size.flower + Space.md * 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(items.map { "\($0.name), \((Double($0.grams) / Double(total)).formatted(.percent.precision(.fractionLength(1))))" }
            .joined(separator: "; "))
    }
}

/// A petal: straight seams out from the centre, then one smooth rounded lobe across the rim.
private struct PetalWedge: Shape {
    let center: CGPoint
    let radius: CGFloat
    let start: Double
    let end: Double

    func path(in rect: CGRect) -> Path {
        func point(_ degrees: Double, _ r: CGFloat) -> CGPoint {
            let a = degrees * .pi / 180
            return CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r)
        }
        // Shoulders sit inside the rim; the control points pull the lobe out to it.
        let shoulder = radius * 0.72
        var p = Path()
        p.move(to: center)
        p.addLine(to: point(start, shoulder))
        p.addCurve(to: point(end, shoulder),
                   control1: point(start, radius * 1.3),
                   control2: point(end, radius * 1.3))
        p.closeSubpath()
        return p
    }
}

/// Petals are a fixed light surface, so their labels are fixed navy.
private struct PetalLabel: View {
    let ingredient: Ingredient
    let share: Double

    var body: some View {
        VStack(spacing: Space.xxs) {
            Text(share.formatted(.percent.precision(.fractionLength(1))))
                .textStyle(.headline)
                .foregroundStyle(Palette.navy)
            Text(ingredient.name)
                .textStyle(.caption)
                .foregroundStyle(Palette.navy.opacity(0.6))
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(width: Size.ingredientTile)
    }
}

/// The white card of ingredients: pastel tile, name, grams, and carbs / fat / protein chips.
private struct IngredientCard: View {
    let planned: PlannedMeal
    let isEaten: Bool
    let allergens: Set<Allergen>
    let onMissingIngredient: () -> Void
    let onToggleEaten: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.md + 2) {
            ForEach(planned.ingredients, id: \.name) { ingredient in
                IngredientRow(ingredient: ingredient)
            }

            HStack(spacing: Space.xs) {
                Text("Total").textStyle(.label).foregroundStyle(Palette.inkMuted)
                Spacer()
                Text("\(planned.kcal) kcal").textStyle(.label).foregroundStyle(Palette.ink)
                MacroChip(kind: .carbs, grams: Double(planned.carbsG))
                MacroChip(kind: .fat, grams: Double(planned.fatG))
                MacroChip(kind: .protein, grams: Double(planned.proteinG))
            }
            .padding(.top, Space.xs)

            if !allergens.isEmpty {
                InlineNote(text: "Contains \(allergens.map { $0.title.lowercased() }.sorted().joined(separator: ", ")). Always check labels.",
                           systemImage: "exclamationmark.triangle")
            }

            PrimaryButton(title: "I’m missing an ingredient", showsArrow: false, action: onMissingIngredient)
            Button(action: onToggleEaten) {
                Label(isEaten ? "Logged — tap to undo" : "Log as eaten", systemImage: isEaten ? "checkmark" : "plus")
                    .textStyle(.chip)
                    .foregroundStyle(Palette.ink)
                    .frame(maxWidth: .infinity, minHeight: Size.button)
                    .overlay(Capsule().strokeBorder(Palette.track))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Space.lg)
        .padding(.top, Space.xl)
        .padding(.bottom, Space.xxl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.card, in: UnevenRoundedRectangle(topLeadingRadius: Radius.sheet, topTrailingRadius: Radius.sheet))
    }
}

private struct IngredientRow: View {
    let ingredient: Ingredient

    var body: some View {
        let entry = NutritionTable.bundled[ingredient.name]
        let macros = ingredient.macros
        HStack(alignment: .center, spacing: Space.md) {
            Text(entry?.emoji ?? "🥣")
                .font(TextStyle.display.font)
                .frame(width: Size.ingredientTile, height: Size.ingredientTile)
                .background(tile(entry?.tone), in: RoundedRectangle(cornerRadius: Radius.tile))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text(ingredient.name)
                        .textStyle(.ingredientName)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(2)
                    Spacer(minLength: Space.xs)
                    Text("\(ingredient.grams) g")
                        .textStyle(.rowTitle)
                        .foregroundStyle(Palette.inkMuted)
                }
                if let macros {
                    HStack(spacing: Space.xs - 2) {
                        MacroChip(kind: .carbs, grams: macros.carbsG)
                        MacroChip(kind: .fat, grams: macros.fatG)
                        MacroChip(kind: .protein, grams: macros.proteinG)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func tile(_ tone: String?) -> Color {
        switch tone {
        case "green": Palette.tileGreen
        case "peach": Palette.tilePeach
        case "blue": Palette.tileBlue
        default: Palette.tileSand
        }
    }
}

struct MacroChip: View {
    enum Kind { case carbs, fat, protein }
    let kind: Kind
    let grams: Double

    var body: some View {
        HStack(spacing: Space.xxs) {
            Image(systemName: icon)
                .font(TextStyle.micro.font)
                .foregroundStyle(color)
            Text(value)
                .textStyle(.micro)
                .foregroundStyle(Palette.ink)
                .monospacedDigit()
        }
        .padding(.horizontal, Space.sm - 2)
        .padding(.vertical, Space.xs - 2)
        .background(Palette.chipFill, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name) \(value)")
    }

    /// 0.3 g under ten grams, whole grams above.
    private var value: String {
        (grams < 10 ? grams.formatted(.number.precision(.fractionLength(1))) : grams.formatted(.number.precision(.fractionLength(0)))) + " g"
    }

    private var icon: String {
        switch kind { case .carbs: "leaf.fill"; case .fat: "drop.fill"; case .protein: "cube.fill" }
    }
    private var color: Color {
        switch kind { case .carbs: Palette.carbGreen; case .fat: Palette.fatOrange; case .protein: Palette.proteinRed }
    }
    private var name: String {
        switch kind { case .carbs: "Carbs"; case .fat: "Fat"; case .protein: "Protein" }
    }
}

// MARK: - Ingredient swap

struct IngredientSwapSheet: View {
    let planned: PlannedMeal
    let profile: UserProfile
    let onSwap: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        MockSheet(kicker: "Ingredient swap", title: "What are you missing?",
                  subtitle: "\(planned.meal.name) — tap what you don’t have. The swap keeps the macros close.") {
            CardList {
                ForEach(Array(planned.ingredients.enumerated()), id: \.element.name) { i, ing in
                    let letter = String(UnicodeScalar(UInt8(65 + i)))
                    if let sub = MealPlanner.safeSubstitute(for: ing.name, profile: profile) {
                        SheetRow(badge: letter, title: ing.name, subtitle: "Swap for \(sub)") {
                            onSwap(ing.name, sub)
                            dismiss()
                        }
                    } else {
                        SheetRow(badge: letter, title: ing.name,
                                 subtitle: MealPlanner.substitute(for: ing.name) == nil ? "No swap listed" : "No safe swap for your allergies or diet") {}
                            .disabled(true)
                            .opacity(0.6)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
