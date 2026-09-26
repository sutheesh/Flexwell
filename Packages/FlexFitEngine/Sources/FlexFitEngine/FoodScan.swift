import Foundation

/// Per-100 g nutrition for something the user logs outside the plan (scan, barcode, label, manual).
public struct FoodFacts: Codable, Sendable, Hashable {
    public var name: String
    public var category: String
    public var kcalPer100g: Double
    public var proteinPer100g: Double
    public var carbsPer100g: Double
    public var fatPer100g: Double
    /// A sensible starting portion; the user adjusts it.
    public var defaultGrams: Int

    public init(name: String, category: String, kcalPer100g: Double, proteinPer100g: Double,
                carbsPer100g: Double, fatPer100g: Double, defaultGrams: Int) {
        self.name = name
        self.category = category
        self.kcalPer100g = kcalPer100g
        self.proteinPer100g = proteinPer100g
        self.carbsPer100g = carbsPer100g
        self.fatPer100g = fatPer100g
        self.defaultGrams = defaultGrams
    }

    public func macros(grams: Int) -> Macros {
        let f = Double(grams) / 100
        return Macros(kcal: kcalPer100g * f, proteinG: proteinPer100g * f, carbsG: carbsPer100g * f, fatG: fatPer100g * f)
    }
}

/// Turns on-device image-classification labels into foods with nutrition.
/// Covers whole foods from the ingredient table plus common dishes people eat out.
public enum FoodRecognizer {
    /// Common dishes and fruit not in the recipe ingredients, per 100 g (reference values).
    static let dishes: [String: (kcal: Double, p: Double, c: Double, f: Double, grams: Int, category: String)] = [
        "pizza": (266, 11, 33, 10, 250, "Dish"), "hamburger": (254, 13, 24, 12, 220, "Dish"),
        "burger": (254, 13, 24, 12, 220, "Dish"), "cheeseburger": (263, 14, 22, 13, 230, "Dish"),
        "sandwich": (250, 11, 30, 9, 200, "Dish"), "hot dog": (290, 10, 24, 17, 150, "Dish"),
        "french fries": (312, 3.4, 41, 15, 150, "Side"), "fries": (312, 3.4, 41, 15, 150, "Side"),
        "salad": (60, 2, 6, 3.5, 250, "Dish"), "sushi": (143, 6, 28, 0.6, 250, "Dish"),
        "pasta": (158, 6, 31, 1, 300, "Dish"), "spaghetti": (158, 6, 31, 1, 300, "Dish"),
        "noodles": (138, 4.5, 25, 2, 300, "Dish"), "ramen": (90, 4, 12, 3, 500, "Dish"),
        "curry": (120, 7, 8, 7, 300, "Dish"), "burrito": (206, 9, 26, 7, 300, "Dish"),
        "taco": (226, 9, 20, 12, 150, "Dish"), "dumpling": (190, 8, 24, 7, 180, "Dish"),
        "fried rice": (163, 4, 26, 5, 300, "Dish"), "omelette": (154, 11, 0.6, 12, 150, "Dish"),
        "pancake": (227, 6, 28, 10, 150, "Dish"), "waffle": (291, 8, 33, 14, 100, "Dish"),
        "cake": (371, 5, 53, 16, 100, "Dessert"), "ice cream": (207, 3.5, 24, 11, 100, "Dessert"),
        "donut": (452, 5, 51, 25, 60, "Dessert"), "cookie": (488, 5, 64, 24, 40, "Dessert"),
        "croissant": (406, 8, 46, 21, 60, "Bakery"), "muffin": (377, 5, 50, 17, 110, "Bakery"),
        "orange": (47, 0.9, 12, 0.1, 150, "Fruit"), "mandarin": (53, 0.8, 13, 0.3, 120, "Fruit"),
        "grape": (69, 0.7, 18, 0.2, 150, "Fruit"), "kiwi": (61, 1.1, 15, 0.5, 75, "Fruit"),
        "watermelon": (30, 0.6, 8, 0.2, 300, "Fruit"), "fruit": (55, 0.8, 14, 0.3, 200, "Fruit"),
        "steak": (271, 25, 0, 19, 200, "Dish"), "fried chicken": (246, 24, 8, 13, 200, "Dish"),
        "soup": (40, 2, 5, 1.5, 350, "Dish"), "coffee": (2, 0.3, 0, 0, 250, "Drink"),
        "smoothie": (60, 1.5, 12, 0.8, 350, "Drink"), "bread": (265, 9, 49, 3.2, 60, "Bakery"),
    ]

