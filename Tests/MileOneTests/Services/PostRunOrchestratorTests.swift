import Testing
import CoreLocation
import SwiftData
@testable import MileOne

#if canImport(HealthKit)
import HealthKit
#endif

// MARK: - PostRunOrchestratorTests

@MainActor
struct PostRunOrchestratorTests {

    // MARK: - Helpers

    private func makeTestContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: UserProfile.self, CompletedRun.self, GPSPoint.self, SavedRoute.self,
            configurations: config
        )
    }

    private func makeOrchestrator(
        dataStore: MileOne.DataStore,
        healthGranted: Bool = true
    ) -> PostRunOrchestrator {
#if canImport(HealthKit)
        let mock = MockHealthStore()
        mock.authorizationGranted = healthGranted
        return PostRunOrchestrator(dataStore: dataStore, healthStore: mock)
#else
        return PostRunOrchestrator(dataStore: dataStore)
#endif
    }

    /// Returns the MockHealthStore from the orchestrator (HealthKit builds only).
#if canImport(HealthKit)
    private func healthStore(from orchestrator: PostRunOrchestrator) -> MockHealthStore {
        orchestrator.healthStore as! MockHealthStore
    }
#endif

    private func seedProfile(in dataStore: MileOne.DataStore) async throws {
        try await dataStore.saveUserProfile(
            heightCm: 175, weightKg: 70, birthYear: 1990,
            biologicalSex: .male, currentWeek: 3,
            completedSessionsThisWeek: 1, hasCompletedOnboarding: true,
            hasGraduated: false, startingWeek: 1, usesMetric: true,
            runDays: [2, 4, 6], reminderHour: 7, reminderMinute: 0,
            remindersEnabled: true
        )
    }

    private func makeLocations(count: Int, startDate: Date) -> [CLLocation] {
        (0..<count).map { i in
            CLLocation(
                coordinate: CLLocationCoordinate2D(
                    latitude: 35.78 + Double(i) * 0.001,
                    longitude: -78.64
                ),
                altitude: 100,
                horizontalAccuracy: 10,
                verticalAccuracy: 10,
                timestamp: startDate.addingTimeInterval(Double(i) * 10)
            )
        }
    }

    private let sampleIntervals: [Interval] = [
        Interval(type: .warmUp, durationSeconds: 300),
        Interval(type: .run, durationSeconds: 600),
        Interval(type: .coolDown, durationSeconds: 300),
    ]

    // MARK: - Tests

    @Test("Full save pipeline persists run, GPS, and HealthKit data")
    func fullSavePipeline() async throws {
        let container = try makeTestContainer()
        let dataStore = MileOne.DataStore(modelContainer: container)
        try await seedProfile(in: dataStore)

        let orchestrator = makeOrchestrator(dataStore: dataStore, healthGranted: true)

        let runStart = Date().addingTimeInterval(-1200)
        let locations = makeLocations(count: 10, startDate: runStart)

        let result = try await orchestrator.saveRun(
            weekNumber: 3,
            sessionNumber: 2,
            runStart: runStart,
            locations: locations,
            totalElapsed: 1200,
            totalDistance: 2500,
            intervals: sampleIntervals
        )

        // SwiftData: run saved
        let runs = try await dataStore.fetchCompletedRuns(weekNumber: 3, limit: nil)
        #expect(runs.count == 1, "CompletedRun must be saved to SwiftData")
        #expect(runs[0].distanceMeters == 2500)
        #expect(result.swiftDataSaved == true)

        // SwiftData: GPS points saved
        let gpsData = try await dataStore.fetchGPSPoints(forRunId: result.runId)
        #expect(gpsData.count == 10, "All GPS points must be persisted")

        // SwiftData: sessions incremented
        let profile = try await dataStore.fetchUserProfile()
        #expect(profile?.completedSessionsThisWeek == 2,
                "completedSessionsThisWeek must increment from 1 to 2")

#if canImport(HealthKit)
        let hk = healthStore(from: orchestrator)
        // HealthKit: workout saved
        #expect(hk.savedWorkouts.count == 1, "HKWorkout must be saved")
        #expect(hk.savedWorkouts[0].activityType == .running)
        // HealthKit: route data inserted
        #expect(hk.insertedRouteLocations.isEmpty == false, "Route data must be inserted")
        // HealthKit: route finalized
        #expect(hk.routeFinalized == true, "Route must be finalized")
        #expect(result.healthKitSaved == true)
