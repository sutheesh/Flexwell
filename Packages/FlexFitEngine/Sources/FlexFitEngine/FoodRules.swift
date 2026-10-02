import Foundation

/// Proteins a user can say they don't eat. Everything is eaten unless it's excluded.
public enum Protein: String, Codable, Sendable, CaseIterable {
    case poultry, beef, pork, lamb, fish, shellfish, eggs, dairy, soy

    /// Meat from land animals (what pescatarians leave out).
    public static let landMeat: Set<Protein> = [.poultry, .beef, .pork, .lamb]
    /// Every animal protein (what vegetarians leave out, less eggs and dairy).
    public static let meatAndFish: Set<Protein> = landMeat.union([.fish, .shellfish])
}

/// Food rules that sit on top of any diet style.
public enum FoodRule: String, Codable, Sendable, CaseIterable {
    /// No pork (and nothing else in the library conflicts: there is no alcohol or gelatine).
    case halal
    /// Vegetarian without eggs, and no root vegetables, mushrooms or honey. Onion, garlic and ginger used for
    /// flavour are left out of the dish; recipes built on potatoes, carrots and the like are skipped.
    case jain
}

/// Which snacks to lean towards.
public enum SnackTaste: String, Codable, Sendable, CaseIterable {
    case both, sweet, savoury
}

extension IngredientRules {
    static let landMeatWords: [Protein: [String]] = [
        .poultry: ["chicken", "turkey"],
        .beef: ["beef", "sirloin"],
        .pork: ["pork", "bacon", "prosciutto"],
        .lamb: ["lamb", "mutton"],
    ]

    /// The proteins in an ingredient, by name.
    public static func proteins(in name: String) -> Set<Protein> {
        let n = name.lowercased()
        var result = Set(landMeatWords.filter { $0.value.contains(where: n.contains) }.keys)
        let allergens = allergens(in: n)
        let map: [Allergen: Protein] = [.fish: .fish, .shellfish: .shellfish, .eggs: .eggs, .dairy: .dairy, .soy: .soy]
        for (allergen, protein) in map where allergens.contains(allergen) { result.insert(protein) }
        return result
    }

    /// Aromatics a Jain kitchen leaves out; the rest of the dish stands without them.
    static let jainLeftOut = ["onion", "garlic", "ginger"]
    /// Ingredients a Jain diet doesn't allow and a dish can't do without.
    static let jainExcluded = ["potato", "carrot", "beetroot", "radish", "yam", "cassava", "mushroom", "honey"]

    public static func isLeftOutForJain(_ name: String) -> Bool {
        let n = name.lowercased()
        return jainLeftOut.contains(where: n.contains)
    }

    public static func isExcludedForJain(_ name: String) -> Bool {
        let n = name.lowercased()
        return jainExcluded.contains(where: n.contains) || isMeatOrFish(n) || n.contains("egg")
    }

    static let sweetWords = ["apple", "banana", "berr", "mango", "pineapple", "pear", "orange", "grape", "kiwi", "watermelon",
                             "date", "raisin", "honey", "maple", "chocolate", "granola", "protein bar"]

    static func isSweet(_ name: String) -> Bool {
        let n = name.lowercased()
        return sweetWords.contains(where: n.contains)
    }
}

extension Meal {
    /// Every protein in the recipe.
    public var proteins: Set<Protein> {
        ingredients.reduce(into: Set<Protein>()) { $0.formUnion(IngredientRules.proteins(in: $1.name)) }
    }

    /// A snack that eats sweet: fruit, dates, honey or chocolate make up much of it.
    public var isSweet: Bool {
        let total = ingredients.reduce(0) { $0 + $1.grams }
        let sweet = ingredients.filter { IngredientRules.isSweet($0.name) }.reduce(0) { $0 + $1.grams }
        return total > 0 && Double(sweet) / Double(total) >= 0.4
    }

    /// Whether this user can be served the recipe at all: diet style, allergens, proteins they don't eat, and
    /// their food rules. Never relaxed.
    public func isAllowed(for profile: UserProfile) -> Bool {
        guard fits(profile.diet), profile.allergens.isDisjoint(with: allergens) else { return false }
        let proteins = proteins
        guard proteins.isDisjoint(with: profile.excludedProteins) else { return false }
        if profile.foodRules.contains(.halal), proteins.contains(.pork) { return false }
        if profile.foodRules.contains(.jain), ingredients.contains(where: { IngredientRules.isExcludedForJain($0.name) }) {
            return false
        }
        return true
    }
}

extension UserProfile {
    /// Whether a single ingredient (a swap-in) is fine for this user.
    public func accepts(ingredient name: String) -> Bool {
        guard allergens.isDisjoint(with: IngredientRules.allergens(in: name)) else { return false }
        let proteins = IngredientRules.proteins(in: name)
        guard proteins.isDisjoint(with: excludedProteins) else { return false }
        if foodRules.contains(.halal), proteins.contains(.pork) { return false }
        if foodRules.contains(.jain), IngredientRules.isExcludedForJain(name) || IngredientRules.isLeftOutForJain(name) { return false }
        switch diet {
        case .vegan: return IngredientRules.isVegan(name)
        case .vegetarian: return !IngredientRules.isMeatOrFish(name)
        case .pescatarian: return proteins.isDisjoint(with: Protein.landMeat)
        default: return true
        }
    }
}