    /// Candidate foods for classifier labels (best first). Labels are lowercased identifiers
    /// such as "orange", "pizza", "salad"; generic ones ("food", "dish") are ignored.
    public static func candidates(for labels: [(label: String, confidence: Double)], limit: Int = 3) -> [FoodFacts] {
        var seen = Set<String>()
        var out: [FoodFacts] = []
        for (raw, _) in labels.sorted(by: { $0.confidence > $1.confidence }) {
            let label = raw.lowercased().replacingOccurrences(of: "_", with: " ")
            guard !["food", "dish", "meal", "produce", "plant", "tableware", "bowl", "plate"].contains(label),
                  let facts = facts(for: label), seen.insert(facts.name).inserted else { continue }
            out.append(facts)
            if out.count == limit { break }
        }
        return out
    }

    /// Nutrition for a label: exact dish, then an ingredient whose name contains it (or vice versa).
    public static func facts(for label: String) -> FoodFacts? {
        let l = label.lowercased()
        if let d = dishes[l] {
            return FoodFacts(name: l.capitalized, category: d.category, kcalPer100g: d.kcal, proteinPer100g: d.p,
                             carbsPer100g: d.c, fatPer100g: d.f, defaultGrams: d.grams)
        }
        let table = NutritionTable.bundled
        let match = table.keys.sorted().first { $0.lowercased() == l }
            ?? table.keys.sorted().first { $0.lowercased().hasPrefix(l) || l.hasPrefix($0.lowercased()) }
        guard let name = match, let e = table[name], e.kcal > 0 else { return nil }
        return FoodFacts(name: name, category: "Ingredient", kcalPer100g: e.kcal, proteinPer100g: e.proteinG,
                         carbsPer100g: e.carbsG, fatPer100g: e.fatG, defaultGrams: 100)
    }
}

/// Reads a photographed nutrition panel (OCR lines) into per-100 g facts.
/// Handles "per 100 g" panels (EU/UK/India) and US "per serving" panels with a serving size.
public enum NutritionLabelParser {
    public struct Result: Equatable, Sendable {
        public var kcal: Double
        public var proteinG: Double
        public var carbsG: Double
        public var fatG: Double
        /// Grams per serving when the panel gives one; values above are per 100 g either way.
        public var servingGrams: Double?
    }

    public static func parse(_ lines: [String]) -> Result? {
        let text = lines.joined(separator: "\n").lowercased().replacingOccurrences(of: ",", with: ".")
        let serving = firstNumber(in: text, after: ["serving size", "per serving", "portion"], unit: "g")
        let per100 = text.contains("100 g") || text.contains("100g") || text.contains("100ml")

        guard var kcal = value(in: text, for: ["energy", "calories", "kcal"], preferKcal: true) else { return nil }
        var protein = value(in: text, for: ["protein"]) ?? 0
        var carbs = value(in: text, for: ["carbohydrate", "total carb", "carbs"]) ?? 0
        var fat = value(in: text, for: ["total fat", "fat"]) ?? 0

        // US panels are per serving: convert to per 100 g when we know the serving weight.
        if !per100, let s = serving, s > 0 {
            let f = 100 / s
            kcal *= f; protein *= f; carbs *= f; fat *= f
        }
        return Result(kcal: kcal, proteinG: protein, carbsG: carbs, fatG: fat, servingGrams: serving)
    }

    /// The first number after any of the keys on the same line. For energy, prefer a kcal figure over kJ.
    static func value(in text: String, for keys: [String], preferKcal: Bool = false) -> Double? {
        for line in text.split(separator: "\n").map(String.init) {
            guard let key = keys.first(where: { line.contains($0) }) else { continue }
            if key == "fat", line.contains("saturated") || line.contains("trans") { continue }
            let tail = String(line[line.range(of: key)!.upperBound...])
            if preferKcal, let kcal = number(before: "kcal", in: line) { return kcal }
            let nums = numbers(in: tail)
            if preferKcal, line.contains("kj"), nums.count > 1 { return nums[1] }
            if preferKcal, line.contains("kj"), let kj = nums.first { return kj / 4.184 }
            if let n = nums.first { return n }
        }
        return nil
    }

    static func firstNumber(in text: String, after keys: [String], unit: String) -> Double? {
        for line in text.split(separator: "\n").map(String.init) where keys.contains(where: line.contains) {
            if let g = number(before: unit, in: line) { return g }
        }
        return nil
    }

    static func number(before unit: String, in line: String) -> Double? {
        let pattern = #"(\d+(?:\.\d+)?)\s*"# + NSRegularExpression.escapedPattern(for: unit) + #"\b"#
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let r = Range(m.range(at: 1), in: line) else { return nil }
        return Double(line[r])
    }

    static func numbers(in s: String) -> [Double] {
        guard let re = try? NSRegularExpression(pattern: #"\d+(?:\.\d+)?"#) else { return [] }
        return re.matches(in: s, range: NSRange(s.startIndex..., in: s)).compactMap { m in
            Range(m.range, in: s).flatMap { Double(s[$0]) }
        }
    }
}
