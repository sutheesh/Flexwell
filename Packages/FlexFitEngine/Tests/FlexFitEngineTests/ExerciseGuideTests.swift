import Testing
@testable import FlexFitEngine

@Test func everyExerciseHasAGuide() {
    for ex in ExerciseLibrary.bundled.exercises {
        let guide = ExerciseGuides.bundled[ex.id]
        #expect(guide != nil, "no guide for \(ex.id)")
        #expect((guide?.steps.count ?? 0) >= 3, "too few steps for \(ex.id)")
        #expect(!(guide?.cues.isEmpty ?? true), "no cues for \(ex.id)")
    }
    #expect(ExerciseGuides.reviewStatus.contains("draft"))
}

@Test func everyMuscleBelongsToOneGroupAndEveryGroupHasExercises() {
    for muscle in Muscle.allCases {
        #expect(MuscleGroup.allCases.filter { $0.muscles.contains(muscle) }.count == 1, "\(muscle)")
    }
    for group in MuscleGroup.allCases {
        #expect(!group.exercises().isEmpty, "\(group) has no exercises")
    }
}

@Test func groupListsPrimaryBeforeSecondary() {
    let list = MuscleGroup.chest.exercises()
    let firstSecondary = list.firstIndex { !$0.primaryMuscles.contains(.chest) } ?? list.count
    #expect(list[..<firstSecondary].allSatisfy { $0.primaryMuscles.contains(.chest) })
}
