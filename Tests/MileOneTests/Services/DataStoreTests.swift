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
