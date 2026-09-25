import SwiftUI
import SwiftData
import FlexFitEngine

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
                    .overlay { Image(planned.slot.illustration).resizable().scaledToFill() }
                    .frame(width: Size.mealThumb.width, height: Size.mealThumb.height)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: Space.xs) {
                    Button(action: onOpen) {
                        VStack(alignment: .leading, spacing: Space.xs - 2) {
                            Text("\(planned.slot.title) · \(planned.slot.clock)")
                                .textStyle(.micro)
                                .foregroundStyle(Palette.inkMuted)
                            Text(planned.meal.name)
                                .textStyle(.rowTitle)
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
                .textStyle(accent ? .rowTitle : .label)
                .foregroundStyle(accent ? Palette.copperText : Palette.ink)
            Text(label)
                .textStyle(.micro)
                .foregroundStyle(Palette.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                    .textStyle(.title2)
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
                        .textStyle(.chip)
                        .foregroundStyle(Palette.white)
                        .padding(.horizontal, Space.md - 2)
                        .padding(.vertical, Space.sm - 2)
                        .background(Palette.navy, in: Capsule())
                }
                .buttonStyle(PressableStyle())
                .padding(.top, Space.sm + 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Circle()
                .fill(Palette.white.opacity(0.4))
                .overlay { Image(planned.slot.illustration).resizable().scaledToFill() }
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

// MARK: - Meal detail

struct MealDetailView: View {
    let planned: PlannedMeal
    let isEaten: Bool
    let onToggleEaten: () -> Void
    let onMissingIngredient: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRouter.self) private var router
    @Query private var saved: [SavedMeal]

    private var isSaved: Bool { saved.contains { $0.mealID == planned.meal.id } }

    var body: some View {
        VStack(spacing: 0) {
            // The mock's top bar: back · slot · bookmark.
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(TextStyle.rowTitle.font)
                        .foregroundStyle(Palette.ink)
                        .frame(width: Size.avatar + 2, height: Size.avatar + 2)
                        .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.sm))
                        .cardShadow()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
                Spacer()
                Text("\(planned.slot.title) · \(planned.slot.clock)")
                    .textStyle(.kicker)
                    .foregroundStyle(Palette.inkMuted)
                Spacer()
                Button(action: toggleSaved) {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .font(TextStyle.rowTitle.font)
                        .foregroundStyle(Palette.copperText)
                        .frame(width: Size.avatar + 2, height: Size.avatar + 2)
                        .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.sm))
                        .cardShadow()
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isSaved ? "Remove from saved meals" : "Save meal")
            }
            .padding(.horizontal, Space.lg)
            .padding(.top, Space.md)
            .readableColumn()

            ScrollView {
                VStack(spacing: 0) {
                    IngredientFlower(planned: planned)
                        .padding(.top, Space.xs)

                    Text(planned.meal.name)
                        .textStyle(.title1)
                        .foregroundStyle(Palette.ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text("\(planned.totalGrams) g · \(planned.kcal) kcal · \(planned.meal.cookMinutes) min")
                        .textStyle(.chip)
                        .foregroundStyle(Palette.inkMuted)
                        .padding(.top, Space.xs + 1)

                    HStack(spacing: 0) {
                        macro("\(planned.proteinG)g", "Protein", color: Palette.blueText)
                        Rectangle().fill(Palette.hairline).frame(width: 1)
                        macro("\(planned.carbsG)g", "Carbs", color: Palette.copperText)
                        Rectangle().fill(Palette.hairline).frame(width: 1)
                        macro("\(planned.fatG)g", "Fat", color: Palette.blueText)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, Space.md - 1)
                    .background(Palette.card, in: RoundedRectangle(cornerRadius: Radius.md))
                    .cardShadow()
                    .padding(.top, Space.lg)

                    CardList {
                        ForEach(planned.ingredients, id: \.name) { ingredient in
                            IngredientRow(ingredient: ingredient, planned: planned)
                        }
                    }
                    .padding(.top, Space.md - 2)

                    if !allergens.isEmpty {
                        InlineNote(text: "Contains \(allergens.map { $0.title.lowercased() }.sorted().joined(separator: ", ")). Always check labels.",
                                   systemImage: "exclamationmark.triangle")
                            .padding(.top, Space.md - 2)
                    }

                    PrimaryButton(title: "I’m missing an ingredient", showsArrow: false, action: onMissingIngredient)
                        .padding(.top, Space.md)
                    Button(action: onToggleEaten) {
                        Label(isEaten ? "Logged — tap to undo" : "Log as eaten", systemImage: isEaten ? "checkmark" : "plus")
                            .textStyle(.chip)
                            .foregroundStyle(Palette.ink)
                            .frame(maxWidth: .infinity, minHeight: Size.button)
                            .overlay(Capsule().strokeBorder(Palette.track))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, Space.sm)
                }
                .padding(.horizontal, Space.lg)
                .padding(.bottom, Space.xl)
                .readableColumn()
            }
        }
        .pageBackground()
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

    private func macro(_ value: String, _ label: String, color: Color) -> some View {
        VStack(spacing: Space.xs - 2) {
            Text(value).textStyle(.headline).foregroundStyle(Palette.ink)
            Text(label).textStyle(.micro).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// The mock's "flower": one petal per ingredient (up to 6), labelled with its share of the dish by weight.
private struct IngredientFlower: View {
    let planned: PlannedMeal

    private var items: [Ingredient] { Array(planned.ingredients.prefix(6)) }
    private var total: Int { max(1, items.reduce(0) { $0 + $1.grams }) }

    var body: some View {
        ZStack {
            ForEach(items.indices, id: \.self) { i in
                Petal(angle: angle(i))
            }
            ForEach(items.indices, id: \.self) { i in
                PetalLabel(ingredient: items[i], share: Double(items[i].grams) / Double(total), angle: angle(i))
            }
            Circle()
                .fill(Palette.white)
                .overlay { Image(planned.slot.illustration).resizable().scaledToFill() }
                .frame(width: Size.mealHero, height: Size.mealHero)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Palette.white, lineWidth: 4))
                .shadow(color: Palette.navy.opacity(0.14), radius: 11, y: 8)
        }
        .frame(height: Size.mealHero * 3.2)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(items.map { "\($0.name) \($0.grams) grams" }.joined(separator: ", "))
    }

    private func angle(_ i: Int) -> Double { Double(i) * 360 / Double(max(1, items.count)) }
}

private struct Petal: View {
    let angle: Double

    var body: some View {
        RoundedRectangle(cornerRadius: Radius.lg)
            .fill(RadialGradient(colors: [Palette.copper, Palette.sand, Palette.iceLight, Palette.white],
                                 center: UnitPoint(x: 0.5, y: 0.84), startRadius: 0, endRadius: 90))
            .frame(width: Size.mealHero + 4, height: Size.mealHero * 1.5)
            .offset(y: -Size.mealHero * 0.76)
            .rotationEffect(.degrees(angle))
    }
}

private struct PetalLabel: View {
    let ingredient: Ingredient
    let share: Double
    let angle: Double

    var body: some View {
        let radians = (angle - 90) * .pi / 180
        let radius = Size.mealHero * 1.18
        VStack(spacing: Space.xxs) {
            Text("\(Int((share * 100).rounded()))%")
                .textStyle(.statValue)
                .foregroundStyle(Palette.navy)
            Text(ingredient.name)
                .textStyle(.micro)
                .foregroundStyle(Palette.navy.opacity(0.7))
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(width: Size.mealThumb.width)
        .offset(x: cos(radians) * radius, y: sin(radians) * radius)
    }
}

/// Grams and share of the dish by weight. No per-ingredient macros: the library has dish-level
/// nutrition only, and splitting it by weight would be wrong (eggs don't carry the bread's carbs).
private struct IngredientRow: View {
    let ingredient: Ingredient
    let planned: PlannedMeal

    var body: some View {
        let share = Double(ingredient.grams) / Double(max(1, planned.totalGrams))
        HStack(spacing: Space.sm + 1) {
            Text("\(Int((share * 100).rounded()))%")
                .textStyle(.label)
                .foregroundStyle(Palette.navy)
                .frame(width: Size.avatar + 2, height: Size.avatar + 2)
                .background(LinearGradient(colors: [Palette.sand, Palette.iceLight], startPoint: .topLeading, endPoint: .bottomTrailing),
                            in: RoundedRectangle(cornerRadius: Radius.sm))
            Text(ingredient.name)
                .textStyle(.rowTitle)
                .foregroundStyle(Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(ingredient.grams) g")
                .textStyle(.caption)
                .foregroundStyle(Palette.inkMuted)
        }
        .padding(.horizontal, Space.md)
        .padding(.vertical, Space.sm)
        .accessibilityElement(children: .combine)
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
