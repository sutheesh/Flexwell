import Testing
@testable import FlexFitEngine

@Test func classifierLabelsMapToFoods() {
    let c = FoodRecognizer.candidates(for: [("food", 0.99), ("orange", 0.8), ("banana", 0.6), ("pizza", 0.3)])
    #expect(c.map(\.name) == ["Orange", "Banana", "Pizza"])
    #expect(c[0].kcalPer100g == 47 && c[1].kcalPer100g == 89)
}

@Test func euPer100gLabel() {
    let r = NutritionLabelParser.parse([
        "Nutrition per 100g", "Energy 1569 kJ / 374 kcal", "Fat 9.4 g", "of which saturates 1.2 g",
        "Carbohydrate 60 g", "Protein 11 g",
    ])
    #expect(r?.kcal == 374 && r?.fatG == 9.4 && r?.carbsG == 60 && r?.proteinG == 11)
}

@Test func usPerServingLabelConvertsToPer100g() {
    let r = NutritionLabelParser.parse([
        "Nutrition Facts", "Serving size 40g", "Calories 160", "Total Fat 6g", "Saturated Fat 1g",
        "Total Carbohydrate 22g", "Protein 4g",
    ])
    #expect(r?.servingGrams == 40)
    #expect(r?.kcal == 400 && r?.fatG == 15 && r?.carbsG == 55 && r?.proteinG == 10)
}

@Test func unreadableLabelIsNil() {
    #expect(NutritionLabelParser.parse(["hello", "world"]) == nil)
}
