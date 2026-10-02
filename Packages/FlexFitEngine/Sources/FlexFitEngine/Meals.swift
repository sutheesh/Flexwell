import Foundation

/// The kind of recipe: what a meal in the library is written for.
public enum MealSlot: String, Codable, Sendable, CaseIterable {
    case breakfast, lunch, snack, dinner
}

/// Where a meal sits in the day. The raw value is its fixed place, so what's eaten and swapped stays with
/// the right meal when snacks are turned on or off.
public enum MealMoment: Int, Codable, Sendable, CaseIterable {
    case breakfast, morningSnack, lunch, eveningSnack, dinner

    /// The kind of recipe served here.
    public var slot: MealSlot {
        switch self {
        case .breakfast: .breakfast
        case .morningSnack, .eveningSnack: .snack
        case .lunch: .lunch
        case .dinner: .dinner
        }
    }

    public var isSnack: Bool { slot == .snack }

    /// Where a recipe of this kind would sit (an afternoon snack for a snack).
    public init(slot: MealSlot) {
        switch slot {
        case .breakfast: self = .breakfast
        case .lunch: self = .lunch
        case .snack: self = .eveningSnack
        case .dinner: self = .dinner
        }
    }

    /// How the main meals share what the snacks leave.
    var share: Double {
        switch self {
        case .breakfast: 0.28
        case .lunch: 0.37
        case .dinner: 0.35
        case .morningSnack, .eveningSnack: 0
        }
    }

    /// The day's meals for this profile: the main meals, with a snack between breakfast and lunch and one
    /// between lunch and dinner when snacks are on. Intermittent fasting eats inside an 8-hour window
    /// (lunch at 1, a snack, dinner by 8), so it skips breakfast and the morning snack.
    public static func day(for profile: UserProfile) -> [MealMoment] {
        let two = profile.mealPattern == .two || profile.diet == .intermittentFasting
        let mains: [MealMoment] = two ? [.lunch, .dinner] : [.breakfast, .lunch, .dinner]
        guard profile.snacksBetweenMeals else { return mains }
        return allCases.filter { mains.contains($0) || ($0 == .morningSnack && mains.contains(.breakfast)) || $0 == .eveningSnack }
    }
}

public struct Ingredient: Codable, Sendable, Hashable {
    public var name: String
    public var grams: Int
    public init(name: String, grams: Int) { self.name = name; self.grams = grams }

    /// This ingredient's own macros at its weight, from the reference table. Nil if it isn't listed.
    public var macros: Macros? { NutritionTable.bundled[name].map { $0.scaled(grams: grams) } }
}

public struct Macros: Sendable, Hashable {
    public var kcal: Double
    public var proteinG: Double
    public var carbsG: Double
    public var fatG: Double

    public static let zero = Macros(kcal: 0, proteinG: 0, carbsG: 0, fatG: 0)
    public static func + (a: Macros, b: Macros) -> Macros {
        Macros(kcal: a.kcal + b.kcal, proteinG: a.proteinG + b.proteinG, carbsG: a.carbsG + b.carbsG, fatG: a.fatG + b.fatG)
    }
}

/// Per-100 g reference nutrition for every ingredient (resources/nutrition.json), plus how to picture it.
public struct NutritionEntry: Codable, Sendable, Hashable {
    public var kcal: Double
    public var proteinG: Double
    public var carbsG: Double
    public var fatG: Double
    /// A food emoji for the ingredient tile.
    public var emoji: String
    /// Tile tint family: green, peach, blue, sand.
    public var tone: String
    /// Where the numbers come from (a USDA FoodData Central ID, IFCT 2017, brand labels…).
    public var source: String?

    public func scaled(grams: Int) -> Macros {
        let f = Double(grams) / 100
        return Macros(kcal: kcal * f, proteinG: proteinG * f, carbsG: carbsG * f, fatG: fatG * f)
    }
}

