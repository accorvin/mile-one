import Foundation
import CoreLocation

// MARK: - RouteResult

/// Value type returned from DirectionsProviding.
/// Avoids direct use of MKRoute (which cannot be constructed in tests).
public struct RouteResult: Sendable {
    /// Distance in meters.
    public let distance: CLLocationDistance
    /// Estimated travel time in seconds.
    public let expectedTravelTime: TimeInterval
    /// Decoded polyline coordinates.
    public let polylineCoordinates: [CLLocationCoordinate2D]

    public init(
        distance: CLLocationDistance,
        expectedTravelTime: TimeInterval,
        polylineCoordinates: [CLLocationCoordinate2D]
    ) {
        self.distance = distance
        self.expectedTravelTime = expectedTravelTime
        self.polylineCoordinates = polylineCoordinates
    }
}
