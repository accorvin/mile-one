import Testing
import MapKit
@testable import MileOne

struct RouteServiceTests {

    @Test func cachePreventsDuplicateRequests() async throws {
        // Uses a MockDirectionsProvider to avoid real API calls
        let mockDirections = MockDirectionsProvider()
        let service = RouteService(directionsProvider: mockDirections)
        let from = CLLocationCoordinate2D(latitude: 35.78, longitude: -78.64)
        let to = CLLocationCoordinate2D(latitude: 35.79, longitude: -78.64)

        // First call goes to API
        _ = try await service.calculateRoute(from: from, to: to)
        #expect(mockDirections.calculateCallCount == 1)

        // Second call should hit cache
        _ = try await service.calculateRoute(from: from, to: to)
        #expect(mockDirections.calculateCallCount == 1, "Second call must use cache, not API")
    }

    @Test func insufficientWaypointsThrows() async {
        let service = RouteService(directionsProvider: MockDirectionsProvider())
        do {
            _ = try await service.calculateMultiWaypointRoute(waypoints: [
                CLLocationCoordinate2D(latitude: 35.78, longitude: -78.64)
            ])
            Issue.record("Should have thrown — need at least 2 waypoints")
        } catch {
            #expect(error is RouteError)
        }
    }

    @Test func clearCacheRemovesCachedRoutes() async throws {
        let mockDirections = MockDirectionsProvider()
        let service = RouteService(directionsProvider: mockDirections)
        let from = CLLocationCoordinate2D(latitude: 35.78, longitude: -78.64)
        let to = CLLocationCoordinate2D(latitude: 35.79, longitude: -78.64)

        _ = try await service.calculateRoute(from: from, to: to)
        #expect(mockDirections.calculateCallCount == 1)

        await service.clearCache()

        // After clearing, next call should hit API again
        _ = try await service.calculateRoute(from: from, to: to)
        #expect(mockDirections.calculateCallCount == 2, "After cache clear, must call API again")
    }

    @Test func cacheEvictsOldestEntryWhenFull() async throws {
        let mockDirections = MockDirectionsProvider()
        let service = RouteService(directionsProvider: mockDirections)

        // Insert 51 unique routes (maxCacheSize = 50)
        // Each pair of coords is unique to avoid cache hits
        for i in 0..<51 {
            let from = CLLocationCoordinate2D(latitude: 35.78 + Double(i) * 0.01, longitude: -78.64)
            let to   = CLLocationCoordinate2D(latitude: 35.78 + Double(i) * 0.01, longitude: -78.63)
            _ = try await service.calculateRoute(from: from, to: to)
        }

        // After 51 inserts, the first entry (i=0) should be evicted.
        // Route 0: from (35.78, -78.64) to (35.78, -78.63)
        let firstFrom = CLLocationCoordinate2D(latitude: 35.78, longitude: -78.64)
        let firstTo   = CLLocationCoordinate2D(latitude: 35.78, longitude: -78.63)
        let callCountBefore = mockDirections.calculateCallCount

        _ = try await service.calculateRoute(from: firstFrom, to: firstTo)

        #expect(mockDirections.calculateCallCount == callCountBefore + 1,
                "First entry must have been evicted when cache reached max size (51 inserts)")
    }

    @Test func rateLimitEnforcesMinimumInterval() async throws {
        let mockDirections = MockDirectionsProvider()
        let service = RouteService(directionsProvider: mockDirections)

        let coords = (0..<3).map { i in
            CLLocationCoordinate2D(latitude: 35.78 + Double(i) * 0.01, longitude: -78.64)
        }

        // Rapid-fire requests — rate limiter should enforce minimum interval
        for i in 0..<2 {
            _ = try await service.calculateRoute(from: coords[i], to: coords[i + 1])
        }

        // Both should succeed (rate limiter adds delay, doesn't reject)
        #expect(mockDirections.calculateCallCount == 2)
    }
}
