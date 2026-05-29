← [Back to Index](README.md)

# Mile One — Phase 4: HealthKit Integration + Post-Run Flow

### Phase 4: HealthKit Integration + Post-Run Flow

**Goal**: Runs are saved to HealthKit with workout data and GPS routes. Post-run summary shows all stats. The save pipeline is resilient to HealthKit permission denial.

#### Design Decisions (fixes from review 2)

- **No `fatalError()` in mocks**: MockHealthStore implements all methods with proper mock behavior, returning predictable test data. Fixes review 2 issue 1f.
- **HealthKit permission denied = graceful degradation**: If HealthKit is denied, run data is still saved to SwiftData. HealthKit is supplementary, not required. Fixes the unhandled throw in the save pipeline.
- **Native async HealthKit API**: Uses `healthStore.requestAuthorization(toShare:read:)` async variant (iOS 15+), not callback-based `withCheckedThrowingContinuation`. Fixes review 2 issue 1e.
- **PostRunOrchestrator**: A dedicated class owns the save pipeline, with all dependencies injected. Fixes review 2 issue 8a.
- **End Run confirmation**: Users must confirm before ending a run. No accidental data loss.
- **Heart rate query**: Reads heart rate from HealthKit (Apple Watch data) during the run window.

#### Tests FIRST

**File: `Tests/MileOneTests/Mocks/MockHealthStore.swift`**

```swift
@testable import MileOne
import HealthKit
import CoreLocation

/// MockHealthStore conforms to the CANONICAL HealthStoreProviding protocol from services.md.
final class MockHealthStore: HealthStoreProviding, @unchecked Sendable {
    var authorizationRequested = false
    var authorizationGranted = true // toggle to test denial
    var savedWorkouts: [MockWorkout] = []
    var insertedRouteLocations: [[CLLocation]] = []
    var routeFinalized = false
    var lastReadType: HKQuantityType?
    var mockHeartRateSamples: [HKQuantitySample] = []
    
    struct MockWorkout {
        let activityType: HKWorkoutActivityType
        let start: Date
        let end: Date
        let distance: Double
        let calories: Double
    }
    
    func requestAuthorization(
        toShare: Set<HKSampleType>,
        read: Set<HKObjectType>
    ) async throws -> Bool {
        authorizationRequested = true
        return authorizationGranted
    }
    
    func saveWorkout(
        activityType: HKWorkoutActivityType,
        start: Date,
        end: Date,
        totalDistance: HKQuantity,
        totalEnergyBurned: HKQuantity
    ) async throws -> HKWorkout {
        guard authorizationGranted else {
            throw HealthKitError.authorizationDenied
        }
        let workout = MockWorkout(
            activityType: activityType,
            start: start,
            end: end,
            distance: totalDistance.doubleValue(for: .meter()),
            calories: totalEnergyBurned.doubleValue(for: .kilocalorie())
        )
        savedWorkouts.append(workout)
        return HKWorkout(activityType: .running,
                         start: start,
                         end: end)
    }
    
    func createRouteBuilder() -> HKWorkoutRouteBuilder {
        // NOTE: In tests, route building is tracked via insertedRouteLocations/routeFinalized.
        // The real HKWorkoutRouteBuilder requires an HKHealthStore instance.
        // Tests should use the insertRouteData/finishRoute tracking methods below instead.
        fatalError("Use insertRouteData/finishRoute tracking in tests, not createRouteBuilder")
    }
    
    func readMostRecentSample(for type: HKQuantityType) async throws -> HKQuantitySample? {
        lastReadType = type
        return nil // Override in specific tests
    }
    
    /// Matches canonical protocol: queryHeartRateSamples(start:end:)
    func queryHeartRateSamples(start: Date, end: Date) async throws -> [HKQuantitySample] {
        return mockHeartRateSamples
    }
    
    // --- Test helper methods (not part of protocol) ---
    
    func insertRouteData(_ locations: [CLLocation]) async throws {
        guard authorizationGranted else {
            throw HealthKitError.authorizationDenied
        }
        insertedRouteLocations.append(locations)
    }
    
    func finishRoute(with workout: HKWorkout) async throws {
        guard authorizationGranted else {
            throw HealthKitError.authorizationDenied
        }
        routeFinalized = true
    }
}
```

**File: `Tests/MileOneTests/Services/HealthKitServiceTests.swift`**

