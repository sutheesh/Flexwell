import Foundation
import HealthKit

/// Apple Health: read body weight, write strength workouts (PRD F6/F7). Asked only when the user turns it on.
final class HealthService: Sendable {
    static let shared = HealthService()
    private let store = HKHealthStore()

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        let read: Set<HKObjectType> = [HKQuantityType(.bodyMass)]
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
}
