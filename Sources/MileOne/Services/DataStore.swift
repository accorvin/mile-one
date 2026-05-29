import Foundation
import SwiftData

// MARK: - DataStore

/// Persistent data store backed by SwiftData.
/// @ModelActor provides actor isolation — all methods run on the model executor.
@ModelActor
public actor DataStore: DataStoreProviding {

    // MARK: - UserProfile

    public func fetchUserProfile() async throws -> UserProfileSnapshot? {
        let descriptor = FetchDescriptor<UserProfile>()
        let profiles = try modelContext.fetch(descriptor)
        guard let profile = profiles.first else { return nil }
        return snapshot(from: profile)
    }

    /// Upsert: fetch the singleton profile and update it, or insert if it doesn't exist.
    /// This prevents duplicate profiles from accumulating (critical for CloudKit sync).
    public func saveUserProfile(
        heightCm: Double,
        weightKg: Double,
        birthYear: Int,
        biologicalSex: BiologicalSex,
        currentWeek: Int,
        completedSessionsThisWeek: Int,
        hasCompletedOnboarding: Bool,
        hasGraduated: Bool,
        startingWeek: Int,
        usesMetric: Bool,
        runDays: [Int],
        reminderHour: Int,
        reminderMinute: Int,
        remindersEnabled: Bool
    ) async throws {
        let descriptor = FetchDescriptor<UserProfile>()
        let profiles = try modelContext.fetch(descriptor)

        let profile: UserProfile
        if let existing = profiles.first {
            profile = existing
        } else {
            profile = UserProfile()
            modelContext.insert(profile)
        }

        profile.heightCm = heightCm
        profile.weightKg = weightKg
        profile.birthYear = birthYear
        profile.biologicalSex = biologicalSex.rawValue
        profile.currentWeek = currentWeek
        profile.completedSessionsThisWeek = completedSessionsThisWeek
        profile.hasCompletedOnboarding = hasCompletedOnboarding
        profile.hasGraduated = hasGraduated
        profile.startingWeek = startingWeek
        profile.usesMetric = usesMetric
        profile.runDays = runDays
        profile.reminderHour = reminderHour
        profile.reminderMinute = reminderMinute
        profile.remindersEnabled = remindersEnabled
        profile.updatedAt = Date()

        try modelContext.save()
    }

    // MARK: - CompletedRun

    public func saveCompletedRun(
        weekNumber: Int,
        sessionNumber: Int,
        date: Date,
        distanceMeters: Double,
        durationSeconds: Double,
        calories: Double,
        averagePaceSecondsPerKm: Double?,
        averageHeartRate: Double?,
        effortRating: EffortRating?,
        isFreeRun: Bool
    ) async throws -> UUID {
        let run = CompletedRun(weekNumber: weekNumber, sessionNumber: sessionNumber, isFreeRun: isFreeRun)
        run.date = date
        run.distanceMeters = distanceMeters
        run.durationSeconds = durationSeconds
        run.calories = calories
        run.averagePaceSecondsPerKm = averagePaceSecondsPerKm
        run.averageHeartRate = averageHeartRate
        run.effortRating = effortRating?.rawValue

        modelContext.insert(run)
        try modelContext.save()
        return run.id
    }

    public func fetchCompletedRuns(weekNumber: Int?, limit: Int?) async throws -> [CompletedRunSnapshot] {
        var descriptor: FetchDescriptor<CompletedRun>

        if let weekNumber {
            let predicate = #Predicate<CompletedRun> { run in
                run.weekNumber == weekNumber
            }
            descriptor = FetchDescriptor<CompletedRun>(predicate: predicate, sortBy: [SortDescriptor(\.date, order: .reverse)])
        } else {
            descriptor = FetchDescriptor<CompletedRun>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        }

        if let limit {
            descriptor.fetchLimit = limit
        }

        let runs = try modelContext.fetch(descriptor)
        return runs.map { snapshot(from: $0) }
    }

    // MARK: - GPS Points

    public func fetchGPSPoints(forRunId: UUID) async throws -> [GPSPointSnapshot] {
        let predicate = #Predicate<GPSPoint> { point in
            point.run?.id == forRunId
        }
        let descriptor = FetchDescriptor<GPSPoint>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp)]
        )
        let points = try modelContext.fetch(descriptor)
        return points.map { snapshot(from: $0) }
    }

    /// Saves GPS points in batches of 50 to avoid memory pressure.
    public func saveGPSPoints(_ points: [GPSPointData], forRunId: UUID) async throws {
        // Find the owning run
        let predicate = #Predicate<CompletedRun> { run in
            run.id == forRunId
        }
        let descriptor = FetchDescriptor<CompletedRun>(predicate: predicate)
        guard let run = try modelContext.fetch(descriptor).first else {
            throw DataStoreError.runNotFound(forRunId)
        }

        // Batch insert in chunks of 50
        let chunkSize = 50
        var offset = 0
        while offset < points.count {
            let chunk = Array(points[offset..<min(offset + chunkSize, points.count)])
            for data in chunk {
                let point = GPSPoint(
                    latitude: data.latitude,
                    longitude: data.longitude,
                    altitude: data.altitude,
                    horizontalAccuracy: data.horizontalAccuracy,
                    timestamp: data.timestamp,
                    speed: data.speed
                )
                point.run = run
                modelContext.insert(point)
            }
            offset += chunkSize
        }
        try modelContext.save()
    }

    // MARK: - Saved Routes

    public func fetchSavedRoutes() async throws -> [SavedRouteSnapshot] {
        let descriptor = FetchDescriptor<SavedRoute>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let routes = try modelContext.fetch(descriptor)
        return routes.map { snapshot(from: $0) }
    }

    public func saveSavedRoute(
        name: String,
        drawMode: DrawMode,
        waypointsData: Data,
        distanceMeters: Double
    ) async throws -> UUID {
        let route = SavedRoute(name: name, drawMode: drawMode, waypoints: waypointsData)
        route.distanceMeters = distanceMeters
        modelContext.insert(route)
        try modelContext.save()
        return route.id
    }

    public func deleteSavedRoute(id: UUID) async throws {
        let predicate = #Predicate<SavedRoute> { route in
            route.id == id
        }
        let descriptor = FetchDescriptor<SavedRoute>(predicate: predicate)
        let routes = try modelContext.fetch(descriptor)
        for route in routes {
            modelContext.delete(route)
        }
        try modelContext.save()
    }

    // MARK: - Miscellaneous

    public func fetchLastRunDate() async throws -> Date? {
        var descriptor = FetchDescriptor<CompletedRun>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        let runs = try modelContext.fetch(descriptor)
        return runs.first?.date
    }

    public func updateEffortRating(runId: UUID, rating: EffortRating) async throws {
        let predicate = #Predicate<CompletedRun> { run in
            run.id == runId
        }
        let descriptor = FetchDescriptor<CompletedRun>(predicate: predicate)
        guard let run = try modelContext.fetch(descriptor).first else {
            throw DataStoreError.runNotFound(runId)
        }
        run.effortRating = rating.rawValue
        try modelContext.save()
    }

    public func incrementCompletedSessions() async throws {
        let descriptor = FetchDescriptor<UserProfile>()
        guard let profile = try modelContext.fetch(descriptor).first else {
            throw DataStoreError.profileNotFound
        }
        profile.completedSessionsThisWeek += 1
        profile.updatedAt = Date()
        try modelContext.save()
    }

    // MARK: - Snapshot Factories (private helpers)

    private func snapshot(from profile: UserProfile) -> UserProfileSnapshot {
        UserProfileSnapshot(
            heightCm: profile.heightCm,
            weightKg: profile.weightKg,
            birthYear: profile.birthYear,
            biologicalSex: BiologicalSex(rawValue: profile.biologicalSex) ?? .male,
            currentWeek: profile.currentWeek,
            completedSessionsThisWeek: profile.completedSessionsThisWeek,
            hasCompletedOnboarding: profile.hasCompletedOnboarding,
            hasGraduated: profile.hasGraduated,
            startingWeek: profile.startingWeek,
            usesMetric: profile.usesMetric,
            runDays: profile.runDays,
            reminderHour: profile.reminderHour,
            reminderMinute: profile.reminderMinute,
            remindersEnabled: profile.remindersEnabled
        )
    }

    private func snapshot(from run: CompletedRun) -> CompletedRunSnapshot {
        CompletedRunSnapshot(
            id: run.id,
            weekNumber: run.weekNumber,
            sessionNumber: run.sessionNumber,
            date: run.date,
            distanceMeters: run.distanceMeters,
            durationSeconds: run.durationSeconds,
            calories: run.calories,
            averagePaceSecondsPerKm: run.averagePaceSecondsPerKm,
            averageHeartRate: run.averageHeartRate,
            effortRating: run.effortRating.flatMap { EffortRating(rawValue: $0) },
            isFreeRun: run.isFreeRun
        )
    }

    private func snapshot(from point: GPSPoint) -> GPSPointSnapshot {
        GPSPointSnapshot(
            latitude: point.latitude,
            longitude: point.longitude,
            altitude: point.altitude,
            timestamp: point.timestamp,
            speed: point.speedMetersPerSecond,
            horizontalAccuracy: point.horizontalAccuracy
        )
    }

    private func snapshot(from route: SavedRoute) -> SavedRouteSnapshot {
        SavedRouteSnapshot(
            id: route.id,
            name: route.name,
            createdAt: route.createdAt,
            distanceMeters: route.distanceMeters,
            drawMode: DrawMode(rawValue: route.drawMode) ?? .freeDraw
        )
    }
}

// MARK: - DataStoreError

public enum DataStoreError: Error, Sendable {
    case profileNotFound
    case runNotFound(UUID)
    case routeNotFound(UUID)
}