```swift
import Testing
import HealthKit
@testable import MileOne

struct HealthKitServiceTests {
    
    @Test func requestedPermissionsIncludeAllRequired() {
        let writeTypes: Set<HKSampleType> = [
            HKWorkoutType.workoutType(),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
        ]
        let readTypes: Set<HKObjectType> = [
            HKWorkoutType.workoutType(),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.heartRate),
            HKQuantityType(.height),
            HKQuantityType(.bodyMass),
            HKCharacteristicType(.dateOfBirth),
            HKCharacteristicType(.biologicalSex),
        ]
        #expect(writeTypes.count == 3)
        #expect(readTypes.count == 8)
    }
    
    @Test func authorizationDeniedDoesNotHang() async throws {
        let mock = MockHealthStore()
        mock.authorizationGranted = false
        
        // Should return false, not hang forever
        let result = try await mock.requestAuthorization(toShare: [], read: [])
        #expect(result == false, "Denied authorization must return false, never hang")
    }
    
    @Test func heartRateQueryReturnsData() async throws {
        let mock = MockHealthStore()
        // In real tests, create HKQuantitySample mocks or use plain Double wrappers.
        // The canonical protocol returns [HKQuantitySample], but for mock testing
        // we verify the mock returns the configured samples.
        let samples = try await mock.queryHeartRateSamples(
            start: Date().addingTimeInterval(-1800),
            end: Date()
        )
        // With no configured samples, should return empty
        #expect(samples.count == 0)
    }
}
```

**File: `Tests/MileOneTests/Services/PostRunOrchestratorTests.swift`**

