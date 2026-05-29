import Foundation
import CoreLocation

// MARK: - LocationService

/// Production CLLocationManager wrapper implementing `LocationProviding`.
///
/// CLLocationManager requires main-thread usage, so this class is `@unchecked Sendable`
/// to satisfy the `Sendable` requirement of `LocationProviding` while keeping all
/// delegate callbacks on the main thread.
public final class LocationService: NSObject, LocationProviding, CLLocationManagerDelegate, @unchecked Sendable {

    // MARK: - Properties

    private let manager: CLLocationManager

    public var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }

    public var onLocationUpdate: ((CLLocation) -> Void)?
    public var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?
    public var onLocationError: ((Error) -> Void)?

    // MARK: - Init

    public override init() {
        manager = CLLocationManager()
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = Constants.gpsDistanceFilter
    }

    // MARK: - LocationProviding

    public func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    public func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }

    public func startUpdatingLocation() {
        manager.startUpdatingLocation()
    }

    public func stopUpdatingLocation() {
        manager.stopUpdatingLocation()
    }

    // MARK: - CLLocationManagerDelegate

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        onLocationUpdate?(location)
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        onLocationError?(error)
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus

        // Enable background updates only after authorization is granted.
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            #if os(iOS)
            manager.allowsBackgroundLocationUpdates = true
            #endif
        default:
            break
        }

        onAuthorizationChange?(status)
    }
}
