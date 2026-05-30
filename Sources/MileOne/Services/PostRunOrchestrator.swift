import Foundation
import CoreLocation

#if canImport(HealthKit)
import HealthKit
#endif

// MARK: - PostRunOrchestrator

/// Owns the entire post-run save pipeline.
/// All dependencies are injected for testability.
///
/// Save order:
/// 1. Fetch user profile (for weight → calorie calculation)
/// 2. Calculate calories + average pace
/// 3. Query heart rate from HealthKit (best-effort, non-fatal)
/// 4. Persist CompletedRun to SwiftData
/// 5. Persist GPS points to SwiftData
/// 6. Save workout + route to HealthKit (non-fatal if denied or unavailable)
/// 7. Increment completedSessionsThisWeek in SwiftData
/// 8. Clear crash-recovery checkpoint
@MainActor
public final class PostRunOrchestrator {

    // MARK: - Dependencies

    public let dataStore: any DataStoreProviding

#if canImport(HealthKit)
    public let healthStore: any HealthStoreProviding

    public init(
        dataStore: any DataStoreProviding,
        healthStore: any HealthStoreProviding
    ) {
        self.dataStore = dataStore
        self.healthStore = healthStore
    }
#else
    public init(dataStore: any DataStoreProviding) {
        self.dataStore = dataStore
    }
#endif

    // MARK: - Save Pipeline

    public func saveRun(
        weekNumber: Int,
        sessionNumber: Int,
        runStart: Date,
        locations: [CLLocation],
        totalElapsed: TimeInterval,
        totalDistance: Double,
        intervals: [Interval]
    ) async throws -> SaveRunResult {

        let runEnd = runStart.addingTimeInterval(totalElapsed)

        // 1. Fetch profile for weight
        let profileSnapshot = try await dataStore.fetchUserProfile()
        let weightKg = profileSnapshot?.weightKg ?? 70.0

        // 2. Calculate calories and pace
        let calories = CalorieCalculator.calculate(
            weightKg: weightKg,
            intervals: intervals,
            actualDurationSeconds: totalElapsed
        )
        let averagePace: Double? = totalDistance > 0
            ? totalElapsed / (totalDistance / 1000.0)
            : nil

        // 3. Query heart rate from HealthKit (best-effort, macOS-safe)
        var averageHeartRate: Double? = nil
#if canImport(HealthKit)
        if let samples = try? await healthStore.queryHeartRateSamples(
            start: runStart, end: runEnd
        ), !samples.isEmpty {
            let bpmUnit = HKUnit.count().unitDivided(by: .minute())
            let total = samples.reduce(0.0) { $0 + $1.quantity.doubleValue(for: bpmUnit) }
            averageHeartRate = total / Double(samples.count)
        }
#endif

        // 4. Save CompletedRun to SwiftData
        let runId = try await dataStore.saveCompletedRun(
            weekNumber: weekNumber,
            sessionNumber: sessionNumber,
            date: runStart,
            distanceMeters: totalDistance,
            durationSeconds: totalElapsed,
            calories: calories,
            averagePaceSecondsPerKm: averagePace,
            averageHeartRate: averageHeartRate,
            effortRating: nil,
            isFreeRun: false
        )

        // 5. Save GPS points to SwiftData (convert CLLocation → GPSPointData)
        let pointData = locations.map { loc in
            GPSPointData(
                latitude: loc.coordinate.latitude,
                longitude: loc.coordinate.longitude,
                altitude: loc.altitude,
                horizontalAccuracy: loc.horizontalAccuracy,
                timestamp: loc.timestamp,
                speed: max(loc.speed, 0)
            )
        }
        try await dataStore.saveGPSPoints(pointData, forRunId: runId)

        // 6. Save to HealthKit (non-fatal — SwiftData has already succeeded by this point)
        var healthKitSaved = false
        var healthKitError: Error? = nil

#if canImport(HealthKit)
        do {
            let distanceQuantity = HKQuantity(unit: .meter(), doubleValue: totalDistance)
            let caloriesQuantity = HKQuantity(unit: .kilocalorie(), doubleValue: calories)

            let workout = try await healthStore.saveWorkout(
                activityType: .running,
                start: runStart,
                end: runEnd,
                totalDistance: distanceQuantity,
                totalEnergyBurned: caloriesQuantity
            )

            // Insert route GPS data in batches of 200
            let batchSize = 200
            var offset = 0
            while offset < locations.count {
                let batchEnd = min(offset + batchSize, locations.count)
                let batch = Array(locations[offset..<batchEnd])
                try await healthStore.insertRouteData(batch)
                offset = batchEnd
            }

            // Finalize route and associate with workout
            try await healthStore.finishRoute(with: workout)
            healthKitSaved = true
        } catch {
            healthKitError = error
            // HealthKit failure is intentionally non-fatal.
            // Run data is safe in SwiftData.
        }
#endif

        // 7. Increment completed sessions in user profile (best-effort)
        try? await dataStore.incrementCompletedSessions()

        // 8. Clear the crash-recovery checkpoint
        RunCheckpoint.clear()

        return SaveRunResult(
            runId: runId,
            swiftDataSaved: true,
            healthKitSaved: healthKitSaved,
            healthKitError: healthKitError
        )
    }
}
