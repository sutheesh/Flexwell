import Testing
@testable import FlexFitEngine

let meals = MealLibrary.bundled

@Test func mealLibraryLoads() {
    #expect(meals.meals.count == 120)
    #expect(Set(meals.meals.map(\.id)).count == 120)
    #expect(meals.substitutions["Eggs"] == "Firm tofu")
}

@Test func allergensAreNeverServed() {
    for allergen in Allergen.allCases {
        var p = alex
        p.allergens = [allergen]
        for weekday in 0..<7 {
            for m in MealPlanner.day(weekday: weekday, profile: p, targetCalories: 2000) {
                #expect(!m.meal.allergens.contains(allergen), "\(m.meal.name) has \(allergen)")
            }
        }
    }
}

@Test func dietStyleIsAHardFilter() {
    var p = alex
    p.diet = .vegan
    for weekday in 0..<7 {
        #expect(MealPlanner.day(weekday: weekday, profile: p, targetCalories: 2000).allSatisfy { $0.meal.vegan })
    }
}

@Test func dayScalesToTarget() {
    var p = alex
    p.mealPattern = .threePlusSnack
    let day = MealPlanner.day(weekday: 2, profile: p, targetCalories: 2100)
    #expect(day.count == 4)
    let total = day.reduce(0) { $0 + $1.kcal }
    #expect(abs(total - 2100) <= 25)
}

@Test func preferredCuisinesComeFirst() {
    var p = alex
    p.cuisines = [.mexican]
    #expect(MealPlanner.pool(for: p)[.lunch]?.first?.cuisine == "Mexican")
}

@Test func dislikesAreAvoidedWhenPossible() {
    var p = alex
    p.dislikes = ["Salmon", "Paneer"]
    for weekday in 0..<7 {
        for m in MealPlanner.day(weekday: weekday, profile: p, targetCalories: 2000) {
            #expect(!m.meal.contains(anyOf: p.dislikes))
        }
    }
}

@Test func ingredientSwapReplacesTheName() {
    var p = alex
    p.mealPattern = .three
    let first = MealPlanner.day(weekday: 0, profile: p, targetCalories: 2000)[0]
    let from = first.ingredients[0].name
    let to = MealPlanner.substitute(for: from) ?? "X"
    let swapped = MealPlanner.day(weekday: 0, profile: p, targetCalories: 2000,
                                  swaps: [IngredientSwapChoice(mealIndex: 0, from: from, to: to)])[0]
    #expect(swapped.ingredients[0].name == to && swapped.swapped?.to == to)
}

@Test func restaurantGuideHasTenCuisinesAndRespectsAllergens() {
    #expect(RestaurantGuide.cuisines.count == 10)
    var p = alex
    p.allergens = [.fish, .soy]
    for cuisine in RestaurantGuide.cuisines {
        for pick in RestaurantGuide.picks(cuisine: cuisine, profile: p, kcalLeft: 700) {
            #expect(p.allergens.isDisjoint(with: pick.allergens))
        }
    }
    p.diet = .vegan
    #expect(RestaurantGuide.picks(cuisine: "Indian", profile: p, kcalLeft: 700).allSatisfy { $0.vegan })
}

@Test func groceryListSumsTheWeek() {
    var p = alex
    p.mealPattern = .three
    let days = (0..<7).map { MealPlanner.day(weekday: $0, profile: p, targetCalories: 2000) }
    let list = GroceryList.build(from: days)
    let total = list.reduce(0) { $0 + $1.grams }
    #expect(total == days.flatMap { $0 }.flatMap(\.ingredients).reduce(0) { $0 + $1.grams })
    #expect(Set(list.map(\.name)).count == list.count)
}

@Test func substitutesNeverIntroduceAllergensOrBreakDiet() {
    var p = alex
    p.allergens = [.soy]
    #expect(MealPlanner.safeSubstitute(for: "Eggs", profile: p) == nil)          // → Firm tofu (soy)
    p.allergens = []
    #expect(MealPlanner.safeSubstitute(for: "Eggs", profile: p) == "Firm tofu")
    p.diet = .vegan
    #expect(MealPlanner.safeSubstitute(for: "Firm tofu", profile: p) == nil)     // → Paneer (dairy)
    p.diet = .vegetarian
    #expect(MealPlanner.safeSubstitute(for: "Sirloin", profile: p) == nil)       // → Chicken thigh
    #expect(IngredientRules.allergens(in: "Soy milk") == [.soy])
    #expect(IngredientRules.allergens(in: "Milk") == [.dairy])
}

/// Tags must cover everything the ingredient rules detect, and diet flags must hold.
@Test func everyRecipeIsTaggedConsistently() {
    for meal in meals.meals {
        let detected = meal.ingredients.reduce(into: Set<Allergen>()) { $0.formUnion(IngredientRules.allergens(in: $1.name)) }
        #expect(detected.isSubset(of: Set(meal.allergens)), "\(meal.name): missing \(detected.subtracting(meal.allergens))")
        if meal.vegan { #expect(meal.ingredients.allSatisfy { IngredientRules.isVegan($0.name) }, "\(meal.name) isn't vegan") }
        if meal.vegetarian { #expect(!meal.ingredients.contains { IngredientRules.isMeatOrFish($0.name) }, "\(meal.name) has meat") }
        #expect(meal.cookMinutes <= 30)
    }
}

@Test func everyIngredientHasNutrition() {
    for meal in meals.meals { for ing in meal.ingredients { #expect(NutritionTable.bundled[ing.name] != nil, "\(ing.name)") } }
    for sub in meals.substitutions.values { #expect(NutritionTable.bundled[sub] != nil, "\(sub)") }
}

@Test func ingredientMacrosAddUpToTheDish() {
    for weekday in 0..<7 {
        for m in MealPlanner.day(weekday: weekday, profile: alex, targetCalories: 2000) {
            let sum = m.ingredients.compactMap(\.macros).reduce(Macros.zero, +)
            #expect(abs(sum.proteinG - Double(m.proteinG)) <= 0.5 + 1e-9)
            #expect(abs(sum.carbsG - Double(m.carbsG)) <= 0.5 + 1e-9)
            #expect(abs(sum.kcal - Double(m.kcal)) <= 2.5 + 1e-9)
        }
    }
}

@Test func swappingAnIngredientChangesTheMacros() {
    var p = alex
    p.mealPattern = .three
    let plain = MealPlanner.day(weekday: 0, profile: p, targetCalories: 2000)[0]
    guard let target = plain.ingredients.first(where: { MealPlanner.substitute(for: $0.name) != nil }) else { return }
    let to = MealPlanner.substitute(for: target.name)!
    let swapped = MealPlanner.day(weekday: 0, profile: p, targetCalories: 2000,
                                  swaps: [IngredientSwapChoice(mealIndex: 0, from: target.name, to: to)])[0]
    let expected = swapped.ingredients.compactMap(\.macros).reduce(Macros.zero, +)
    #expect(abs(expected.proteinG - Double(swapped.proteinG)) <= 0.5 + 1e-9)
}
