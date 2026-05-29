← [Back to Index](README.md)

# Mile One — Phase 6: Route Planner

### Phase 6: Route Planner

**Goal**: Users can draw routes on a map (road-snap or free-draw), save them, and use them during runs.

#### Tests FIRST

**File: `Tests/MileOneTests/Services/RouteServiceTests.swift`**

```swift
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
```

**File: `Tests/MileOneTests/ViewModels/RoutePlannerViewModelTests.swift`**

```swift
import Testing
import CoreLocation
@testable import MileOne

@MainActor
struct RoutePlannerViewModelTests {
    
    @Test func addWaypointUpdatesViewModel() {
        let vm = RoutePlannerViewModel(routeService: RouteService(directionsProvider: MockDirectionsProvider()))
        
        vm.addWaypoint(CLLocationCoordinate2D(latitude: 35.78, longitude: -78.64))
        vm.addWaypoint(CLLocationCoordinate2D(latitude: 35.79, longitude: -78.64))
        
        #expect(vm.waypoints.count == 2)
        #expect(vm.canCalculateRoute == true, "Need ≥2 waypoints to calculate")
    }
    
    @Test func removeLastWaypointUpdatesState() {
        let vm = RoutePlannerViewModel(routeService: RouteService(directionsProvider: MockDirectionsProvider()))
        
        vm.addWaypoint(CLLocationCoordinate2D(latitude: 35.78, longitude: -78.64))
        vm.addWaypoint(CLLocationCoordinate2D(latitude: 35.79, longitude: -78.64))
        vm.addWaypoint(CLLocationCoordinate2D(latitude: 35.80, longitude: -78.64))
        vm.removeLastWaypoint()
        
        #expect(vm.waypoints.count == 2)
    }
    
    @Test func clearAllResetsState() {
        let vm = RoutePlannerViewModel(routeService: RouteService(directionsProvider: MockDirectionsProvider()))
        
        vm.addWaypoint(CLLocationCoordinate2D(latitude: 35.78, longitude: -78.64))
        vm.addWaypoint(CLLocationCoordinate2D(latitude: 35.79, longitude: -78.64))
        vm.clearAll()
        
        #expect(vm.waypoints.isEmpty)
        #expect(vm.canCalculateRoute == false)
        #expect(vm.totalDistance == 0)
    }
    
    @Test func distanceUpdatesOnRouteCalculation() async {
        let mock = MockDirectionsProvider()
        mock.mockDistance = 1500 // 1.5 km
        let vm = RoutePlannerViewModel(routeService: RouteService(directionsProvider: mock))
        
        vm.addWaypoint(CLLocationCoordinate2D(latitude: 35.78, longitude: -78.64))
        vm.addWaypoint(CLLocationCoordinate2D(latitude: 35.79, longitude: -78.64))
        
        await vm.calculateRoute()
        
        #expect(vm.totalDistance > 0, "Distance should update after route calculation")
    }
    
    @Test func douglasPeuckerSimplification() {
        // A straight line should simplify to just 2 endpoints
        let points = (0..<100).map { i in
            CLLocationCoordinate2D(
                latitude: 35.78 + Double(i) * 0.0001,
                longitude: -78.64
            )
        }
        
        let simplified = RoutePlannerViewModel.simplifyPath(points, epsilon: 0.00005)
        #expect(simplified.count == 2, "Straight line should simplify to 2 endpoints")
        #expect(simplified.first?.latitude == points.first?.latitude)
        #expect(simplified.last?.latitude == points.last?.latitude)
    }
    
    @Test func douglasPeuckerPreservesSharpTurns() {
        // L-shaped path should preserve the corner point
        let points = [
            CLLocationCoordinate2D(latitude: 35.78, longitude: -78.64),
            CLLocationCoordinate2D(latitude: 35.79, longitude: -78.64),  // straight
            CLLocationCoordinate2D(latitude: 35.80, longitude: -78.64),  // corner
            CLLocationCoordinate2D(latitude: 35.80, longitude: -78.63),  // turn right
            CLLocationCoordinate2D(latitude: 35.80, longitude: -78.62),  // straight
        ]
        
        let simplified = RoutePlannerViewModel.simplifyPath(points, epsilon: 0.00005)
        #expect(simplified.count >= 3, "L-shape must preserve corner point")
    }
    
    @Test func waypointEncodingAndDecoding() throws {
        let waypoints = [
            [35.78, -78.64],
            [35.79, -78.65],
        ]
        let data = try JSONEncoder().encode(waypoints)
        let decoded = try JSONDecoder().decode([[Double]].self, from: data)
        
        #expect(decoded.count == 2)
        #expect(decoded[0][0] == 35.78)
    }
}
```

#### Implementation

1. Build `RoutePlannerView`:
   - `Map` inside `MapReader` with tap gesture for waypoints (road snap mode)
   - Free draw mode with transparent overlay view for drag gesture (separate from map pan/zoom)
   - Toggle button between modes (clearly labeled)
   - Live distance counter (sum of segments)
   - Estimated time range based on current week
   - Undo last point / Clear all controls
   - Save button → name input → save to DataStore
   - Handle `nil` from `proxy.convert()` when tap is outside map bounds

2. Implement `RouteService` with `DirectionsProviding` protocol for testability:
   ```swift
   protocol DirectionsProviding {
       func calculate(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async throws -> MKRoute
   }
   
   struct MKDirectionsProvider: DirectionsProviding { /* real implementation */ }
   struct MockDirectionsProvider: DirectionsProviding { /* returns mock routes */ }
   ```
   - Cache: dictionary keyed by rounded coordinate pair (6 decimal places, avoids floating-point key issues)
   - Rate limit: minimum 2 seconds between requests
   - Backoff: exponential on `MKError.serverFailure` with max 3 retries
   - Cache eviction: LRU with max 50 entries

3. Implement Douglas-Peucker simplification:
   ```swift
   static func simplifyPath(_ points: [CLLocationCoordinate2D],
                            epsilon: Double) -> [CLLocationCoordinate2D] {
       guard points.count > 2 else { return points }
       
       // Find the point with maximum distance from the line (first, last)
       var maxDistance = 0.0
       var maxIndex = 0
       let start = points.first!
       let end = points.last!
       
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
   ```

4. Build `RouteListView`:
   - List of saved routes with name, distance, date
   - Swipe to delete
   - Tap to view detail → option to start run with route

---
