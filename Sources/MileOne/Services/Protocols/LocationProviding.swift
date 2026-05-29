import Foundation

// MARK: - LocationProviding
// Stub protocol for Phase 1. Full implementation comes in Phase 2 (Run Engine + GPS).

/// Abstracts CLLocationManager for testability.
public protocol LocationProviding: AnyObject, Sendable {
    /// Request "when in use" location authorization.
    func requestWhenInUseAuthorization()
    /// Request "always" location authorization (needed for background tracking).
    func requestAlwaysAuthorization()
    /// Begin streaming location updates.
    func startUpdatingLocation()
    /// Stop streaming location updates.
    func stopUpdatingLocation()
}