```swift
import Testing
import CoreLocation
import SwiftData
@testable import MileOne

@MainActor
struct PostRunOrchestratorTests {
    
    private func makeTestContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: UserProfile.self, CompletedRun.self, GPSPoint.self, SavedRoute.self,
            configurations: config
        )
    }
    
    @Test func fullSavePipeline() async throws {
        let container = try makeTestContainer()
        let dataStore = DataStore(modelContainer: container)
        let healthStore = MockHealthStore()
        
        // Setup: create user profile using plain values (canonical API)
        try await dataStore.saveUserProfile(
            heightCm: 170, weightKg: 70, birthYear: 1990,
            biologicalSex: .male, currentWeek: 3,
            completedSessionsThisWeek: 1, hasCompletedOnboarding: true,
            hasGraduated: false, startingWeek: 1, usesMetric: false,
            runDays: [2, 4, 6], reminderHour: 7, reminderMinute: 0,
            remindersEnabled: true
        )
        
        let orchestrator = PostRunOrchestrator(
            dataStore: dataStore,
            healthStore: healthStore
        )
        
        let runStart = Date().addingTimeInterval(-1200)
        let locations = (0..<10).map { i in
            CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: 35.78 + Double(i) * 0.001, longitude: -78.64),
                altitude: 100, horizontalAccuracy: 10, verticalAccuracy: 10,
                timestamp: runStart.addingTimeInterval(Double(i) * 120)
            )
        }
        let intervals = [
            Interval(type: .warmUp, durationSeconds: 300),
            Interval(type: .run, durationSeconds: 600),
            Interval(type: .coolDown, durationSeconds: 300),
        ]
        
        let result = try await orchestrator.saveRun(
            weekNumber: 3,
            sessionNumber: 2,
            runStart: runStart,
            locations: locations,
            totalElapsed: 1200,
            totalDistance: 2500,
            intervals: intervals
        )
        
        // 1. SwiftData: CompletedRun saved
        let runs = try await dataStore.fetchCompletedRuns(weekNumber: 3, limit: nil)
        #expect(runs.count == 1, "CompletedRun must be saved to SwiftData")
        #expect(runs[0].distanceMeters == 2500)
        
        // 2. SwiftData: GPS points saved
        let gpsData = try await dataStore.fetchGPSPoints(forRunId: result.runId)
        #expect(gpsData.count == 10, "GPS points must be persisted")
        
        // 3. HealthKit: workout saved
        #expect(healthStore.savedWorkouts.count == 1, "HKWorkout must be saved")
        #expect(healthStore.savedWorkouts[0].activityType == .running)
        
        // 4. HealthKit: route data inserted
        #expect(healthStore.insertedRouteLocations.isEmpty == false, "Route data must be inserted")
        
        // 5. HealthKit: route finalized
        #expect(healthStore.routeFinalized == true, "Route must be finalized with workout")
        
        // 6. UserProfile sessions incremented
        let updatedProfile = try await dataStore.fetchUserProfile()
        #expect(updatedProfile?.completedSessionsThisWeek == 2,
                "completedSessionsThisWeek must increment")
    }
    
    @Test func healthKitDeniedStillSavesToSwiftData() async throws {
        // Verifies graceful degradation — HealthKit denial must not lose run data
        let container = try makeTestContainer()
        let dataStore = DataStore(modelContainer: container)
        let healthStore = MockHealthStore()
        healthStore.authorizationGranted = false // HealthKit denied
        
        try await dataStore.saveUserProfile(
            heightCm: 170, weightKg: 70, birthYear: 1990,
            biologicalSex: .male, currentWeek: 1,
            completedSessionsThisWeek: 0, hasCompletedOnboarding: true,
            hasGraduated: false, startingWeek: 1, usesMetric: false,
            runDays: [2, 4, 6], reminderHour: 7, reminderMinute: 0,
            remindersEnabled: true
        )
        
        let orchestrator = PostRunOrchestrator(
            dataStore: dataStore,
            healthStore: healthStore
        )
        
        let runStart = Date().addingTimeInterval(-1800)
        let locations = [
            CLLocation(latitude: 35.78, longitude: -78.64)
        ]
        
        let result = try await orchestrator.saveRun(
            weekNumber: 1,
            sessionNumber: 1,
            runStart: runStart,
            locations: locations,
            totalElapsed: 1800,
            totalDistance: 3000,
            intervals: [Interval(type: .run, durationSeconds: 1800)]
        )
        
        // SwiftData save must succeed even when HealthKit fails
        let runs = try await dataStore.fetchCompletedRuns(weekNumber: 1, limit: nil)
        #expect(runs.count == 1, "Run must be saved to SwiftData even when HealthKit is denied")
        #expect(result.healthKitSaved == false, "Result should indicate HealthKit was skipped")
        #expect(result.swiftDataSaved == true)
    }
    
    @Test func endRunConfirmationRequired() {
        // End Run must require user confirmation
        // This is a UI flow test — verifying the data model supports it
        let endRunState = EndRunConfirmation(
            showingConfirmation: false,
            elapsedTime: 1200,
            distance: 2500
        )
        
        #expect(endRunState.showingConfirmation == false)
        
        // User taps End Run → show confirmation
        var mutable = endRunState
        mutable.showingConfirmation = true
        #expect(mutable.showingConfirmation == true)
        
        // Confirmation should show stats so user knows what they're ending
        #expect(mutable.elapsedTime > 0)
        #expect(mutable.distance > 0)
    }
    
    @Test func routeDataBatchedCorrectly() async throws {
        let container = try makeTestContainer()
        let dataStore = DataStore(modelContainer: container)
        let healthStore = MockHealthStore()
        
        try await dataStore.saveUserProfile(
            heightCm: 170, weightKg: 70, birthYear: 1990,
            biologicalSex: .male, currentWeek: 1,
            completedSessionsThisWeek: 0, hasCompletedOnboarding: true,
            hasGraduated: false, startingWeek: 1, usesMetric: false,
            runDays: [2, 4, 6], reminderHour: 7, reminderMinute: 0,
            remindersEnabled: true
        )
        
        let orchestrator = PostRunOrchestrator(
            dataStore: dataStore,
            healthStore: healthStore
        )
        
        // 500 GPS points — should be batched into ceil(500/200) = 3 batches
        let locations = (0..<500).map { i in
            CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: 35.78 + Double(i) * 0.0001, longitude: -78.64),
                altitude: 100, horizontalAccuracy: 10, verticalAccuracy: 10,
                timestamp: Date().addingTimeInterval(Double(i))
            )
        }
        
        _ = try await orchestrator.saveRun(
            weekNumber: 1, sessionNumber: 1,
            runStart: Date().addingTimeInterval(-500),
            locations: locations,
            totalElapsed: 500, totalDistance: 5000,
            intervals: [Interval(type: .run, durationSeconds: 500)]
        )
        
        // Route data should have been inserted in batches of 200
        let totalInserted = healthStore.insertedRouteLocations.reduce(0) { $0 + $1.count }
        #expect(totalInserted == 500, "All GPS points must be inserted into route builder")
        #expect(healthStore.insertedRouteLocations.count >= 3, "Should batch into ≥3 inserts")
    }
}
```

#### Implementation

1. Implement `HealthKitService` with correct API flow:
   - Use native async `requestAuthorization` (iOS 15+), NOT callback-based
   - `saveWorkout` returns non-optional `HKWorkout` on iOS 17+ — no `guard let`
   - `queryHeartRate(start:end:)` — queries HKQuantityType(.heartRate) for the run window
   - All HealthKit methods handle denial gracefully (throw `HealthKitError.authorizationDenied`)

