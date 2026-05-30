#if canImport(MapKit)
import Foundation
import CoreLocation
@testable import MileOne

// MARK: - MockDirectionsProvider

/// Test double for DirectionsProviding.
/// Returns configurable mock routes without hitting the MapKit API.
public final class MockDirectionsProvider: DirectionsProviding, @unchecked Sendable {

    // MARK: - Configuration

    /// Distance (meters) returned by every mock calculate call.
    public var mockDistance: CLLocationDistance = 500

    /// Expected travel time (seconds) returned by every mock call.
    public var mockExpectedTravelTime: TimeInterval = 300

    // MARK: - Tracking

    /// Number of times `calculate` was called (cache hit = no increment).
    public private(set) var calculateCallCount: Int = 0

    // MARK: - Init

    public init() {}

    // MARK: - DirectionsProviding

    public func calculate(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) async throws -> RouteResult {
        calculateCallCount += 1
        return RouteResult(
            distance: mockDistance,
            expectedTravelTime: mockExpectedTravelTime,
            polylineCoordinates: [from, to]
        )
    }
}
// MARK: - FailingDirectionsProvider

/// Always throws an error — used to test failure paths.
public final class FailingDirectionsProvider: DirectionsProviding, @unchecked Sendable {
    public init() {}

    public func calculate(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) async throws -> RouteResult {
        throw RouteError.serverFailure
    }
}
#endif
