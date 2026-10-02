import Testing
@testable import FlexFitEngine

private func days(_ p: UserProfile, _ n: Int = 28) -> [PlannedMeal] {
    (0..<n).flatMap { MealPlanner.day(dayNumber: $0, profile: p, targetCalories: 2100) }
}

@Test func pescatariansGetFishButNoMeat() {
    var p = alex
    p.diet = .pescatarian
    let served = days(p)
    #expect(served.allSatisfy { $0.meal.proteins.isDisjoint(with: Protein.landMeat) })
    #expect(served.contains { $0.meal.proteins.contains(.fish) })
}

@Test func proteinsTheUserDoesntEatAreNeverServed() {
    for protein in Protein.allCases {
        var p = alex
        p.excludedProteins = [protein]
        #expect(days(p, 14).allSatisfy { !$0.meal.proteins.contains(protein) }, "\(protein)")
    }
}

@Test func halalMeansNoPork() {
    var p = alex
    p.foodRules = [.halal]
    #expect(meals.meals.contains { $0.proteins.contains(.pork) })
    #expect(days(p).allSatisfy { !$0.meal.proteins.contains(.pork) })
}

@Test func jainMealsHaveNoMeatEggsRootsOrAromatics() {
    var p = alex
    p.diet = .vegetarian
    p.foodRules = [.jain]
    let served = days(p)
    #expect(!served.isEmpty)
    for m in served {
        for ing in m.ingredients {
            #expect(!IngredientRules.isExcludedForJain(ing.name) && !IngredientRules.isLeftOutForJain(ing.name), "\(m.meal.name): \(ing.name)")
        }
    }
    // Enough to eat without repeating every other day.
    for slot in [MealSlot.breakfast, .lunch, .dinner] {
        #expect(meals.meals.filter { $0.slot == slot && $0.isAllowed(for: p) }.count >= 8, "\(slot)")
    }
}

@Test func snackTasteLeansTheSnacks() {
    var p = alex
    p.snackTaste = .sweet
    let sweet = days(p).filter(\.moment.isSnack)
    #expect(Double(sweet.filter(\.meal.isSweet).count) >= 0.8 * Double(sweet.count))
    p.snackTaste = .savoury
    let savoury = days(p).filter(\.moment.isSnack)
    #expect(Double(savoury.filter { !$0.meal.isSweet }.count) >= 0.8 * Double(savoury.count))
}

@Test func swapsRespectProteinsAndRules() {
    var p = alex
    p.diet = .balanced
    #expect(p.accepts(ingredient: "Chicken breast"))
    p.excludedProteins = [.poultry]
    #expect(!p.accepts(ingredient: "Chicken breast") && !p.accepts(ingredient: "Turkey mince"))
    p.foodRules = [.halal]
    #expect(!p.accepts(ingredient: "Pork loin"))
    p.foodRules = [.jain]
    #expect(!p.accepts(ingredient: "Potato") && !p.accepts(ingredient: "Onion") && !p.accepts(ingredient: "Eggs"))
}

@Test func restaurantPicksRespectProteins() {
    var p = alex
    p.excludedProteins = [.poultry, .beef, .pork, .lamb]
    for cuisine in RestaurantGuide.cuisines {
        for pick in RestaurantGuide.picks(cuisine: cuisine, profile: p, kcalLeft: 700) {
            #expect(IngredientRules.proteins(in: pick.name).isDisjoint(with: Protein.landMeat), "\(pick.name)")
        }
    }
}
