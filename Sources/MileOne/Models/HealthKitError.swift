import Foundation

// MARK: - HealthKitError

/// Errors thrown by HealthKit operations. All cases are Sendable-safe.
public enum HealthKitError: Error, Sendable, Equatable {
    case authorizationDenied
    case notAvailable
    case saveFailed(description: String)
}
