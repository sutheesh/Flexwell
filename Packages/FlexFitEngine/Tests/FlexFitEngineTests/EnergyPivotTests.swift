import Testing
@testable import FlexFitEngine

@Test func highIsFullWithFinisherAtRPE9() {
    let r = EnergyPivot.pivot(energy: .high, lowYesterday: false, plannedMinutes: 45)
    #expect(r.variant == .full && r.minutes == 45 && r.rpeCap == 9 && r.offersFinisher)
}

@Test func okIsAsPlannedAtRPE8() {
    let r = EnergyPivot.pivot(energy: .ok, lowYesterday: true, plannedMinutes: 45)
    #expect(r.variant == .full && r.minutes == 45 && r.rpeCap == 8)
}

@Test(arguments: [(60, 35), (45, 25), (30, 15), (20, 15)])
func lowTrimsToAtMostSixtyPercent(planned: Int, expected: Int) {
    let r = EnergyPivot.pivot(energy: .low, lowYesterday: false, plannedMinutes: planned)
    #expect(r.variant == .trimmed && r.minutes == expected && r.rpeCap == 7)
    #expect(!r.suggestMaintenanceDay)
}

@Test func secondLowDayIsMinimumAndSuggestsMaintenance() {
    let r = EnergyPivot.pivot(energy: .low, lowYesterday: true, plannedMinutes: 45)
    #expect(r.variant == .minimum && (15...20).contains(r.minutes) && r.rpeCap == 6 && r.suggestMaintenanceDay)
}
