import Foundation

// MARK: - Eating out (PRD Phase 3 restaurant guide)

public struct RestaurantPick: Codable, Sendable, Hashable {
    public var name: String
    public var tip: String
    public var kcal: Int
    public var proteinG: Int
    public var vegetarian: Bool
    public var vegan: Bool
    public var allergens: [Allergen]
}

public enum RestaurantGuide {
    struct Document: Codable { var cuisines: [String: [RestaurantPick]] }

    public static let bundled: [String: [RestaurantPick]] = {
        guard let url = Bundle.module.url(forResource: "restaurants", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let doc = try? JSONDecoder().decode(Document.self, from: data)
        else { fatalError("restaurants.json is missing or invalid") }
        return doc.cuisines
    }()

    public static var cuisines: [String] { bundled.keys.sorted() }

    /// Picks safe for this user (allergens, vegetarian/vegan), best protein-per-calorie first,
    /// preferring ones that fit the calories left today.
    public static func picks(cuisine: String, profile: UserProfile, kcalLeft: Int, limit: Int = 3) -> [RestaurantPick] {
        (bundled[cuisine] ?? [])
            .filter { profile.allergens.isDisjoint(with: $0.allergens) }
            .filter { profile.diet == .vegan ? $0.vegan : profile.diet == .vegetarian ? $0.vegetarian : true }
            .sorted { a, b in
                let aFits = a.kcal <= max(kcalLeft, 350), bFits = b.kcal <= max(kcalLeft, 350)
                if aFits != bFits { return aFits }
                return Double(a.proteinG) / Double(a.kcal) > Double(b.proteinG) / Double(b.kcal)
            }
            .prefix(limit)
            .map { $0 }
    }
}

// MARK: - Grocery list (mock "Groceries", PRD Phase 2)

public enum GroceryCategory: String, Sendable, CaseIterable {
    case protein, produce, dairy, pantry

    static func of(_ name: String) -> GroceryCategory {
        let n = name.lowercased()
        if ["chicken", "salmon", "sirloin", "egg", "paneer", "tofu", "whey", "tuna"].contains(where: n.contains) { return .protein }
        if ["yoghurt", "milk", "feta", "ghee", "curd", "skyr"].contains(where: n.contains) && !n.contains("coconut") { return .dairy }
        if ["rice", "oat", "bread", "roti", "pita", "quinoa", "dal", "beans", "chickpea", "chana", "tortilla",
            "sourdough", "rye", "oil", "honey", "seeds", "sauce", "cumin", "masala", "salt", "coconut", "sesame"].contains(where: n.contains) {
            return .pantry
        }
        return .produce
    }
}

public struct GroceryItem: Sendable, Hashable {
    public var name: String
    public var grams: Int
    public var category: GroceryCategory
}

public enum GroceryList {
    /// Every ingredient across the given days' meals, summed and grouped.
    public static func build(from days: [[PlannedMeal]]) -> [GroceryItem] {
        var totals: [String: Int] = [:]
        for meal in days.flatMap({ $0 }) {
            for ing in meal.ingredients { totals[ing.name, default: 0] += ing.grams }
        }
        return totals.map { GroceryItem(name: $0.key, grams: $0.value, category: GroceryCategory.of($0.key)) }
            .sorted { ($0.category.rawValue, $0.name) < ($1.category.rawValue, $1.name) }
    }
}
