import Foundation

// MARK: - RouteError

/// Errors thrown by RouteService.
public enum RouteError: Error, Sendable {
    /// Fewer than 2 waypoints were provided.
    case insufficientWaypoints
    /// The directions request failed.
    case directionsRequestFailed(underlying: any Error)
    /// The server returned an error (used for retry logic).
    case serverFailure
}
