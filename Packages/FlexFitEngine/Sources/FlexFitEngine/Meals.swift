import Foundation

public enum MealSlot: String, Codable, Sendable, CaseIterable {
    case breakfast, lunch, snack, dinner
}

public struct Ingredient: Codable, Sendable, Hashable {
    public var name: String
    public var grams: Int
    public init(name: String, grams: Int) { self.name = name; self.grams = grams }
}

/// A recipe from the library (per-portion values as authored).
public struct Meal: Codable, Sendable, Hashable, Identifiable {
    public var id: Int
    public var slot: MealSlot
    public var name: String
    public var cuisine: String
    public var vegetarian: Bool
    public var vegan: Bool
    public var keto: Bool
    public var allergens: [Allergen]
    public var kcal: Int
    public var proteinG: Int
    public var carbsG: Int
    public var fatG: Int
    public var cookMinutes: Int
    public var rating: Double
    public var ingredients: [Ingredient]

    public enum Tag: String, Sendable { case highProtein, lowCarb, vegan, vegetarian, balanced }

    public var tag: Tag {
        if keto { return .lowCarb }
        if vegan { return .vegan }
        if Double(proteinG * 4) / Double(kcal) > 0.28 { return .highProtein }
        if vegetarian { return .vegetarian }
        return .balanced
    }

    func fits(_ diet: DietStyle) -> Bool {
        switch diet {
        case .vegetarian: vegetarian
        case .vegan: vegan
        case .keto: keto
        case .highProtein, .balanced, .intermittentFasting: true
        }
    }

    func contains(anyOf words: Set<String>) -> Bool {
        ingredients.contains { ing in words.contains { ing.name.lowercased().contains($0.lowercased()) } }
    }
}

public struct MealLibrary: Sendable {
    struct Document: Codable {
        var version: Int
        var reviewStatus: String
        var meals: [Meal]
        var substitutions: [String: String]
    }

    public let meals: [Meal]
    /// Ingredient → a similar-macro replacement ("I'm missing an ingredient").
    public let substitutions: [String: String]

    public init(meals: [Meal], substitutions: [String: String]) {
        self.meals = meals
        self.substitutions = substitutions
    }

    public subscript(id: Int) -> Meal? { meals.first { $0.id == id } }

    public static let bundled: MealLibrary = {
        guard let url = Bundle.module.url(forResource: "meals", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let doc = try? JSONDecoder().decode(Document.self, from: data)
        else { fatalError("meals.json is missing or invalid") }
        return MealLibrary(meals: doc.meals, substitutions: doc.substitutions)
    }()
}

/// A meal as served on a given day: scaled to the day's target, with any ingredient swaps applied.
public struct PlannedMeal: Sendable, Hashable, Identifiable {
    public var meal: Meal
    public var slot: MealSlot
    /// Position in the day (0-based), so the same recipe can appear twice without clashing.
    public var index: Int
    public var kcal: Int
    public var proteinG: Int
    public var carbsG: Int
    public var fatG: Int
    public var ingredients: [Ingredient]
    /// (from, to) when the user swapped an ingredient.
    public var swapped: (from: String, to: String)?
    public var id: String { "\(index)-\(meal.id)" }

    public init(meal: Meal, slot: MealSlot, index: Int, kcal: Int, proteinG: Int, carbsG: Int, fatG: Int,
                ingredients: [Ingredient], swapped: (from: String, to: String)?) {
        self.meal = meal
        self.slot = slot
        self.index = index
        self.kcal = kcal
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.ingredients = ingredients
        self.swapped = swapped
    }

    public static func == (a: PlannedMeal, b: PlannedMeal) -> Bool { a.id == b.id && a.kcal == b.kcal && a.ingredients == b.ingredients }
    public func hash(into h: inout Hasher) { h.combine(id); h.combine(kcal) }

    public var totalGrams: Int { ingredients.reduce(0) { $0 + $1.grams } }
}

public struct IngredientSwapChoice: Sendable, Hashable {
    public var mealIndex: Int
    public var from: String
    public var to: String
    public init(mealIndex: Int, from: String, to: String) { self.mealIndex = mealIndex; self.from = from; self.to = to }
}

/// Builds each day's meals from the library and the user's food answers (mock "Eat" + PRD Phase 2).
public enum MealPlanner {
    /// Candidates per slot: allergens and diet are hard filters and never relaxed; dislikes and cooking
    /// time are soft and relax only when a slot would otherwise be empty. Preferred cuisines come first.
    public static func pool(for profile: UserProfile, library: MealLibrary = .bundled) -> [MealSlot: [Meal]] {
        var result: [MealSlot: [Meal]] = [:]
        for slot in MealSlot.allCases {
            let safe = library.meals.filter {
                $0.slot == slot && $0.fits(profile.diet) && profile.allergens.isDisjoint(with: $0.allergens)
            }
            let preferred = safe.filter { meal in
                !meal.contains(anyOf: profile.dislikes) && (profile.maxCookMinutes.map { meal.cookMinutes <= $0 } ?? true)
            }
            let base = preferred.isEmpty ? safe.filter { !$0.contains(anyOf: profile.dislikes) } : preferred
            let candidates = base.isEmpty ? safe : base
            let liked = Set(profile.cuisines.map(\.rawValue))
            result[slot] = candidates.filter { liked.contains($0.cuisine) }
                + candidates.filter { !liked.contains($0.cuisine) }
        }
        return result
    }

