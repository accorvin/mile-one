import Foundation

// MARK: - HealthStoreProviding
// Phase 4: Expanded from Phase 1 stub to full protocol.
// The entire protocol is guarded with #if canImport(HealthKit) because HealthKit
// is unavailable on macOS — all concrete types, HKWorkout, HKQuantitySample, etc.
// are iOS-only and cannot be referenced in macOS builds.

#if canImport(HealthKit)
import HealthKit
import CoreLocation

/// Abstracts HKHealthStore for testability.
/// Conforms to AnyObject (class-only) and Sendable for safe cross-actor use.
public protocol HealthStoreProviding: AnyObject, Sendable {

    /// Whether HealthKit is available on the current device.
    var isHealthDataAvailable: Bool { get }

    /// Request authorization for the given share and read types.
    /// Uses the native async API (iOS 15+).
    /// Returns true when authorized, false when denied.
    func requestAuthorization(
        toShare: Set<HKSampleType>,
        read: Set<HKObjectType>
    ) async throws -> Bool

    /// Save a workout to HealthKit. Returns the saved HKWorkout.
    func saveWorkout(
        activityType: HKWorkoutActivityType,
        start: Date,
        end: Date,
        totalDistance: HKQuantity,
        totalEnergyBurned: HKQuantity
    ) async throws -> HKWorkout

    /// Query heart rate samples within the given time window.
    func queryHeartRateSamples(
        start: Date,
        end: Date
    ) async throws -> [HKQuantitySample]

    /// Insert a batch of GPS locations into the current route builder.
    /// The production HealthKitService maintains the route builder internally.
    func insertRouteData(_ locations: [CLLocation]) async throws

    /// Finalize the GPS route and associate it with the given workout.
    func finishRoute(with workout: HKWorkout) async throws
}
#endif
