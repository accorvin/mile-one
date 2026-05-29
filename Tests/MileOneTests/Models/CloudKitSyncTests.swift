import Testing
import SwiftData
@testable import MileOne

/// Tests that all @Model types can round-trip through the persistent store,
/// mirroring the serialization CloudKit performs.
struct CloudKitSyncTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: UserProfile.self, CompletedRun.self, GPSPoint.self, SavedRoute.self,
            configurations: config
        )
    }

    @Test func userProfileRoundTrips() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let profile = UserProfile()
        profile.heightCm = 175
        profile.weightKg = 80
        profile.biologicalSex = "male"
        profile.runDays = [2, 4, 6]
        profile.currentWeek = 3
        profile.completedSessionsThisWeek = 2
        profile.hasCompletedOnboarding = true

        context.insert(profile)
        try context.save()

        let descriptor = FetchDescriptor<UserProfile>()
        let fetched = try context.fetch(descriptor)

        #expect(fetched.count == 1)
        let p = try #require(fetched.first)
        #expect(p.heightCm == 175)
        #expect(p.weightKg == 80)
        #expect(p.biologicalSex == "male")
        #expect(p.runDays.sorted() == [2, 4, 6], "Array ordering must survive round-trip (sort on read)")
        #expect(p.currentWeek == 3)
        #expect(p.completedSessionsThisWeek == 2)
        #expect(p.hasCompletedOnboarding == true)
    }

    @Test func completedRunRoundTrips() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let run = CompletedRun(weekNumber: 5, sessionNumber: 2)
        run.distanceMeters = 3200
        run.durationSeconds = 2100
        run.calories = 280
        run.averagePaceSecondsPerKm = 656
        run.effortRating = "justRight"
        // gpsPoints must stay nil (not []) — CloudKit treats them differently
        run.gpsPoints = nil

        context.insert(run)
        try context.save()

        let descriptor = FetchDescriptor<CompletedRun>()
        let fetched = try context.fetch(descriptor)

        #expect(fetched.count == 1)
        let r = try #require(fetched.first)
        #expect(r.weekNumber == 5)
        #expect(r.distanceMeters == 3200)
        #expect(r.effortRating == "justRight")
        #expect(r.gpsPoints == nil, "nil gpsPoints must stay nil, not become []")
    }

    @Test func savedRouteRoundTrips() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let waypoints = try JSONEncoder().encode([[35.7, -78.6], [35.71, -78.61]])
        let route = SavedRoute(name: "Test Route", drawMode: "roadSnap", waypoints: waypoints)
        route.distanceMeters = 3000

        context.insert(route)
        try context.save()

        let descriptor = FetchDescriptor<SavedRoute>()
        let fetched = try context.fetch(descriptor)

        #expect(fetched.count == 1)
        let r = try #require(fetched.first)
        #expect(r.name == "Test Route")
        #expect(r.drawMode == "roadSnap")
        #expect(r.distanceMeters == 3000)

        let decoded = try JSONDecoder().decode([[Double]].self, from: r.waypointsData)
        #expect(decoded.count == 2)
        #expect(decoded[0][0] == 35.7)
    }

    @Test func gpsPointRelationshipRoundTrips() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let run = CompletedRun(weekNumber: 1, sessionNumber: 1)
        context.insert(run)

        let point = GPSPoint(
            latitude: 35.78,
            longitude: -78.64,
            altitude: 100,
            horizontalAccuracy: 5,
            timestamp: Date(),
            speed: 2.5
        )
        point.run = run
        context.insert(point)
        try context.save()

        let descriptor = FetchDescriptor<GPSPoint>()
        let fetched = try context.fetch(descriptor)
        #expect(fetched.count == 1)
        let p = try #require(fetched.first)
        #expect(p.latitude == 35.78)
        #expect(p.run?.weekNumber == 1, "GPSPoint.run relationship must survive round-trip")
    }
}
