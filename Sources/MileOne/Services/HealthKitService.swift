#if canImport(HealthKit)
import Foundation
import HealthKit
import CoreLocation

// MARK: - HealthKitService

/// Production HealthKit implementation.
/// Wraps HKHealthStore and manages the workout route builder internally.
/// All methods are async and use the native iOS 15+ async HealthKit APIs.
public final class HealthKitService: HealthStoreProviding, @unchecked Sendable {

    // MARK: - Permission Sets

    /// Sample types Mile One writes to HealthKit.
    public static let shareTypes: Set<HKSampleType> = [
        HKWorkoutType.workoutType(),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.distanceWalkingRunning),
    ]

    /// Object types Mile One reads from HealthKit.
    public static let readTypes: Set<HKObjectType> = [
        HKWorkoutType.workoutType(),
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.distanceWalkingRunning),
        HKQuantityType(.heartRate),
        HKQuantityType(.height),
        HKQuantityType(.bodyMass),
        HKCharacteristicType(.dateOfBirth),
        HKCharacteristicType(.biologicalSex),
    ]

    // MARK: - Private State

    private let store: HKHealthStore

    /// Internal route builder — owned here so it doesn't appear on the protocol.
    private var routeBuilder: HKWorkoutRouteBuilder?

    // MARK: - Init

    public init() {
        self.store = HKHealthStore()
    }

    // MARK: - HealthStoreProviding

    public var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    public func requestAuthorization(
        toShare: Set<HKSampleType>,
        read: Set<HKObjectType>
    ) async throws -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        // Native async API (iOS 15+) — no continuation wrappers needed.
        try await store.requestAuthorization(toShare: toShare, read: read)

        // HKHealthStore.requestAuthorization doesn't return a Bool in the async variant —
        // check authorization status for one of our write types to determine outcome.
        let status = store.authorizationStatus(for: HKWorkoutType.workoutType())
        return status == .sharingAuthorized
    }

    public func saveWorkout(
        activityType: HKWorkoutActivityType,
        start: Date,
        end: Date,
        totalDistance: HKQuantity,
        totalEnergyBurned: HKQuantity
    ) async throws -> HKWorkout {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        let status = store.authorizationStatus(for: HKWorkoutType.workoutType())
        guard status == .sharingAuthorized else {
            throw HealthKitError.authorizationDenied
        }

        // Build the configuration
        let config = HKWorkoutConfiguration()
        config.activityType = activityType
        config.locationType = .outdoor

        // Use the builder API which is the recommended path in iOS 16+
        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())

        try await builder.beginCollection(at: start)

        // Add distance and energy samples
        let distanceSample = HKQuantitySample(
            type: HKQuantityType(.distanceWalkingRunning),
            quantity: totalDistance,
            start: start,
            end: end
        )
        let energySample = HKQuantitySample(
            type: HKQuantityType(.activeEnergyBurned),
            quantity: totalEnergyBurned,
            start: start,
            end: end
        )
        try await builder.addSamples([distanceSample, energySample])
        try await builder.endCollection(at: end)

        guard let workout = try await builder.finishWorkout() else {
            throw HealthKitError.saveFailed(description: "HKWorkoutBuilder returned nil workout")
        }

        // Initialize the route builder for subsequent insertRouteData calls
        routeBuilder = HKWorkoutRouteBuilder(healthStore: store, device: .local())

        return workout
    }

    public func queryHeartRateSamples(
        start: Date,
        end: Date
    ) async throws -> [HKQuantitySample] {
        let heartRateType = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: .strictStartDate
        )
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: heartRateType, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        )
        let results = try await descriptor.result(for: store)
        return results
    }

    public func insertRouteData(_ locations: [CLLocation]) async throws {
        guard let builder = routeBuilder else {
            throw HealthKitError.saveFailed(description: "Route builder not initialized — call saveWorkout first")
        }
        try await builder.insertRouteData(locations)
    }

    public func finishRoute(with workout: HKWorkout) async throws {
        guard let builder = routeBuilder else {
            throw HealthKitError.saveFailed(description: "Route builder not initialized — call saveWorkout first")
        }
        try await builder.finishRoute(with: workout, metadata: nil)
        routeBuilder = nil
    }
}
#endif
