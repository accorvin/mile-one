#if canImport(HealthKit)
import Testing
import HealthKit
@testable import MileOne

// MARK: - HealthKitServiceTests
// These tests verify the permission surface and mock behavior.
// They do NOT touch a real HKHealthStore (which requires a device/simulator).

struct HealthKitServiceTests {

    // MARK: - Permission Type Coverage

    @Test("Write permission types include required workout types")
    func writePermissionsIncludeRequiredTypes() {
        let writeTypes = HealthKitService.shareTypes
        #expect(writeTypes.contains(HKWorkoutType.workoutType()),
                "Must request write access to HKWorkoutType")
        #expect(writeTypes.contains(HKQuantityType(.activeEnergyBurned)),
                "Must request write access to activeEnergyBurned")
        #expect(writeTypes.contains(HKQuantityType(.distanceWalkingRunning)),
                "Must request write access to distanceWalkingRunning")
        #expect(writeTypes.count == 3,
                "Exactly 3 write types expected")
    }

    @Test("Read permission types include all required types")
    func readPermissionsIncludeRequiredTypes() {
        let readTypes = HealthKitService.readTypes
        #expect(readTypes.contains(HKWorkoutType.workoutType()))
        #expect(readTypes.contains(HKQuantityType(.activeEnergyBurned)))
        #expect(readTypes.contains(HKQuantityType(.distanceWalkingRunning)))
        #expect(readTypes.contains(HKQuantityType(.heartRate)))
        #expect(readTypes.contains(HKQuantityType(.height)))
        #expect(readTypes.contains(HKQuantityType(.bodyMass)))
        #expect(readTypes.contains(HKCharacteristicType(.dateOfBirth)))
        #expect(readTypes.contains(HKCharacteristicType(.biologicalSex)))
        #expect(readTypes.count == 8,
                "Exactly 8 read types expected")
    }

    // MARK: - Authorization Mock Behavior

    @Test("Authorization granted returns true")
    func authorizationGrantedReturnsTrue() async throws {
        let mock = MockHealthStore()
        mock.authorizationGranted = true

        let result = try await mock.requestAuthorization(toShare: [], read: [])

        #expect(result == true)
        #expect(mock.authorizationRequested == true)
    }

    @Test("Authorization denied returns false without hanging")
    func authorizationDeniedReturnsFalse() async throws {
        let mock = MockHealthStore()
        mock.authorizationGranted = false

        let result = try await mock.requestAuthorization(toShare: [], read: [])

        #expect(result == false, "Denied authorization must return false, never hang")
        #expect(mock.authorizationRequested == true)
    }

    // MARK: - Heart Rate Query

    @Test("Heart rate query returns configured samples")
    func heartRateQueryReturnsConfiguredSamples() async throws {
        let mock = MockHealthStore()

        // Empty by default
        let emptySamples = try await mock.queryHeartRateSamples(
            start: Date().addingTimeInterval(-1800),
            end: Date()
        )
        #expect(emptySamples.count == 0,
                "Mock should return empty samples when none configured")
    }

    @Test("Heart rate query returns populated samples when configured")
    func heartRateQueryReturnsMockSamples() async throws {
        let mock = MockHealthStore()

        // Build a fake heart rate sample
        let hrType = HKQuantityType(.heartRate)
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        let quantity = HKQuantity(unit: bpmUnit, doubleValue: 145.0)
        let sample = HKQuantitySample(
            type: hrType,
            quantity: quantity,
            start: Date().addingTimeInterval(-60),
            end: Date()
        )
        mock.mockHeartRateSamples = [sample]

        let samples = try await mock.queryHeartRateSamples(
            start: Date().addingTimeInterval(-3600),
            end: Date()
        )
        #expect(samples.count == 1)
        #expect(samples[0].quantity.doubleValue(for: bpmUnit) == 145.0)
    }

    // MARK: - Route Data

    @Test("insertRouteData tracks batches")
    func insertRouteDataTracksBatches() async throws {
        let mock = MockHealthStore()
        let loc = CLLocation(latitude: 35.78, longitude: -78.64)

        try await mock.insertRouteData([loc])
        try await mock.insertRouteData([loc, loc])

        #expect(mock.insertedRouteLocations.count == 2)
        #expect(mock.insertedRouteLocations[0].count == 1)
        #expect(mock.insertedRouteLocations[1].count == 2)
    }

    @Test("insertRouteData throws when authorization denied")
    func insertRouteDataThrowsWhenDenied() async throws {
        let mock = MockHealthStore()
        mock.authorizationGranted = false
        let loc = CLLocation(latitude: 35.78, longitude: -78.64)

        await #expect(throws: HealthKitError.authorizationDenied) {
            try await mock.insertRouteData([loc])
        }
    }

    @Test("finishRoute sets routeFinalized")
    func finishRouteSetsFlag() async throws {
        let mock = MockHealthStore()
        let workout = HKWorkout(activityType: .running, start: Date().addingTimeInterval(-600), end: Date())

        try await mock.finishRoute(with: workout)

        #expect(mock.routeFinalized == true)
    }

    @Test("finishRoute throws when authorization denied")
    func finishRouteThrowsWhenDenied() async throws {
        let mock = MockHealthStore()
        mock.authorizationGranted = false
        let workout = HKWorkout(activityType: .running, start: Date().addingTimeInterval(-600), end: Date())

        await #expect(throws: HealthKitError.authorizationDenied) {
            try await mock.finishRoute(with: workout)
        }
    }

    @Test("saveWorkout tracks workout record")
    func saveWorkoutTracksRecord() async throws {
        let mock = MockHealthStore()
        let start = Date().addingTimeInterval(-1200)
        let end = Date()

        let workout = try await mock.saveWorkout(
            activityType: .running,
            start: start,
            end: end,
            totalDistance: HKQuantity(unit: .meter(), doubleValue: 3000),
            totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: 250)
        )

        #expect(mock.savedWorkouts.count == 1)
        #expect(mock.savedWorkouts[0].activityType == .running)
        #expect(mock.savedWorkouts[0].distanceMeters == 3000)
        #expect(mock.savedWorkouts[0].caloriesKcal == 250)
        #expect(workout.workoutActivityType == .running)
    }

    @Test("saveWorkout throws when authorization denied")
    func saveWorkoutThrowsWhenDenied() async throws {
        let mock = MockHealthStore()
        mock.authorizationGranted = false

        await #expect(throws: HealthKitError.authorizationDenied) {
            try await mock.saveWorkout(
                activityType: .running,
                start: Date().addingTimeInterval(-600),
                end: Date(),
                totalDistance: HKQuantity(unit: .meter(), doubleValue: 1000),
                totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: 100)
            )
        }
    }
}

// MARK: - CLLocation convenience

import CoreLocation
#endif
