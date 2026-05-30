import Foundation
import Testing
import SwiftData
@testable import MileOne

struct DataStoreTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: UserProfile.self, CompletedRun.self, GPSPoint.self, SavedRoute.self,
            configurations: config
        )
    }

    @Test func saveAndFetchUserProfile() async throws {
        let container = try makeContainer()
        let store = DataStore(modelContainer: container)

        try await store.saveUserProfile(
            heightCm: 180, weightKg: 85, birthYear: 1990,
            biologicalSex: .male, currentWeek: 1,
            completedSessionsThisWeek: 0, hasCompletedOnboarding: false,
            hasGraduated: false, startingWeek: 1, usesMetric: false,
            runDays: [2, 4, 6], reminderHour: 7, reminderMinute: 0,
            remindersEnabled: true
        )
        let fetched = try await store.fetchUserProfile()

        #expect(fetched != nil)
        #expect(fetched?.heightCm == 180)
        #expect(fetched?.weightKg == 85)
        #expect(fetched?.biologicalSex == .male)
    }

    @Test func saveProfileTwiceDoesNotDuplicate() async throws {
        // Verifies the fetch-then-upsert behaviour — NOT insert-always.
        let container = try makeContainer()
        let store = DataStore(modelContainer: container)

        try await store.saveUserProfile(
            heightCm: 180, weightKg: 70, birthYear: 1990,
            biologicalSex: .male, currentWeek: 1,
            completedSessionsThisWeek: 0, hasCompletedOnboarding: false,
            hasGraduated: false, startingWeek: 1, usesMetric: false,
            runDays: [2, 4, 6], reminderHour: 7, reminderMinute: 0,
            remindersEnabled: true
        )

        // Simulate a settings update
        try await store.saveUserProfile(
            heightCm: 180, weightKg: 90, birthYear: 1990,
            biologicalSex: .male, currentWeek: 1,
            completedSessionsThisWeek: 0, hasCompletedOnboarding: false,
            hasGraduated: false, startingWeek: 1, usesMetric: false,
            runDays: [2, 4, 6], reminderHour: 7, reminderMinute: 0,
            remindersEnabled: true
        )

        // Should still have exactly one profile with the updated weight
        let profile = try await store.fetchUserProfile()
        #expect(profile != nil, "saveUserProfile must upsert, not insert a duplicate")
        #expect(profile?.weightKg == 90, "Second save should update weightKg to 90")
    }

    @Test func saveAndFetchCompletedRun() async throws {
        let container = try makeContainer()
        let store = DataStore(modelContainer: container)

        _ = try await store.saveCompletedRun(
            weekNumber: 1, sessionNumber: 1, date: Date(),
            distanceMeters: 2500, durationSeconds: 1800,
            calories: 200, averagePaceSecondsPerKm: nil,
            averageHeartRate: nil, effortRating: nil, isFreeRun: false
        )
        let runs = try await store.fetchCompletedRuns(weekNumber: 1, limit: nil)

        #expect(runs.count == 1)
        #expect(runs[0].distanceMeters == 2500)
        #expect(runs[0].weekNumber == 1)
    }

    @Test func gpsPointsAreSeparateFromRun() async throws {
        let container = try makeContainer()
        let store = DataStore(modelContainer: container)

        let runId = try await store.saveCompletedRun(
            weekNumber: 1, sessionNumber: 1, date: Date(),
            distanceMeters: 0, durationSeconds: 0,
            calories: 0, averagePaceSecondsPerKm: nil,
            averageHeartRate: nil, effortRating: nil, isFreeRun: false
        )

        let pointData = (0..<100).map { i in
            GPSPointData(
                latitude:          35.7 + Double(i) * 0.0001,
                longitude:        -78.6 + Double(i) * 0.0001,
                altitude:          100,
                horizontalAccuracy: 10,
                timestamp:         Date().addingTimeInterval(Double(i)),
                speed:             2.5
            )
        }

        try await store.saveGPSPoints(pointData, forRunId: runId)
        let fetched = try await store.fetchGPSPoints(forRunId: runId)

        #expect(fetched.count == 100)
        #expect(fetched[0].latitude > 35.6)
    }

    @Test func fetchCompletedRunsFiltersByWeek() async throws {
        let container = try makeContainer()
        let store = DataStore(modelContainer: container)

        _ = try await store.saveCompletedRun(
            weekNumber: 1, sessionNumber: 1, date: Date(),
            distanceMeters: 0, durationSeconds: 0, calories: 0,
            averagePaceSecondsPerKm: nil, averageHeartRate: nil,
            effortRating: nil, isFreeRun: false
        )
        _ = try await store.saveCompletedRun(
            weekNumber: 2, sessionNumber: 1, date: Date(),
            distanceMeters: 0, durationSeconds: 0, calories: 0,
            averagePaceSecondsPerKm: nil, averageHeartRate: nil,
            effortRating: nil, isFreeRun: false
        )

        let week1Runs = try await store.fetchCompletedRuns(weekNumber: 1, limit: nil)
        #expect(week1Runs.count == 1)
        #expect(week1Runs[0].weekNumber == 1)

        let allRuns = try await store.fetchCompletedRuns(weekNumber: nil, limit: nil)
        #expect(allRuns.count == 2)
    }

    @Test func savedRoutesCRUD() async throws {
        let container = try makeContainer()
        let store = DataStore(modelContainer: container)

        let waypoints = try JSONEncoder().encode([[35.7, -78.6], [35.71, -78.61]])

        let routeId = try await store.saveSavedRoute(
            name: "Morning Loop",
            drawMode: .roadSnap,
            waypointsData: waypoints,
            distanceMeters: 3200
        )

        var routes = try await store.fetchSavedRoutes()
        #expect(routes.count == 1)
        #expect(routes[0].name == "Morning Loop")
        #expect(routes[0].drawMode == .roadSnap)

        try await store.deleteSavedRoute(id: routeId)
        routes = try await store.fetchSavedRoutes()
        #expect(routes.count == 0)
    }

    @Test func updateEffortRatingUpdatesExistingRun() async throws {
        let container = try makeContainer()
        let store = DataStore(modelContainer: container)

        let runId = try await store.saveCompletedRun(
            weekNumber: 1, sessionNumber: 1, date: Date(),
            distanceMeters: 1000, durationSeconds: 600, calories: 80,
            averagePaceSecondsPerKm: nil, averageHeartRate: nil,
            effortRating: nil, isFreeRun: false
        )

        try await store.updateEffortRating(runId: runId, rating: .tooHard)

        let runs = try await store.fetchCompletedRuns(weekNumber: 1, limit: nil)
        #expect(runs.count == 1)
        #expect(runs[0].effortRating == .tooHard,
                "updateEffortRating must persist the new rating")
    }

    @Test func updateEffortRatingOnNonExistentRunThrows() async throws {
        let container = try makeContainer()
        let store = DataStore(modelContainer: container)
        let fakeId = UUID()

        do {
            try await store.updateEffortRating(runId: fakeId, rating: .justRight)
            Issue.record("Should have thrown DataStoreError.runNotFound")
        } catch {
            // Expected: runNotFound error
            #expect(error is MileOne.DataStoreError)
        }
    }

    @Test func saveGPSPointsForNonExistentRunThrows() async throws {
        let container = try makeContainer()
        let store = DataStore(modelContainer: container)
        let fakeId = UUID()

        let points = [GPSPointData(
            latitude: 35.78, longitude: -78.64,
            altitude: 100, horizontalAccuracy: 10,
            timestamp: Date(), speed: 2.5
        )]

        do {
            try await store.saveGPSPoints(points, forRunId: fakeId)
            Issue.record("Should have thrown DataStoreError.runNotFound")
        } catch {
            // Expected: runNotFound error
            #expect(error is MileOne.DataStoreError)
        }
    }

    @Test func incrementCompletedSessionsOnNonExistentProfileThrows() async throws {
        let container = try makeContainer()
        let store = DataStore(modelContainer: container)
        // No profile saved — should throw profileNotFound

        do {
            try await store.incrementCompletedSessions()
            Issue.record("Should have thrown DataStoreError.profileNotFound")
        } catch {
            // Expected: DataStoreError.profileNotFound
            #expect(error is MileOne.DataStoreError)
        }
    }

    @Test func fetchCompletedRunsWithLimit1ReturnsExactlyOneRun() async throws {
        let container = try makeContainer()
        let store = DataStore(modelContainer: container)

        // Save 3 runs
        for i in 1...3 {
            _ = try await store.saveCompletedRun(
                weekNumber: 1, sessionNumber: i,
                date: Date().addingTimeInterval(Double(i) * 60),
                distanceMeters: 1000, durationSeconds: 600, calories: 80,
                averagePaceSecondsPerKm: nil, averageHeartRate: nil,
                effortRating: nil, isFreeRun: false
            )
        }

        let runs = try await store.fetchCompletedRuns(weekNumber: nil, limit: 1)
        #expect(runs.count == 1, "fetchCompletedRuns(limit:1) must return exactly 1 run")
    }

    @Test func fetchCompletedRunsReturnsSortedNewestFirst() async throws {
        let container = try makeContainer()
        let store = DataStore(modelContainer: container)

        let now = Date()
        let olderDate = now.addingTimeInterval(-3600)  // 1 hour ago
        let newerDate = now.addingTimeInterval(-60)    // 1 minute ago

        _ = try await store.saveCompletedRun(
            weekNumber: 1, sessionNumber: 1, date: olderDate,
            distanceMeters: 1000, durationSeconds: 600, calories: 80,
            averagePaceSecondsPerKm: nil, averageHeartRate: nil,
            effortRating: nil, isFreeRun: false
        )
        _ = try await store.saveCompletedRun(
            weekNumber: 1, sessionNumber: 2, date: newerDate,
            distanceMeters: 2000, durationSeconds: 900, calories: 120,
            averagePaceSecondsPerKm: nil, averageHeartRate: nil,
            effortRating: nil, isFreeRun: false
        )

        let runs = try await store.fetchCompletedRuns(weekNumber: nil, limit: nil)
        #expect(runs.count == 2)
        #expect(runs[0].date >= runs[1].date,
                "fetchCompletedRuns must return newest run first")
    }

    @Test func fetchGPSPointsExcludesPointsFromOtherRun() async throws {
        let container = try makeContainer()
        let store = DataStore(modelContainer: container)

        let runAId = try await store.saveCompletedRun(
            weekNumber: 1, sessionNumber: 1, date: Date(),
            distanceMeters: 0, durationSeconds: 0, calories: 0,
            averagePaceSecondsPerKm: nil, averageHeartRate: nil,
            effortRating: nil, isFreeRun: false
        )
        let runBId = try await store.saveCompletedRun(
            weekNumber: 1, sessionNumber: 2, date: Date(),
            distanceMeters: 0, durationSeconds: 0, calories: 0,
            averagePaceSecondsPerKm: nil, averageHeartRate: nil,
            effortRating: nil, isFreeRun: false
        )

        let pointsA = [GPSPointData(
            latitude: 35.78, longitude: -78.64,
            altitude: 100, horizontalAccuracy: 10,
            timestamp: Date(), speed: 2.5
        )]
        let pointsB = [GPSPointData(
            latitude: 36.00, longitude: -79.00,
            altitude: 200, horizontalAccuracy: 10,
            timestamp: Date(), speed: 3.0
        ), GPSPointData(
            latitude: 36.01, longitude: -79.01,
            altitude: 200, horizontalAccuracy: 10,
            timestamp: Date().addingTimeInterval(10), speed: 3.0
        )]

        try await store.saveGPSPoints(pointsA, forRunId: runAId)
        try await store.saveGPSPoints(pointsB, forRunId: runBId)

        let fetchedA = try await store.fetchGPSPoints(forRunId: runAId)
        let fetchedB = try await store.fetchGPSPoints(forRunId: runBId)

        #expect(fetchedA.count == 1,
                "fetchGPSPoints for run A must return only run A's points")
        #expect(fetchedB.count == 2,
                "fetchGPSPoints for run B must return only run B's points")
        #expect(abs(fetchedA[0].latitude - 35.78) < 0.001,
                "Run A's GPS point must have the correct latitude")
    }

    @Test func fetchGPSPointsRoundTripsNegativeAndPolarCoordinates() async throws {
        let container = try makeContainer()
        let store = DataStore(modelContainer: container)

        let runId = try await store.saveCompletedRun(
            weekNumber: 1, sessionNumber: 1, date: Date(),
            distanceMeters: 0, durationSeconds: 0, calories: 0,
            averagePaceSecondsPerKm: nil, averageHeartRate: nil,
            effortRating: nil, isFreeRun: false
        )

        let points = [
            GPSPointData(latitude: -89.9999, longitude: -179.9999,
                         altitude: -100, horizontalAccuracy: 5,
                         timestamp: Date(), speed: 0.0),
            GPSPointData(latitude: 89.9999, longitude: 179.9999,
                         altitude: 8848, horizontalAccuracy: 5,
                         timestamp: Date().addingTimeInterval(1), speed: 0.0),
        ]
        try await store.saveGPSPoints(points, forRunId: runId)
        let fetched = try await store.fetchGPSPoints(forRunId: runId)

        #expect(fetched.count == 2)
        #expect(abs(fetched[0].latitude  - (-89.9999)) < 0.00001)
        #expect(abs(fetched[0].longitude - (-179.9999)) < 0.00001)
        #expect(abs(fetched[1].latitude  - 89.9999) < 0.00001)
        #expect(abs(fetched[1].longitude - 179.9999) < 0.00001)
    }

    @Test func fetchLastRunDate() async throws {
        let container = try makeContainer()
        let store = DataStore(modelContainer: container)

        let noDate = try await store.fetchLastRunDate()
        #expect(noDate == nil, "No runs → fetchLastRunDate should return nil")

        let now = Date()
        _ = try await store.saveCompletedRun(
            weekNumber: 1, sessionNumber: 1, date: now,
            distanceMeters: 0, durationSeconds: 0, calories: 0,
            averagePaceSecondsPerKm: nil, averageHeartRate: nil,
            effortRating: nil, isFreeRun: false
        )

        let lastDate = try await store.fetchLastRunDate()
        #expect(lastDate != nil, "After saving a run, fetchLastRunDate should return a date")
    }
}
