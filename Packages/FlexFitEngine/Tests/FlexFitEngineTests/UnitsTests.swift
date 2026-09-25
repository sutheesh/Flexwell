import Testing
@testable import FlexFitEngine

@Test func poundsRoundTrip() {
    let kg = 82.1
    let lb = Mass.display(kilograms: kg, in: .imperial)
    #expect(abs(Mass.kilograms(from: lb, in: .imperial) - kg) < 1e-9)
}

@Test func metricIsIdentity() {
    #expect(Mass.display(kilograms: 75, in: .metric) == 75)
}
