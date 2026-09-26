import Foundation
import Testing
@testable import FlexFitEngine

private func day(_ d: Int) -> Date { Date(timeIntervalSince1970: 1_767_268_800 + Double(d) * 86_400) } // Thu 1 Jan 2026, midday UTC

@Test func changeUsesFirstAndLatestByDate() {
    let c = ProgressReport.change([(day(10), 18.0), (day(0), 21.0), (day(5), 20.0)])
    #expect(c?.first == 21 && c?.latest == 18 && c?.delta == -3)
    #expect(ProgressReport.change([]) == nil)
}

@Test func weeklyCaloriesAverageLoggedDaysOnly() {
    let weeks = ProgressReport.weeklyCalories([(day(4), 2000), (day(5), 2200), (day(6), 0), (day(11), 1800)])
    #expect(weeks.count == 2)
    #expect(weeks[0].averageKcal == 2100 && weeks[0].daysLogged == 2)
    #expect(weeks[1].averageKcal == 1800)
}

@Test func daysOnTargetIsWithinTenPercent() {
    #expect(ProgressReport.daysOnTarget([(2000, 2000), (2190, 2000), (2300, 2000), (0, 2000), (1810, 2000)]) == 3)
}

@Test func trainingCapsLongSessionsAndSumsLoad() {
    let sets = [SetResult(value: 10, loadKg: 20), SetResult(value: 8, loadKg: nil)]
    let t = ProgressReport.training([(day(0), day(0).addingTimeInterval(3600), sets),
                                     (day(1), day(1).addingTimeInterval(10 * 3600), [])])
    #expect(t.sessions == 2 && t.hours == 4 && t.liftedKg == 200)
}

@Test func checkInIsDueAfterAWeekWithoutWeighIn() {
    #expect(ProgressReport.checkInDue(lastWeighIn: day(0), lastBodyMetric: day(0), now: day(8)))
    #expect(!ProgressReport.checkInDue(lastWeighIn: day(5), lastBodyMetric: day(0), now: day(8)))
    #expect(ProgressReport.checkInDue(lastWeighIn: day(5), lastBodyMetric: nil, now: day(8)))
}