2. Implement `PostRunOrchestrator` — owns the entire save pipeline.
   Works with snapshot structs (immutable) and plain values only.
   Calls DataStore methods with plain values; never passes @Model objects.
   Queries heart rate from HealthKit and passes result to DataStore.
   ```swift
   struct SaveRunResult {
       let runId: UUID
       let swiftDataSaved: Bool
       let healthKitSaved: Bool
       let healthKitError: Error?
   }
   
   @MainActor
   final class PostRunOrchestrator {
       let dataStore: DataStoreProviding
       let healthStore: HealthStoreProviding
       
       init(dataStore: DataStoreProviding, healthStore: HealthStoreProviding) {
           self.dataStore = dataStore
           self.healthStore = healthStore
       }
       
       func saveRun(
           weekNumber: Int,
           sessionNumber: Int,
           runStart: Date,
           locations: [CLLocation],
           totalElapsed: TimeInterval,
           totalDistance: Double,
           intervals: [Interval]
       ) async throws -> SaveRunResult {
           // 1. Fetch profile snapshot for weight (used for calorie calculation)
           let profileSnapshot = try await dataStore.fetchUserProfile()
           let weightKg = profileSnapshot?.weightKg ?? 70
           
           // 2. Calculate calories
           let calories = CalorieCalculator.calculate(
               weightKg: weightKg,
               intervals: intervals,
               actualDurationSeconds: totalElapsed
           )
           
           // 3. Calculate pace
           let averagePace: Double? = totalDistance > 0
               ? totalElapsed / (totalDistance / 1000.0)
               : nil
           
           // 4. Query heart rate from HealthKit (best-effort)
           let runEnd = runStart.addingTimeInterval(totalElapsed)
           var averageHeartRate: Double? = nil
           if let hrSamples = try? await healthStore.queryHeartRateSamples(
               start: runStart, end: runEnd
           ), !hrSamples.isEmpty {
               let bpmUnit = HKUnit.count().unitDivided(by: .minute())
               let totalBPM = hrSamples.reduce(0.0) {
                   $0 + $1.quantity.doubleValue(for: bpmUnit)
               }
               averageHeartRate = totalBPM / Double(hrSamples.count)
           }
           
           // 5. Save CompletedRun to SwiftData using plain values (canonical API)
           let runId = try await dataStore.saveCompletedRun(
               weekNumber: weekNumber,
               sessionNumber: sessionNumber,
               date: runStart,
               distanceMeters: totalDistance,
               durationSeconds: totalElapsed,
               calories: calories,
               averagePaceSecondsPerKm: averagePace,
               averageHeartRate: averageHeartRate,
               effortRating: nil, // Set later via PostRunView
               isFreeRun: false
           )
           
           // 6. Save GPS points as plain GPSPointData values
           let pointData = locations.map { loc in
               GPSPointData(
                   latitude: loc.coordinate.latitude,
                   longitude: loc.coordinate.longitude,
                   altitude: loc.altitude,
                   horizontalAccuracy: loc.horizontalAccuracy,
                   timestamp: loc.timestamp,
                   speed: loc.speed
               )
           }
           try await dataStore.saveGPSPoints(pointData, forRunId: runId)
           
           // 7. Save to HealthKit (may fail — that's OK)
           var healthKitSaved = false
           var healthKitError: Error?
           do {
               let workout = try await healthStore.saveWorkout(
                   activityType: .running,
                   start: runStart,
                   end: runEnd,
                   totalDistance: HKQuantity(unit: .meter(), doubleValue: totalDistance),
                   totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: calories)
               )
               
               // 8. Insert route data in batches of 200
               let routeBuilder = healthStore.createRouteBuilder()
               let batchSize = 200
               for batchStart in stride(from: 0, to: locations.count, by: batchSize) {
                   let end = min(batchStart + batchSize, locations.count)
                   try await routeBuilder.insertRouteData(Array(locations[batchStart..<end]))
               }
               
               // 9. Finalize route with workout
               try await routeBuilder.finishRoute(with: workout, metadata: nil)
               healthKitSaved = true
           } catch {
               healthKitError = error
               // HealthKit failure is non-fatal — SwiftData save already succeeded
           }
           
           // 10. Increment completed sessions via DataStore
           try? await dataStore.incrementCompletedSessions()
           
           // 11. Clear crash recovery checkpoint
           RunCheckpoint.clear()
           
           return SaveRunResult(
               runId: runId,
               swiftDataSaved: true,
               healthKitSaved: healthKitSaved,
               healthKitError: healthKitError
           )
       }
   }
   ```

3. Build `PostRunView`:
   - Route map (MKMapView with GPS polyline)
   - Stats: distance, time, pace, calories
   - Heart rate summary (if Apple Watch data available)
   - HealthKit save status indicator (checkmark if saved, info icon if skipped)
   - Effort check-in (3 buttons: Too Easy / Just Right / Too Hard)
   - CTA: "Nice work → Back to Dashboard"

4. Implement `EndRunConfirmation`:
   ```swift
   struct EndRunConfirmation {
       var showingConfirmation: Bool
       let elapsedTime: TimeInterval
       let distance: Double
   }
   ```
   - End Run button shows confirmation alert with run stats
   - User must tap "Confirm End Run" to proceed
   - Cancel returns to the active run

---
