import Testing
@testable import FlexFitEngine

private func week(_ edit: (inout UserProfile) -> Void) -> CalorieWeek.Week {
    var p = alex
    edit(&p)
    let t = TargetCalculator.initialTargets(for: p)
    return CalorieWeek.week(for: p, base: t.calories, expenditure: t.expenditure)
}

/// Active enough that the week has room above the floor to pay for a cheat day.
private func active(_ p: inout UserProfile) { p.activity = .onFeet }
private let plainTotal = week(active).days.reduce(0) { $0 + $1.calories }

@Test func noCheatDaysLeavesTheWeekAlone() {
    let w = week { _ in }
    #expect(w.unpaidKcal == 0 && w.days.allSatisfy { $0.cheat == nil && $0.calories == $0.plain })
    #expect(w.days.contains { $0.calories == w.days.map(\.calories).max()! - CalorieWeek.restDayReduction })
}

@Test func aSpreadCheatDayKeepsTheWeeksTotal() {
    let w = week { active(&$0); $0.cheatDays.frequency = .once; $0.cheatDays.weekdays = [5] }
    let saturday = w.days[5]
    #expect(saturday.cheat == .day && saturday.calories > saturday.plain)
    #expect(w.unpaidKcal == 0)
    #expect(abs(w.days.reduce(0) { $0 + $1.calories } - plainTotal) <= 40)
    for (i, d) in w.days.enumerated() where i != 5 { #expect(d.calories < d.plain) }
}

@Test func leavingTheGoalToMoveChangesNothingElse() {
    let w = week { $0.cheatDays.frequency = .once; $0.cheatDays.budget = .goalMoves }
    #expect(w.unpaidKcal > 0)
    for (i, d) in w.days.enumerated() where i != 5 { #expect(d.calories == d.plain) }
    var p = alex
    p.cheatDays.frequency = .twice
    p.cheatDays.budget = .goalMoves
    #expect(TargetCalculator.weeksToGoal(for: p)! > TargetCalculator.weeksToGoal(for: alex)!)
}

@Test func whatTheFloorBlocksIsLeftUnpaid() {
    // Alex eats close to his floor: the week pays what it can and says what's left.
    let w = week { $0.cheatDays.frequency = .once }
    #expect(w.unpaidKcal > 0)
    for d in w.days where d.cheat == nil { #expect(d.calories <= d.plain) }
}

@Test func payingForCheatDaysNeverGoesBelowTheFloor() {
    let w = week {
        $0.weightKg = 60; $0.heightCm = 160; $0.targetWeightKg = 55; $0.sex = .female
        $0.cheatDays.frequency = .twice
    }
    for d in w.days where d.cheat == nil { #expect(d.calories >= 1_200) }
}

@Test func aCheatMealAddsToOneMeal() {
    let w = week { $0.cheatDays.frequency = .once; $0.cheatDays.style = .meal; $0.cheatDays.budget = .goalMoves }
    let d = w.days[5]
    #expect(d.cheat == .meal && d.calories == d.plain + CalorieWeek.cheatMealExtra)
    #expect(d.cheatMealKcal! > CalorieWeek.cheatMealExtra && d.plannedCalories < d.plain)
}

@Test func twiceAWeekUsesTwoDistinctDays() {
    var c = CheatDays()
    c.frequency = .twice
    c.weekdays = [5, 5, 2]
    #expect(c.activeWeekdays == [5, 2])
}
