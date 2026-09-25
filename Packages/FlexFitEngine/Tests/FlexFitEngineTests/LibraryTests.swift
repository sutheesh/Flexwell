import Testing
import Foundation
@testable import FlexFitEngine

let library = ExerciseLibrary.bundled

@Test func libraryLoads150UniqueExercises() {
    #expect(library.exercises.count == 150)
    #expect(Set(library.exercises.map(\.id)).count == 150)
    #expect(library.exercises.filter(\.media.bundled).count == 60)
}

@Test func everyStrengthPatternHasABodyweightOption() {
    for pattern in [MovementPattern.horizontalPush, .verticalPush, .horizontalPull, .squat, .hinge, .lunge, .core, .mobility] {
        #expect(!library.candidates(pattern: pattern, equipment: [], limitations: []).isEmpty, "\(pattern)")
    }
}

/// PRD F2 acceptance: no exercise needs equipment the user lacks or is flagged against their limitations.
@Test func sessionsRespectEquipmentAndLimitations() {
    for env in TrainingEnvironment.allCases {
        for limitation in [nil] + Limitation.allCases.map(Optional.some) {
            for days in 2...6 {
                for minutes in [20, 30, 45, 60] {
                    var p = alex
                    p.environment = env
                    p.equipment = env.presetEquipment
                    p.limitations = limitation.map { [$0] } ?? []
                    p.trainingDays = days
                    p.sessionMinutes = minutes
                    for (i, focus) in WeekPlanner.split(forDays: days).enumerated() {
                        let plan = SessionBuilder.build(focus: focus, profile: p, variation: i)
                        if plan.exercises.isEmpty { print("EMPTY", env, focus, minutes, String(describing: limitation)) }; #expect(!plan.exercises.isEmpty)
                        for planned in plan.exercises {
                            let ex = library[planned.exerciseID]!
                            #expect(ex.isAvailable(with: p.equipment), "\(ex.id) needs gear for \(env)")
                            #expect(ex.isSafe(for: p.limitations), "\(ex.id) flagged for \(String(describing: limitation))")
                        }
                        #expect(Set(plan.exercises.map(\.exerciseID)).count == plan.exercises.count)
                    }
                }
            }
        }
    }
}

@Test func beginnersGetNoDifficultyThree() {
    var p = alex
    p.experience = .beginner
    p.environment = .fullGym
    p.equipment = TrainingEnvironment.fullGym.presetEquipment
    for focus in SessionFocus.allCases {
        for planned in SessionBuilder.build(focus: focus, profile: p).exercises {
            #expect(library[planned.exerciseID]!.difficulty <= 2)
        }
    }
}

@Test func swapReturnsTopThreeSamePatternAndFast() {
    let bench = library["bb_bench_press"]!
    let clock = ContinuousClock()
    var options: [SwapOption] = []
    let elapsed = clock.measure {
        options = SwapRanker.alternatives(for: bench, equipment: TrainingEnvironment.fullGym.presetEquipment,
                                          limitations: [], currentLoadKg: 80)
    }
    #expect(options.count == 3)
    #expect(options.allSatisfy { $0.exercise.pattern == .horizontalPush && $0.exercise.id != bench.id })
    #expect(elapsed < .milliseconds(300))   // PRD F3: under 300 ms offline
}

@Test func swapRespectsLimitations() {
    let bench = library["bb_bench_press"]!
    let options = SwapRanker.alternatives(for: bench, equipment: TrainingEnvironment.fullGym.presetEquipment,
                                          limitations: [.shoulders])
    #expect(options.allSatisfy { !$0.exercise.contraindications.contains(.shoulders) })
    #expect(options.allSatisfy { $0.easierOnJoints })
}

@Test func benchToDumbbellCarriesPointFourPerHand() {
    // PRD example: barbell bench → dumbbell press ≈ 0.4 × barbell load per hand.
    let converted = LoadConverter.convert(100, from: library["bb_bench_press"]!, to: library["db_flat_press"]!)
    #expect(converted == 40)
    #expect(LoadConverter.convert(100, from: library["bb_bench_press"]!, to: library["push_up"]!) == nil)
}

@Test func travelKeepsPatternsAndUsesOnlyTheKit() {
    var p = alex
    p.environment = .fullGym
    p.equipment = TrainingEnvironment.fullGym.presetEquipment
    for focus in SessionFocus.allCases {
        let plan = SessionBuilder.build(focus: focus, profile: p)
        for kit in TravelKit.allCases {
            let travel = TravelConverter.convert(plan, kit: kit, limitations: p.limitations)
            #expect(!travel.exercises.isEmpty)
            let originalPatterns = plan.exercises.map { library[$0.exerciseID]!.pattern }
            for (converted, originalPattern) in zip(travel.exercises, originalPatterns) where travel.exercises.count == plan.exercises.count {
                #expect(library[converted.exerciseID]!.pattern == originalPattern)
            }
            for converted in travel.exercises {
                #expect(library[converted.exerciseID]!.isAvailable(with: kit.equipment))
            }
        }
    }
}

@Test func trimmedKeepsThreeCompoundsAtTwoSets() {
    let plan = SessionBuilder.build(focus: .upper, profile: alex)
    let pivot = EnergyPivot.pivot(energy: .low, lowYesterday: false, plannedMinutes: 45)
    let trimmed = SessionBuilder.apply(pivot, to: plan, profile: alex)
    #expect(trimmed.exercises.count <= 3)
    #expect(trimmed.exercises.allSatisfy { $0.sets == 2 && $0.rpeCap == 7 })
    #expect(trimmed.exercises.allSatisfy { library[$0.exerciseID]!.compound })
}

@Test func minimumIsMobilityPlusOneEasyCompound() {
    let plan = SessionBuilder.build(focus: .lower, profile: alex)
    let pivot = EnergyPivot.pivot(energy: .low, lowYesterday: true, plannedMinutes: 45)
    let minimum = SessionBuilder.apply(pivot, to: plan, profile: alex)
    let patterns = minimum.exercises.map { library[$0.exerciseID]!.pattern }
    #expect(patterns.filter { $0 == .mobility }.count == 2)
    #expect(minimum.exercises.filter { library[$0.exerciseID]!.compound }.count == 1)
    #expect(minimum.variant == .minimum)
}

@Test func loadedLiftSwapsToALoadedLiftWhenGearAllows() {
    let press = library["db_flat_press"]!
    let options = SwapRanker.alternatives(for: press, equipment: TrainingEnvironment.homeGym.presetEquipment,
                                          limitations: [], currentLoadKg: 20)
    #expect(options.first?.exercise.loadGroup == "press_horizontal")
    #expect(options.first?.carriedLoadKg != nil)
}

@Test func verticalPullSlotPrefersACompoundPull() {
    var p = alex
    p.limitations = []
    for variation in 0...1 {
        let plan = SessionBuilder.build(focus: .upper, profile: p, variation: variation)
        let pulls = plan.exercises.compactMap { library[$0.exerciseID] }.filter { $0.pattern == .verticalPull }
        #expect(pulls.allSatisfy { $0.compound }, "\(pulls.map(\.id))")
    }
}
