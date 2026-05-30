#if canImport(HealthKit)
import Foundation
import HealthKit
import CoreLocation
@testable import MileOne

// MARK: - MockHealthStore

/// Test double for HealthStoreProviding.
/// Uses @unchecked Sendable because mutable state is only mutated from test bodies,
/// which are structured and non-concurrent.
final class MockHealthStore: HealthStoreProviding, @unchecked Sendable {

    // MARK: - Configuration

    var isHealthDataAvailable: Bool = true
    var authorizationGranted: Bool = true

    // MARK: - Call Tracking

    var authorizationRequested: Bool = false

    /// Each call to saveWorkout appends a record here.
    var savedWorkouts: [MockWorkout] = []

    /// Each call to insertRouteData appends a batch here.
    var insertedRouteLocations: [[CLLocation]] = []

    /// Set to true when finishRoute is called.
    var routeFinalized: Bool = false

    /// Heart rate samples returned by queryHeartRateSamples.
    var mockHeartRateSamples: [HKQuantitySample] = []

    // MARK: - Recorded Workout

    struct MockWorkout {
        let activityType: HKWorkoutActivityType
        let start: Date
        let end: Date
        let distanceMeters: Double
        let caloriesKcal: Double
    }

    // MARK: - HealthStoreProviding

    func requestAuthorization(
        toShare: Set<HKSampleType>,
        read: Set<HKObjectType>
    ) async throws -> Bool {
        authorizationRequested = true
        return authorizationGranted
    }

    func saveWorkout(
        activityType: HKWorkoutActivityType,
        start: Date,
        end: Date,
        totalDistance: HKQuantity,
        totalEnergyBurned: HKQuantity
    ) async throws -> HKWorkout {
        guard authorizationGranted else {
            throw HealthKitError.authorizationDenied
        }
        savedWorkouts.append(MockWorkout(
            activityType: activityType,
            start: start,
            end: end,
            distanceMeters: totalDistance.doubleValue(for: .meter()),
            caloriesKcal: totalEnergyBurned.doubleValue(for: .kilocalorie())
        ))
        // Return a minimal HKWorkout for route builder finalization.
        return HKWorkout(activityType: activityType, start: start, end: end)
    }

    func queryHeartRateSamples(
        start: Date,
        end: Date
    ) async throws -> [HKQuantitySample] {
        return mockHeartRateSamples
    }

    func insertRouteData(_ locations: [CLLocation]) async throws {
        guard authorizationGranted else {
            throw HealthKitError.authorizationDenied
        }
        insertedRouteLocations.append(locations)
    }

    func finishRoute(with workout: HKWorkout) async throws {
        guard authorizationGranted else {
            throw HealthKitError.authorizationDenied
        }
        routeFinalized = true
    }
}
#endif
