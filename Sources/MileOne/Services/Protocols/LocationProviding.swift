import Foundation
import CoreLocation

// MARK: - LocationProviding

/// Abstracts CLLocationManager for testability.
/// Callbacks allow the RunEngine to receive location updates, authorization changes, and errors.
public protocol LocationProviding: AnyObject, Sendable {
    /// Current authorization status for location services.
    var authorizationStatus: CLAuthorizationStatus { get }

    /// Called when a new location is available.
    var onLocationUpdate: ((CLLocation) -> Void)? { get set }
    /// Called when the authorization status changes.
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)? { get set }
    /// Called when a location error occurs.
    var onLocationError: ((Error) -> Void)? { get set }

    /// Request "when in use" location authorization.
    func requestWhenInUseAuthorization()
    /// Request "always" location authorization (needed for background tracking).
    func requestAlwaysAuthorization()
    /// Begin streaming location updates.
    func startUpdatingLocation()
    /// Stop streaming location updates.
    func stopUpdatingLocation()
}
