import Foundation
import HealthKit
import FlexFitEngine

/// Apple Health: read body weight, body composition, steps and walking distance; write strength workouts.
/// Asked only when the user turns it on.
final class HealthService: Sendable {
    static let shared = HealthService()
    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        let read: Set<HKObjectType> = [
            HKQuantityType(.bodyMass), HKQuantityType(.bodyFatPercentage), HKQuantityType(.leanBodyMass),
            HKQuantityType(.waistCircumference), HKQuantityType(.stepCount), HKQuantityType(.distanceWalkingRunning),
        ]
        let write: Set<HKSampleType> = [HKObjectType.workoutType()]
        do {
            try await store.requestAuthorization(toShare: write, read: read)
            return true
        } catch {
            return false
        }
    }

    /// Saves a finished session as a traditional strength training workout.
    func saveStrengthWorkout(start: Date, end: Date) async -> Bool {
        guard isAvailable else { return false }
        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        do {
            try await builder.beginCollection(at: start)
            try await builder.endCollection(at: end)
            _ = try await builder.finishWorkout()
            return true
        } catch {
            return false
        }
    }

    /// Body-weight samples since `date`, in kg.
    func weights(since date: Date) async -> [(Date, Double)] {
        guard isAvailable else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: date, end: nil)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: HKQuantityType(.bodyMass), predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        guard let samples = try? await descriptor.result(for: store) else { return [] }
        return samples.map { ($0.startDate, $0.quantity.doubleValue(for: .gramUnit(with: .kilo))) }
    }

    /// Body fat (%), lean mass (kg) or waist (cm) samples since `date`.
    func bodyMetrics(_ metric: ProgressReport.BodyMetric, since date: Date) async -> [(Date, Double)] {
        guard isAvailable else { return [] }
        let (type, unit): (HKQuantityType, HKUnit) = switch metric {
        case .bodyFatPercent: (HKQuantityType(.bodyFatPercentage), .percent())
        case .leanMassKg: (HKQuantityType(.leanBodyMass), .gramUnit(with: .kilo))
        case .waistCm: (HKQuantityType(.waistCircumference), .meterUnit(with: .centi))
        }
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: HKQuery.predicateForSamples(withStart: date, end: nil))],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        guard let samples = try? await descriptor.result(for: store) else { return [] }
        // Health stores body fat as a fraction (0.21); we show a percentage.
        return samples.map { ($0.startDate, $0.quantity.doubleValue(for: unit) * (metric == .bodyFatPercent ? 100 : 1)) }
    }

    /// Steps and walking + running distance (km) since `date`, and the distance per week (Monday starts).
    struct Walking: Sendable {
        var steps: Double = 0
        var km: Double = 0
        var weeklyKm: [WeekValue] = []
    }

    func walking(since date: Date) async -> Walking {
        guard isAvailable else { return Walking() }
        async let steps = sum(.stepCount, unit: .count(), since: date)
        async let km = sum(.distanceWalkingRunning, unit: .meterUnit(with: .kilo), since: date)
        async let weekly = weeklyDistance(since: date)
        return await Walking(steps: steps, km: km, weeklyKm: weekly)
    }

    private func sum(_ id: HKQuantityTypeIdentifier, unit: HKUnit, since date: Date) async -> Double {
        let window = HKQuery.predicateForSamples(withStart: date, end: .now)
        let descriptor = HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(id), predicate: window), options: .cumulativeSum)
        return (try? await descriptor.result(for: store))?.sumQuantity()?.doubleValue(for: unit) ?? 0
    }

    private func weeklyDistance(since date: Date) async -> [WeekValue] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        let anchor = cal.date(byAdding: .day, value: -((cal.component(.weekday, from: start) + 5) % 7), to: start) ?? start
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: HKQuantityType(.distanceWalkingRunning),
                                       predicate: HKQuery.predicateForSamples(withStart: anchor, end: .now)),
            options: .cumulativeSum, anchorDate: anchor, intervalComponents: DateComponents(day: 7))
        guard let collection = try? await descriptor.result(for: store) else { return [] }
        return collection.statistics().map { WeekValue(weekOf: $0.startDate, value: $0.sumQuantity()?.doubleValue(for: .meterUnit(with: .kilo)) ?? 0) }
    }
}

/// One value per week (Monday start), for charts.
struct WeekValue: Identifiable, Sendable, Hashable {
    let weekOf: Date
    let value: Double
    var id: Date { weekOf }
}