public enum NutritionTable {
    struct Document: Codable { var ingredients: [String: NutritionEntry] }

    public static let bundled: [String: NutritionEntry] = {
        guard let url = Bundle.module.url(forResource: "nutrition", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let doc = try? JSONDecoder().decode(Document.self, from: data)
        else { fatalError("nutrition.json is missing or invalid") }
        return doc.ingredients
    }()
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
        case .pescatarian: proteins.isDisjoint(with: Protein.landMeat)
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

/// A meal as served on a given day: scaled to its share of the day, with any ingredient swaps applied.
public struct PlannedMeal: Sendable, Hashable, Identifiable {
    public var meal: Meal
    public var moment: MealMoment
    public var slot: MealSlot { moment.slot }
    /// What eaten ticks and swaps are keyed by: the meal's fixed place in the day (`moment.rawValue`), or a
    /// number of its own for a recipe shown outside the day's plan.
    public var index: Int
    public var kcal: Int
    public var proteinG: Int
    public var carbsG: Int
    public var fatG: Int
    public var ingredients: [Ingredient]
    /// (from, to) when the user swapped an ingredient.
    public var swapped: (from: String, to: String)?
    public var id: String { "\(index)-\(meal.id)" }

    public init(meal: Meal, moment: MealMoment, index: Int? = nil, kcal: Int, proteinG: Int, carbsG: Int, fatG: Int,
                ingredients: [Ingredient], swapped: (from: String, to: String)?) {
        self.meal = meal
        self.moment = moment
        self.index = index ?? moment.rawValue
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
    /// Candidates per slot: diet, allergens, proteins the user doesn't eat and food rules are hard filters and
    /// never relaxed; dislikes and cooking time are soft and relax only when a slot would otherwise be empty.
    /// Preferred cuisines come first.
    public static func pool(for profile: UserProfile, library: MealLibrary = .bundled) -> [MealSlot: [Meal]] {
        var result: [MealSlot: [Meal]] = [:]
        for slot in MealSlot.allCases {
            let safe = library.meals.filter {
                $0.slot == slot && $0.isAllowed(for: profile)
            }
            let preferred = safe.filter { meal in
                !meal.contains(anyOf: profile.dislikes) && (profile.maxCookMinutes.map { meal.cookMinutes <= $0 } ?? true)
            }
            let base = preferred.isEmpty ? safe.filter { !$0.contains(anyOf: profile.dislikes) } : preferred
            let candidates = base.isEmpty ? safe : base
            let liked = profile.cuisines.reduce(into: Set<String>()) { $0.formUnion($1.served) }
            result[slot] = candidates.filter { liked.contains($0.cuisine) }
                + candidates.filter { !liked.contains($0.cuisine) }
        }
        return result
    }

    /// A snack's calories: about 7% of the day, kept between 100 and 200 so snacks stay light.
    public static func snackCalories(day: Int) -> Int {
        min(200, max(100, Int((Double(day) * 0.07 / 10).rounded()) * 10))
    }

    /// The meals for day number `dayNumber` (days since 1 Jan 2001, a Monday), totalling `targetCalories`.
    /// Snacks get a small fixed budget; the main meals share the rest. Each meal is the recipe that best fits
    /// its budget, walking a shuffle that changes every week, so a week doesn't repeat and weeks differ.
    /// With `cheatMeal`, dinner is left out: the free meal takes its place.
    public static func day(dayNumber: Int, profile: UserProfile, targetCalories: Int, cheatMeal: Bool = false,
                           swaps: [IngredientSwapChoice] = [], library: MealLibrary = .bundled) -> [PlannedMeal] {
        let pool = pool(for: profile, library: library)
        let moments = MealMoment.day(for: profile).filter { !(cheatMeal && $0 == .dinner) }
        var used = Set<Int>()
        var picks: [MealMoment: (meal: Meal, scale: Double)] = [:]

        let snack = snackCalories(day: targetCalories)
        for moment in moments where moment.isSnack {
            guard let meal = choose(pool[moment.slot] ?? [], budget: snack, dayNumber: dayNumber, moment: moment,
                                    profile: profile, used: used) else { continue }
            used.insert(meal.id)
            picks[moment] = (meal, min(1.25, max(0.75, Double(snack) / Double(meal.kcal))))
        }
        let snackTotal = picks.values.reduce(0.0) { $0 + Double($1.meal.kcal) * $1.scale }
        let mains = moments.filter { !$0.isSnack }
        let shares = mains.reduce(0) { $0 + $1.share }
        for moment in mains {
            let budget = Int((Double(targetCalories) - snackTotal) * moment.share / shares)
            guard let meal = choose(pool[moment.slot] ?? [], budget: budget, dayNumber: dayNumber, moment: moment,
                                    profile: profile, used: used) else { continue }
            used.insert(meal.id)
            picks[moment] = (meal, min(2.0, max(0.5, Double(budget) / Double(meal.kcal))))
        }

        return moments.compactMap { moment in
            guard let (meal, f) = picks[moment] else { return nil }
            let swap = swaps.first { $0.mealIndex == moment.rawValue }
            // A Jain kitchen cooks the dish without its onion, garlic and ginger.
            let jain = profile.foodRules.contains(.jain)
            let ingredients = meal.ingredients.filter { !(jain && IngredientRules.isLeftOutForJain($0.name)) }.map { ing in
                Ingredient(name: swap?.from == ing.name ? swap!.to : ing.name, grams: Int((Double(ing.grams) * f).rounded()))
            }
            // Totals come from the ingredients themselves, so a swap really changes them
            // and the per-ingredient chips always add up to the dish.
            let parts = ingredients.map(\.macros)
            let totals: Macros = parts.allSatisfy({ $0 != nil })
                ? parts.compactMap { $0 }.reduce(.zero, +)
                : Macros(kcal: Double(meal.kcal) * f, proteinG: Double(meal.proteinG) * f,
                         carbsG: Double(meal.carbsG) * f, fatG: Double(meal.fatG) * f)
            return PlannedMeal(
                meal: meal, moment: moment,
                kcal: Int((totals.kcal / 5).rounded()) * 5,
                proteinG: Int(totals.proteinG.rounded()),
                carbsG: Int(totals.carbsG.rounded()),
                fatG: Int(totals.fatG.rounded()),
                ingredients: ingredients,
                swapped: swap.map { ($0.from, $0.to) }
            )
        }
    }

    /// The recipe for one meal: among those that fit its budget without stretching the portion too far (the
    /// user's cuisines first when there are enough of them, then the more protein-dense), the one this
    /// weekday lands on in this week's shuffle. A recipe isn't served twice in a day.
    static func choose(_ candidates: [Meal], budget: Int, dayNumber: Int, moment: MealMoment,
                       profile: UserProfile, used: Set<Int>) -> Meal? {
        let fresh = candidates.filter { !used.contains($0.id) }
        let fitting = fresh.filter { (0.6...1.7).contains(Double(budget) / Double($0.kcal)) }
        var options = fitting.isEmpty ? (fresh.isEmpty ? candidates : fresh) : fitting
        if moment.isSnack, profile.snackTaste != .both {
            let tasty = options.filter { $0.isSweet == (profile.snackTaste == .sweet) }
            if tasty.count >= 3 { options = tasty }
        }
        let liked = profile.cuisines.reduce(into: Set<String>()) { $0.formUnion($1.served) }
        let likedOptions = options.filter { liked.contains($0.cuisine) }
        if likedOptions.count >= 3 { options = likedOptions }
        // Favour protein: keep the denser part of the list — the top 60%, or the top 35% on a high-protein diet.
        let keep = profile.diet == .highProtein ? 0.35 : 0.6
        if options.count >= 6 {
            let density = { (m: Meal) in Double(m.proteinG * 4) / Double(max(1, m.kcal)) }
            options = Array(options.sorted { density($0) > density($1) }.prefix(max(4, Int(Double(options.count) * keep))))
        }
        guard !options.isEmpty else { return nil }
        let week = dayNumber >= 0 ? dayNumber / 7 : (dayNumber - 6) / 7
        let weekday = dayNumber - week * 7
        let shuffled = options.sorted { mix(week, moment.rawValue, $0.id) < mix(week, moment.rawValue, $1.id) }
        return shuffled[weekday % shuffled.count]
    }

    /// A fixed hash (Swift's own is seeded per launch), so the same day always gets the same meals.
    static func mix(_ a: Int, _ b: Int, _ c: Int) -> UInt64 {
        var x = UInt64(bitPattern: Int64(a)) &* 0x9E37_79B9_7F4A_7C15
        x ^= UInt64(bitPattern: Int64(b)) &* 0xBF58_476D_1CE4_E5B9
        x ^= UInt64(bitPattern: Int64(c)) &* 0x94D0_49BB_1331_11EB
        x ^= x >> 31; x &*= 0xD6E8_FEB8_6659_FD93; x ^= x >> 32
        return x
    }

    /// The replacement for a missing ingredient, if the library has one.
    public static func substitute(for ingredient: String, library: MealLibrary = .bundled) -> String? {
        library.substitutions[ingredient]
    }

    /// A replacement this user can actually eat: never one carrying their allergens, a protein they don't eat,
    /// or breaking their diet or food rules.
    public static func safeSubstitute(for ingredient: String, profile: UserProfile,
                                      library: MealLibrary = .bundled) -> String? {
        guard let sub = library.substitutions[ingredient], profile.accepts(ingredient: sub) else { return nil }
        return sub
    }
}

/// Conservative keyword rules for single ingredient names (used where a recipe's tags don't apply,
/// e.g. a swapped-in ingredient). Mirrors how meals.json allergens were derived.
public enum IngredientRules {
    static let allergenWords: [Allergen: [String]] = [
        .dairy: ["yoghurt", "paneer", "feta", "ghee", "whey", "curd", "skyr", "cheese", "cheddar", "parmesan",
                 "halloumi", "labneh", "tzatziki", "buttermilk", "cottage", "mozzarella", "ricotta", "pesto"],
        // Soy sauce, teriyaki, oyster sauce, miso and chilli pastes are usually brewed or thickened with wheat or barley.
        .gluten: ["sourdough", "rye", "pita", "roti", "tortilla", "oat", "bread", "wheat", "bagel", "bulgur",
                  "semolina", "soba", "pasta", "panko", "cracker", "granola", "couscous", "somen", "udon", "egg noodle",
                  "soy sauce", "teriyaki", "oyster sauce", "chilli bean paste", "gochujang", "miso"],
        .eggs: ["egg"],
        .soy: ["tofu", "soy", "edamame", "miso", "teriyaki"],
        .fish: ["salmon", "tuna", "fish", "mackerel", "cod", "anchov", "sardine"],
        // Kimchi is usually made with salted shrimp or fish sauce.
        .shellfish: ["prawn", "shrimp", "crab", "squid", "oyster", "kimchi"],
        .sesame: ["sesame", "hummus", "tahini"],
        .treeNuts: ["coconut", "almond", "cashew", "walnut", "pistachio", "hazelnut", "pecan", "pesto"],
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
        return ["chicken", "beef", "sirloin", "lamb", "pork", "turkey", "salmon", "tuna", "fish", "cod", "mackerel", "anchov",
                "sardine", "prawn", "shrimp", "crab", "squid", "oyster", "kimchi"].contains(where: n.contains)
    }

    public static func isVegan(_ name: String) -> Bool {
        let n = name.lowercased()
        if isMeatOrFish(n) || n.contains("egg") || n.contains("honey") { return false }
        return !allergens(in: n).contains(.dairy)
    }
}
