import Foundation
import CoreLocation
import Observation

// MARK: - RoutePlannerViewModel

/// ViewModel for the Route Planner screen.
/// Manages waypoints, route calculation, and path simplification.
@MainActor
@Observable
public final class RoutePlannerViewModel {

    // MARK: - State

    /// Ordered list of waypoints placed by the user.
    public var waypoints: [CLLocationCoordinate2D] = []

    /// Total distance of the calculated route in meters.
    public var totalDistance: Double = 0

    /// Whether a route calculation is in progress.
    public var isCalculating: Bool = false

    /// Last error from route calculation (if any).
    public var lastError: (any Error)?

#if canImport(MapKit)
    // MARK: - Dependencies

    private let routeService: RouteService

    // MARK: - Init

    public init(routeService: RouteService) {
        self.routeService = routeService
    }
#else
    public init() {}
#endif

    // MARK: - Computed

    /// True when at least 2 waypoints are present (minimum for route calculation).
    public var canCalculateRoute: Bool {
        waypoints.count >= 2
    }

    // MARK: - Waypoint Management

    /// Append a waypoint to the end of the list.
    public func addWaypoint(_ coordinate: CLLocationCoordinate2D) {
        waypoints.append(coordinate)
    }

    /// Remove the most recently added waypoint.
    public func removeLastWaypoint() {
        guard !waypoints.isEmpty else { return }
        waypoints.removeLast()
    }

    /// Clear all waypoints and reset route state.
    public func clearAll() {
        waypoints.removeAll()
        totalDistance = 0
        lastError = nil
    }

    // MARK: - Route Calculation

    /// Calculate the route through all current waypoints and update `totalDistance`.
#if canImport(MapKit)
    public func calculateRoute() async {
        guard canCalculateRoute else { return }
        isCalculating = true
        lastError = nil
        defer { isCalculating = false }

        do {
            let segments = try await routeService.calculateMultiWaypointRoute(waypoints: waypoints)
            totalDistance = segments.reduce(0) { $0 + $1.distance }
        } catch {
            lastError = error
        }
    }
#else
    public func calculateRoute() async {}
#endif

    // MARK: - Douglas-Peucker Path Simplification

    /// Simplify a path of coordinates using the Douglas-Peucker algorithm.
    /// - Parameters:
    ///   - points: The input coordinate array.
    ///   - epsilon: Tolerance in degrees. Points within this distance of the line are removed.
    /// - Returns: A simplified array preserving the shape's significant points.
    public static func simplifyPath(
        _ points: [CLLocationCoordinate2D],
        epsilon: Double
    ) -> [CLLocationCoordinate2D] {
        guard points.count > 2 else { return points }

        let start = points.first!
        let end = points.last!

        var maxDistance = 0.0
        var maxIndex = 0

        for i in 1..<(points.count - 1) {
            let d = perpendicularDistance(points[i], lineStart: start, lineEnd: end)
            if d > maxDistance {
                maxDistance = d
                maxIndex = i
            }
        }

        if maxDistance > epsilon {
            let left = simplifyPath(Array(points[...maxIndex]), epsilon: epsilon)
            let right = simplifyPath(Array(points[maxIndex...]), epsilon: epsilon)
            return left.dropLast() + right
        } else {
            return [start, end]
        }
    }

    /// Compute the perpendicular distance from a point to a line segment (in degrees).
    static func perpendicularDistance(
        _ point: CLLocationCoordinate2D,
        lineStart: CLLocationCoordinate2D,
        lineEnd: CLLocationCoordinate2D
    ) -> Double {
        let dx = lineEnd.longitude - lineStart.longitude
        let dy = lineEnd.latitude - lineStart.latitude

        let lenSquared = dx * dx + dy * dy
        guard lenSquared > 0 else {
            // Degenerate segment: distance to the start point
            let px = point.longitude - lineStart.longitude
            let py = point.latitude - lineStart.latitude
            return sqrt(px * px + py * py)
        }

        // Projection parameter
        let t = ((point.longitude - lineStart.longitude) * dx
               + (point.latitude - lineStart.latitude) * dy) / lenSquared

        let clampedT = max(0, min(1, t))
        let projX = lineStart.longitude + clampedT * dx
        let projY = lineStart.latitude + clampedT * dy

        let px = point.longitude - projX
        let py = point.latitude - projY
        return sqrt(px * px + py * py)
    }
}
