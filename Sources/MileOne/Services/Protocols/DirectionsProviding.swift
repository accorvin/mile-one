#if canImport(MapKit)
import Foundation
import CoreLocation
import MapKit

// MARK: - DirectionsProviding

/// Protocol for calculating routes between coordinates.
/// Abstracting MKDirections enables unit-testable RouteService.
public protocol DirectionsProviding: Sendable {
    func calculate(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) async throws -> RouteResult
}

// MARK: - MKDirectionsProvider

/// Real implementation that calls the MapKit Directions API.
public struct MKDirectionsProvider: DirectionsProviding {
    public init() {}

    public func calculate(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) async throws -> RouteResult {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        request.transportType = .walking

        let directions = MKDirections(request: request)
        let response = try await directions.calculate()

        guard let route = response.routes.first else {
            throw RouteError.directionsRequestFailed(underlying: RouteError.serverFailure)
        }

        // Extract polyline coordinates
        var coords = [CLLocationCoordinate2D](
            repeating: kCLLocationCoordinate2DInvalid,
            count: route.polyline.pointCount
        )
        route.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: route.polyline.pointCount))

        return RouteResult(
            distance: route.distance,
            expectedTravelTime: route.expectedTravelTime,
            polylineCoordinates: coords
        )
    }
}
#endif
