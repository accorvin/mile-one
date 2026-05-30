import Foundation
@testable import MileOne
import CoreLocation

final class MockLocationProvider: LocationProviding, @unchecked Sendable {
    #if os(iOS)
    var authorizationStatus: CLAuthorizationStatus = .authorizedWhenInUse
    #else
    var authorizationStatus: CLAuthorizationStatus = .authorized
    #endif
    var onLocationUpdate: ((CLLocation) -> Void)?
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?
    var onLocationError: ((Error) -> Void)?

    private(set) var startUpdatingCalled = false
    private(set) var stopUpdatingCalled = false
    private(set) var requestWhenInUseCalled = false
    private(set) var requestAlwaysCalled = false

    func requestWhenInUseAuthorization() { requestWhenInUseCalled = true }
    func requestAlwaysAuthorization() { requestAlwaysCalled = true }
    func startUpdatingLocation() { startUpdatingCalled = true }
    func stopUpdatingLocation() { stopUpdatingCalled = true; startUpdatingCalled = false }

    /// Simulate a GPS location update with sensible defaults (Raleigh, NC).
    func simulateLocation(
        lat: Double = 35.7796,
        lng: Double = -78.6382,
        timestamp: Date = Date(),
        accuracy: Double = 10
    ) {
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
            altitude: 100,
            horizontalAccuracy: accuracy,
            verticalAccuracy: 10,
            timestamp: timestamp
        )
        onLocationUpdate?(location)
    }
}
