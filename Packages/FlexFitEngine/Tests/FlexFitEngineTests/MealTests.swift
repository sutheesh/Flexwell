import Testing
@testable import FlexFitEngine

let meals = MealLibrary.bundled

@Test func mealLibraryLoads() {
    #expect(meals.meals.count >= 313)
    #expect(Set(meals.meals.map(\.id)).count == meals.meals.count)
    #expect(meals.substitutions["Eggs"] == "Firm tofu")
}

@Test func allergensAreNeverServed() {
    for allergen in Allergen.allCases {
        var p = alex
        p.allergens = [allergen]
        for weekday in 0..<7 {
            for m in MealPlanner.day(dayNumber: weekday, profile: p, targetCalories: 2000) {
                #expect(!m.meal.allergens.contains(allergen), "\(m.meal.name) has \(allergen)")
            }
        }
    }
}

@Test func dietStyleIsAHardFilter() {
    var p = alex
    p.diet = .vegan
    for weekday in 0..<7 {
        #expect(MealPlanner.day(dayNumber: weekday, profile: p, targetCalories: 2000).allSatisfy { $0.meal.vegan })
    }
}

@Test func dayScalesToTarget() {
    for dayNumber in 0..<28 {
        let day = MealPlanner.day(dayNumber: dayNumber, profile: alex, targetCalories: 2100)
        #expect(day.map(\.moment) == [.breakfast, .morningSnack, .lunch, .eveningSnack, .dinner])
        let total = day.reduce(0) { $0 + $1.kcal }
        #expect(abs(total - 2100) <= 60, "day \(dayNumber): \(total)")
    }
}

@Test func snacksAreLightAndMainMealsCarryTheDay() {
    for dayNumber in 0..<28 {
        let day = MealPlanner.day(dayNumber: dayNumber, profile: alex, targetCalories: 2400)
        for snack in day where snack.moment.isSnack {
            #expect(snack.kcal <= 260, "\(snack.meal.name): \(snack.kcal)")
        }
        let mains = day.filter { !$0.moment.isSnack }.reduce(0) { $0 + $1.kcal }
        #expect(Double(mains) >= 0.8 * Double(day.reduce(0) { $0 + $1.kcal }))
    }
}

@Test func snacksFollowTheMainMeals() {
    var p = alex
    p.snacksBetweenMeals = false
    #expect(MealMoment.day(for: p) == [.breakfast, .lunch, .dinner])
    p.mealPattern = .two
    #expect(MealMoment.day(for: p) == [.lunch, .dinner])
    p.snacksBetweenMeals = true
    #expect(MealMoment.day(for: p) == [.lunch, .eveningSnack, .dinner])
    #expect(MealPattern(stored: "fourToFive") == .three && MealPattern.legacyHadSnacks("threePlusSnack") == true)
}

@Test func mealsVaryThroughTheWeekAndFromWeekToWeek() {
    let week1 = (0..<7).map { MealPlanner.day(dayNumber: $0, profile: alex, targetCalories: 2100) }
    let week2 = (7..<14).map { MealPlanner.day(dayNumber: $0, profile: alex, targetCalories: 2100) }
    let lunches = week1.compactMap { $0.first { $0.moment == .lunch }?.meal.id }
    #expect(Set(lunches).count >= 5)
    #expect(week1.map { $0.map(\.meal.id) } != week2.map { $0.map(\.meal.id) })
    // The same day always gets the same meals.
    #expect(MealPlanner.day(dayNumber: 3, profile: alex, targetCalories: 2100).map(\.meal.id) == week1[3].map(\.meal.id))
}

@Test func aRecipeIsNotServedTwiceInADay() {
    for dayNumber in 0..<56 {
        let ids = MealPlanner.day(dayNumber: dayNumber, profile: alex, targetCalories: 2100).map(\.meal.id)
        #expect(Set(ids).count == ids.count)
    }
}

@Test func intermittentFastingEatsInsideTheWindow() {
    var p = alex
    p.diet = .intermittentFasting
    #expect(MealMoment.day(for: p) == [.lunch, .eveningSnack, .dinner])
}

@Test func highProteinServesDenserMeals() {
    var p = alex
    p.diet = .balanced
    let density = { (d: [PlannedMeal]) in Double(d.reduce(0) { $0 + $1.proteinG } * 4) / Double(d.reduce(0) { $0 + $1.kcal }) }
    let usual = (0..<28).map { density(MealPlanner.day(dayNumber: $0, profile: p, targetCalories: 2100)) }.reduce(0, +)
    p.diet = .highProtein
    let high = (0..<28).map { density(MealPlanner.day(dayNumber: $0, profile: p, targetCalories: 2100)) }.reduce(0, +)
    #expect(high > usual)
}

