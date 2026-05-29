import Foundation

// MARK: - HealthStoreProviding
// Stub protocol for Phase 1. Full implementation comes in Phase 4 (HealthKit Integration).

/// Abstracts HKHealthStore for testability.
public protocol HealthStoreProviding: AnyObject, Sendable {
    /// Check whether HealthKit is available on the current device.
    var isHealthDataAvailable: Bool { get }
}