#endif
    }

    @Test("HealthKit denied — run still saved to SwiftData (graceful degradation)")
    func healthKitDeniedStillSavesToSwiftData() async throws {
        let container = try makeTestContainer()
        let dataStore = MileOne.DataStore(modelContainer: container)
        try await seedProfile(in: dataStore)

        let orchestrator = makeOrchestrator(dataStore: dataStore, healthGranted: false)
        let runStart = Date().addingTimeInterval(-1800)
        let locations = makeLocations(count: 5, startDate: runStart)

        let result = try await orchestrator.saveRun(
            weekNumber: 1,
            sessionNumber: 1,
            runStart: runStart,
            locations: locations,
            totalElapsed: 1800,
            totalDistance: 3000,
            intervals: [Interval(type: .run, durationSeconds: 1800)]
        )

        // SwiftData must succeed regardless of HealthKit
        let runs = try await dataStore.fetchCompletedRuns(weekNumber: 1, limit: nil)
        #expect(runs.count == 1, "Run must be saved to SwiftData even when HealthKit is denied")
        #expect(result.swiftDataSaved == true)

#if canImport(HealthKit)
        #expect(result.healthKitSaved == false, "Result should indicate HealthKit was skipped")
        #expect(result.healthKitError != nil, "Error should be captured, not swallowed silently")

        let hk = healthStore(from: orchestrator)
        #expect(hk.savedWorkouts.isEmpty, "No workout should be saved when denied")
        #expect(hk.routeFinalized == false)
#endif
    }

    @Test("Route GPS data is batched into chunks of 200")
    func routeDataBatchedCorrectly() async throws {
#if canImport(HealthKit)
        let container = try makeTestContainer()
        let dataStore = MileOne.DataStore(modelContainer: container)
        try await seedProfile(in: dataStore)

        let orchestrator = makeOrchestrator(dataStore: dataStore, healthGranted: true)
        let runStart = Date().addingTimeInterval(-500)
        // 500 locations → ceil(500/200) = 3 batches
        let locations = makeLocations(count: 500, startDate: runStart)

        _ = try await orchestrator.saveRun(
            weekNumber: 1,
            sessionNumber: 1,
            runStart: runStart,
            locations: locations,
            totalElapsed: 500,
            totalDistance: 5000,
            intervals: [Interval(type: .run, durationSeconds: 500)]
        )

        let hk = healthStore(from: orchestrator)
        let totalInserted = hk.insertedRouteLocations.reduce(0) { $0 + $1.count }
        #expect(totalInserted == 500, "All 500 GPS points must be inserted")
        #expect(hk.insertedRouteLocations.count == 3,
                "500 points / 200 per batch = exactly 3 batches")
        #expect(hk.insertedRouteLocations[0].count == 200)
        #expect(hk.insertedRouteLocations[1].count == 200)
        #expect(hk.insertedRouteLocations[2].count == 100)