@Test func aCheatMealTakesDinnersPlace() {
    let day = MealPlanner.day(dayNumber: 5, profile: alex, targetCalories: 1500, cheatMeal: true)
    #expect(!day.contains { $0.moment == .dinner })
}

@Test func preferredCuisinesComeFirst() {
    var p = alex
    p.cuisines = [.mexican]
    #expect(MealPlanner.pool(for: p)[.lunch]?.first?.cuisine == "Mexican")
    // …and actually get served when there are enough of them; East Asian takes in Chinese, Japanese and Korean.
    p.cuisines = [.eastAsian]
    let asian: Set = ["East Asian", "Chinese", "Japanese", "Korean"]
    #expect((0..<14).allSatisfy { d in
        MealPlanner.day(dayNumber: d, profile: p, targetCalories: 2100).filter { !$0.moment.isSnack }.allSatisfy { asian.contains($0.meal.cuisine) }
    })
    p.cuisines = [.indian]
    let lunches = (0..<14).compactMap { MealPlanner.day(dayNumber: $0, profile: p, targetCalories: 2100).first { $0.moment == .lunch } }
    #expect(lunches.allSatisfy { ["Indian", "South Indian"].contains($0.meal.cuisine) })
}

@Test func dislikesAreAvoidedWhenPossible() {
    var p = alex
    p.dislikes = ["Salmon", "Paneer"]
    for weekday in 0..<7 {
        for m in MealPlanner.day(dayNumber: weekday, profile: p, targetCalories: 2000) {
            #expect(!m.meal.contains(anyOf: p.dislikes))
        }
    }
}

@Test func ingredientSwapReplacesTheName() {
    var p = alex
    p.mealPattern = .three
    p.snacksBetweenMeals = false
    let first = MealPlanner.day(dayNumber: 0, profile: p, targetCalories: 2000)[0]
    let from = first.ingredients[0].name
    let to = MealPlanner.substitute(for: from) ?? "X"
    let swapped = MealPlanner.day(dayNumber: 0, profile: p, targetCalories: 2000,
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
    p.snacksBetweenMeals = false
    let days = (0..<7).map { MealPlanner.day(dayNumber: $0, profile: p, targetCalories: 2000) }
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
        if meal.keto { #expect(meal.carbsG <= 15, "\(meal.name) has \(meal.carbsG) g carbs but is tagged keto") }
    }
}

@Test func everyRecipesCuisineIsOneUsersCanPick() {
    let known = Set(Cuisine.allCases.map(\.rawValue))
    for meal in meals.meals { #expect(known.contains(meal.cuisine), "\(meal.name): \(meal.cuisine)") }
}

@Test func everyDietHasEnoughMainMeals() {
    for (diet, minimum) in [(DietStyle.vegetarian, 12), (.vegan, 12), (.keto, 8)] {
        for slot in [MealSlot.breakfast, .lunch, .dinner] {
            let n = meals.meals.filter { $0.slot == slot && $0.fits(diet) }.count
            #expect(n >= minimum, "\(diet) \(slot): \(n)")
        }
    }
}

@Test func everyIngredientSaysWhereItsNumbersComeFrom() {
    for (name, entry) in NutritionTable.bundled {
        #expect(entry.source?.isEmpty == false, "\(name) has no source")
    }
}

@Test func everyIngredientHasNutrition() {
    for meal in meals.meals { for ing in meal.ingredients { #expect(NutritionTable.bundled[ing.name] != nil, "\(ing.name)") } }
    for sub in meals.substitutions.values { #expect(NutritionTable.bundled[sub] != nil, "\(sub)") }
}

@Test func ingredientMacrosAddUpToTheDish() {
    for weekday in 0..<7 {
        for m in MealPlanner.day(dayNumber: weekday, profile: alex, targetCalories: 2000) {
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
    p.snacksBetweenMeals = false
    let plain = MealPlanner.day(dayNumber: 0, profile: p, targetCalories: 2000)[0]
    guard let target = plain.ingredients.first(where: { MealPlanner.substitute(for: $0.name) != nil }) else { return }
    let to = MealPlanner.substitute(for: target.name)!
    let swapped = MealPlanner.day(dayNumber: 0, profile: p, targetCalories: 2000,
                                  swaps: [IngredientSwapChoice(mealIndex: 0, from: target.name, to: to)])[0]
    let expected = swapped.ingredients.compactMap(\.macros).reduce(Macros.zero, +)
    #expect(abs(expected.proteinG - Double(swapped.proteinG)) <= 0.5 + 1e-9)
}