    /// The day's meals (weekday 0 = Monday), scaled so the day totals `targetCalories`.
    public static func day(weekday: Int, profile: UserProfile, targetCalories: Int,
                           swaps: [IngredientSwapChoice] = [], library: MealLibrary = .bundled) -> [PlannedMeal] {
        let pool = pool(for: profile, library: library)
        let picks: [(Int, MealSlot, Meal)] = profile.mealPattern.slots.enumerated().compactMap { k, slot in
            guard let options = pool[slot], !options.isEmpty else { return nil }
            return (k, slot, options[(weekday * 3 + k * 2) % options.count])
        }
        let raw = picks.reduce(0) { $0 + $1.2.kcal }
        guard raw > 0 else { return [] }
        // Portions scale to the target, within sensible bounds.
        let f = min(2.0, max(0.5, Double(targetCalories) / Double(raw)))

        return picks.map { k, slot, meal in
            let swap = swaps.first { $0.mealIndex == k }
            let ingredients = meal.ingredients.map { ing in
                Ingredient(name: swap?.from == ing.name ? swap!.to : ing.name, grams: Int((Double(ing.grams) * f).rounded()))
            }
            return PlannedMeal(
                meal: meal, slot: slot, index: k,
                kcal: Int((Double(meal.kcal) * f / 5).rounded()) * 5,
                proteinG: Int((Double(meal.proteinG) * f).rounded()),
                carbsG: Int((Double(meal.carbsG) * f).rounded()),
                fatG: Int((Double(meal.fatG) * f).rounded()),
                ingredients: ingredients,
                swapped: swap.map { ($0.from, $0.to) }
            )
        }
    }

    /// The replacement for a missing ingredient, if the library has one.
    public static func substitute(for ingredient: String, library: MealLibrary = .bundled) -> String? {
        library.substitutions[ingredient]
    }

    /// A replacement this user can actually eat: never one carrying their allergens or breaking their diet.
    public static func safeSubstitute(for ingredient: String, profile: UserProfile,
                                      library: MealLibrary = .bundled) -> String? {
        guard let sub = library.substitutions[ingredient] else { return nil }
        guard profile.allergens.isDisjoint(with: IngredientRules.allergens(in: sub)) else { return nil }
        switch profile.diet {
        case .vegan where !IngredientRules.isVegan(sub): return nil
        case .vegetarian where IngredientRules.isMeatOrFish(sub): return nil
        default: return sub
        }
    }
}

/// Conservative keyword rules for single ingredient names (used where a recipe's tags don't apply,
/// e.g. a swapped-in ingredient). Mirrors how meals.json allergens were derived.
public enum IngredientRules {
    static let allergenWords: [Allergen: [String]] = [
        .dairy: ["yoghurt", "paneer", "feta", "ghee", "whey", "curd", "skyr", "cheese", "cheddar", "parmesan",
                 "halloumi", "labneh", "tzatziki", "buttermilk", "cottage"],
        .gluten: ["sourdough", "rye", "pita", "roti", "tortilla", "oat", "bread", "wheat", "bagel", "bulgur",
                  "semolina", "soba", "pasta", "panko", "cracker", "granola"],
        .eggs: ["egg"],
        .soy: ["tofu", "soy", "edamame"],
        .fish: ["salmon", "tuna", "fish", "mackerel"],
        .shellfish: ["prawn", "shrimp"],
        .sesame: ["sesame", "hummus", "tahini"],
        .treeNuts: ["coconut", "almond", "cashew", "walnut"],
        .peanuts: ["peanut"],
    ]

    public static func allergens(in name: String) -> Set<Allergen> {
        let n = name.lowercased()
        var result = Set(allergenWords.filter { $0.value.contains(where: n.contains) }.keys)
        // Butter is dairy; nut butters aren't.
        if n.contains("butter") && !["peanut", "almond", "nut"].contains(where: n.contains) { result.insert(.dairy) }
        // Plain milk is dairy; plant milks aren't (soy milk is caught as soy above).
        if n.contains("milk") && !["soy", "oat", "almond", "coconut"].contains(where: n.contains) { result.insert(.dairy) }
        return result
    }

    public static func isMeatOrFish(_ name: String) -> Bool {
        let n = name.lowercased()
        return ["chicken", "beef", "sirloin", "lamb", "pork", "salmon", "tuna", "fish", "prawn", "shrimp"].contains(where: n.contains)
    }

    public static func isVegan(_ name: String) -> Bool {
        let n = name.lowercased()
        if isMeatOrFish(n) || n.contains("egg") || n.contains("honey") { return false }
        return !allergens(in: n).contains(.dairy)
    }
}