#endif
    }

    @Test("EndRunConfirmation model supports toggle and retains stats")
    func endRunConfirmationModel() {
        var state = EndRunConfirmation(
            showingConfirmation: false,
            elapsedTime: 1200,
            distance: 2500
        )

        #expect(state.showingConfirmation == false)
        #expect(state.elapsedTime == 1200)
        #expect(state.distance == 2500)

        // User taps End Run → show confirmation
        state.showingConfirmation = true
        #expect(state.showingConfirmation == true)

        // Stats must remain accessible so UI can display them in the confirmation
        #expect(state.elapsedTime > 0)
        #expect(state.distance > 0)
    }

    @Test("Calories are calculated from weight and intervals")
    func caloriesCalculatedCorrectly() async throws {
        let container = try makeTestContainer()
        let dataStore = MileOne.DataStore(modelContainer: container)

        // Seed a profile with known weight
        try await dataStore.saveUserProfile(
            heightCm: 175, weightKg: 80, birthYear: 1990,
            biologicalSex: .male, currentWeek: 1,
            completedSessionsThisWeek: 0, hasCompletedOnboarding: true,
            hasGraduated: false, startingWeek: 1, usesMetric: true,
            runDays: [2, 4, 6], reminderHour: 7, reminderMinute: 0,
            remindersEnabled: true
        )

        let orchestrator = makeOrchestrator(dataStore: dataStore)
        let runStart = Date().addingTimeInterval(-3600)
        let intervals = [
            Interval(type: .warmUp, durationSeconds: 300),
            Interval(type: .run, durationSeconds: 2700),
            Interval(type: .coolDown, durationSeconds: 600),
        ]
        let result = try await orchestrator.saveRun(
            weekNumber: 1,
            sessionNumber: 1,
            runStart: runStart,
            locations: makeLocations(count: 3, startDate: runStart),
            totalElapsed: 3600,
            totalDistance: 8000,
            intervals: intervals
        )

        let runs = try await dataStore.fetchCompletedRuns(weekNumber: 1, limit: nil)
        #expect(runs.count == 1)
        // CalorieCalculator(weightKg: 80, intervals: ..., duration: 3600) > 0
        #expect(runs[0].calories > 0, "Calories must be positive for a real run")
        let _ = result // suppress unused-variable warning
    }

    @Test("SaveRunResult exposes correct fields")
    func saveRunResultFields() {
        let id = UUID()
        let result = SaveRunResult(
            runId: id,
            swiftDataSaved: true,
            healthKitSaved: false,
            healthKitError: HealthKitError.authorizationDenied
        )
        #expect(result.runId == id)
        #expect(result.swiftDataSaved == true)
        #expect(result.healthKitSaved == false)
        #expect(result.healthKitError != nil)
    }

    @Test("saveCompletedRun throwing causes failure result and skips GPS and HealthKit")
    func saveCompletedRunThrowingCausesFailure() async throws {
        let mockStore = MockDataStore()
        await mockStore.setMockProfile(UserProfileSnapshot(
            heightCm: 175, weightKg: 70, birthYear: 1990,
            biologicalSex: .male, currentWeek: 3,
            completedSessionsThisWeek: 1, hasCompletedOnboarding: true,
            hasGraduated: false, startingWeek: 1, usesMetric: true,
            runDays: [2, 4, 6], reminderHour: 7, reminderMinute: 0,
            remindersEnabled: true
        ))
        // Make saveCompletedRun throw
        await mockStore.setShouldThrowOnSaveRun(true)

#if canImport(HealthKit)
        let mock = MockHealthStore()
        mock.authorizationGranted = true
        let orchestrator = PostRunOrchestrator(dataStore: mockStore, healthStore: mock)
#else
        let orchestrator = PostRunOrchestrator(dataStore: mockStore)
#endif

        let runStart = Date().addingTimeInterval(-600)
        let locations = makeLocations(count: 3, startDate: runStart)

        do {
            _ = try await orchestrator.saveRun(
                weekNumber: 3,
                sessionNumber: 2,
                runStart: runStart,
                locations: locations,
                totalElapsed: 600,
                totalDistance: 1500,
                intervals: sampleIntervals
            )
            Issue.record("saveRun should have thrown when saveCompletedRun throws")
        } catch {
            // Error is surfaced (not swallowed) — that's the expected behaviour
            let gpsCount = await mockStore.mockGPSPoints.count
            #expect(gpsCount == 0, "GPS points must not be saved when run save fails")

#if canImport(HealthKit)
            let hk = healthStore(from: orchestrator)
            #expect(hk.savedWorkouts.isEmpty, "HealthKit save must be skipped when run save fails")
#endif
        }
    }

    @Test("GPS points with zero or negative speed are clamped to zero")
    func negativeSpeedClampedToZero() async throws {
        let container = try makeTestContainer()
        let dataStore = MileOne.DataStore(modelContainer: container)
        try await seedProfile(in: dataStore)

        let orchestrator = makeOrchestrator(dataStore: dataStore)
        let runStart = Date().addingTimeInterval(-600)

        // CLLocation with speed = -1 (unknown)
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 35.78, longitude: -78.64),
            altitude: 100,
            horizontalAccuracy: 10,
            verticalAccuracy: 10,
            course: 0,
            speed: -1,  // negative = unknown in CoreLocation
            timestamp: runStart
        )

        let result = try await orchestrator.saveRun(
            weekNumber: 1,
            sessionNumber: 1,
            runStart: runStart,
            locations: [location],
            totalElapsed: 600,
            totalDistance: 1000,
            intervals: [Interval(type: .run, durationSeconds: 600)]
        )

        let gpsPoints = try await dataStore.fetchGPSPoints(forRunId: result.runId)
        #expect(gpsPoints.count == 1)
        #expect(gpsPoints[0].speed >= 0, "Negative CLLocation speed must be clamped to 0")
    }
}
