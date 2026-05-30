#if canImport(MapKit)
import Foundation
import CoreLocation
import MapKit

// MARK: - RouteService

/// Actor that manages route calculation with caching and rate limiting.
/// Uses a `DirectionsProviding` dependency for testability.
public actor RouteService {

    // MARK: - Cache

    /// LRU cache entry: key + insertion order.
    private struct CacheEntry {
        let key: String
        let result: RouteResult
        let insertedAt: Date
    }

    private var cache: [String: CacheEntry] = [:]
    private var cacheOrder: [String] = []
    private let maxCacheSize = 50

    // MARK: - Rate Limiting

    private var lastRequestTime: Date = .distantPast
    private let minimumRequestInterval: TimeInterval = 2.0

    // MARK: - Dependencies

    private let directionsProvider: any DirectionsProviding

    // MARK: - Init

    public init(directionsProvider: any DirectionsProviding = MKDirectionsProvider()) {
        self.directionsProvider = directionsProvider
    }

    // MARK: - Public API

    /// Calculate a route between two coordinates.
    /// Results are cached; repeated calls with the same coordinates skip the API.
    public func calculateRoute(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) async throws -> RouteResult {
        let key = cacheKey(from: from, to: to)

        if let cached = cache[key] {
            return cached.result
        }

        try await enforceRateLimit()

        let result = try await directionsProvider.calculate(from: from, to: to)
        storeInCache(key: key, result: result)
        return result
    }

    /// Calculate a route through multiple waypoints sequentially.
    /// Throws `RouteError.insufficientWaypoints` if fewer than 2 waypoints provided.
    public func calculateMultiWaypointRoute(
        waypoints: [CLLocationCoordinate2D]
    ) async throws -> [RouteResult] {
        guard waypoints.count >= 2 else {
            throw RouteError.insufficientWaypoints
        }

        var results: [RouteResult] = []
        for i in 0..<(waypoints.count - 1) {
            let segment = try await calculateRoute(from: waypoints[i], to: waypoints[i + 1])
            results.append(segment)
        }
        return results
    }

    /// Clear all cached routes.
    public func clearCache() {
        cache.removeAll()
        cacheOrder.removeAll()
    }

    // MARK: - Cache Helpers

    private func cacheKey(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> String {
        let r = { (v: Double) in String(format: "%.6f", v) }
        return "\(r(from.latitude)),\(r(from.longitude))→\(r(to.latitude)),\(r(to.longitude))"
    }

    private func storeInCache(key: String, result: RouteResult) {
        // Evict oldest entry if at capacity
        if cache.count >= maxCacheSize, let oldest = cacheOrder.first {
            cache.removeValue(forKey: oldest)
            cacheOrder.removeFirst()
        }
        let entry = CacheEntry(key: key, result: result, insertedAt: Date())
        cache[key] = entry
        cacheOrder.append(key)
    }

    // MARK: - Rate Limiting

    private func enforceRateLimit() async throws {
        let elapsed = Date().timeIntervalSince(lastRequestTime)
        if elapsed < minimumRequestInterval {
            let delay = minimumRequestInterval - elapsed
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        lastRequestTime = Date()
    }
}
#endif
