import Foundation
@testable import MileOne

// MARK: - MockDataStoreError

enum MockDataStoreError: Error {
    case fetchFailed
    case saveFailed
}

// MARK: - MockDataStore

/// In-memory mock conforming to DataStoreProviding.
/// Must be an actor since DataStoreProviding requires Actor conformance.
///
/// Usage:
///   let mock = MockDataStore()
///   await mock.setMockProfile(myProfile)
///   let result = try await mock.fetchUserProfile()
public actor MockDataStore: DataStoreProviding {

    // MARK: - Configurable State

    public var mockProfile: UserProfileSnapshot?
    public var mockRuns: [CompletedRunSnapshot] = []
    public var mockGPSPoints: [GPSPointSnapshot] = []
    public var mockRoutes: [SavedRouteSnapshot] = []
    public var mockLastRunDate: Date?

    // MARK: - Error Injection

    /// Set to true to make fetchUserProfile() throw.
    public var shouldThrowOnFetch: Bool = false
    /// Set to true to make saveUserProfile() throw.
    public var shouldThrowOnSave: Bool = false
    /// Set to true to make fetchCompletedRuns() throw.
    public var shouldThrowOnFetchRuns: Bool = false
    /// Set to true to make saveCompletedRun() throw.
    public var shouldThrowOnSaveRun: Bool = false
    /// Set to true to make saveGPSPoints() throw.
    public var shouldThrowOnSaveGPS: Bool = false
    /// Set to true to make fetchGPSPoints() throw.
    public var shouldThrowOnFetchGPS: Bool = false

    public func setShouldThrowOnFetch(_ value: Bool) { shouldThrowOnFetch = value }
    public func setShouldThrowOnSave(_ value: Bool) { shouldThrowOnSave = value }
    public func setShouldThrowOnFetchRuns(_ value: Bool) { shouldThrowOnFetchRuns = value }
    public func setShouldThrowOnSaveRun(_ value: Bool) { shouldThrowOnSaveRun = value }
    public func setShouldThrowOnSaveGPS(_ value: Bool) { shouldThrowOnSaveGPS = value }
    public func setShouldThrowOnFetchGPS(_ value: Bool) { shouldThrowOnFetchGPS = value }

    // MARK: - Call Tracking

    public var savedRunCount = 0
    public var gpsPointsFetched = false
    public var incrementSessionsCalled = false
    public var advanceWeekCalled = false

    // MARK: - Init

    public init() {}

    // MARK: - Setter Helpers
    // Actors require explicit methods for external mutation.

    public func setMockProfile(_ profile: UserProfileSnapshot?) {
        mockProfile = profile
    }

    public func setMockLastRunDate(_ date: Date?) {
        mockLastRunDate = date
    }

    public func setMockRuns(_ runs: [CompletedRunSnapshot]) {
        mockRuns = runs
    }

    public func setMockGPSPoints(_ points: [GPSPointSnapshot]) {
        mockGPSPoints = points
    }

    public func setMockRoutes(_ routes: [SavedRouteSnapshot]) {
        mockRoutes = routes
    }

    public func resetCallTracking() {
        savedRunCount = 0
        gpsPointsFetched = false
        incrementSessionsCalled = false
        advanceWeekCalled = false
    }

    // MARK: - DataStoreProviding Conformance

    public func fetchUserProfile() async throws -> UserProfileSnapshot? {
        if shouldThrowOnFetch { throw MockDataStoreError.fetchFailed }
        return mockProfile
    }

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
        if shouldThrowOnSave { throw MockDataStoreError.saveFailed }
        mockProfile = UserProfileSnapshot(
            heightCm: heightCm,
            weightKg: weightKg,
            birthYear: birthYear,
            biologicalSex: biologicalSex,
            currentWeek: currentWeek,
            completedSessionsThisWeek: completedSessionsThisWeek,
            hasCompletedOnboarding: hasCompletedOnboarding,
            hasGraduated: hasGraduated,
            startingWeek: startingWeek,
            usesMetric: usesMetric,
            runDays: runDays,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            remindersEnabled: remindersEnabled
        )
    }

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
        if shouldThrowOnSaveRun { throw MockDataStoreError.saveFailed }
        let id = UUID()
        let snapshot = CompletedRunSnapshot(
            id: id,
            weekNumber: weekNumber,
            sessionNumber: sessionNumber,
            date: date,
            distanceMeters: distanceMeters,
            durationSeconds: durationSeconds,
            calories: calories,
            averagePaceSecondsPerKm: averagePaceSecondsPerKm,
            averageHeartRate: averageHeartRate,
            effortRating: effortRating,
            isFreeRun: isFreeRun
        )
        mockRuns.append(snapshot)
        savedRunCount += 1
        return id
    }

    public func fetchCompletedRuns(weekNumber: Int?, limit: Int?) async throws -> [CompletedRunSnapshot] {
        if shouldThrowOnFetchRuns { throw MockDataStoreError.fetchFailed }
        var result = mockRuns
        if let weekNumber {
            result = result.filter { $0.weekNumber == weekNumber }
        }
        if let limit {
            result = Array(result.prefix(limit))
        }
        return result
    }

    public func fetchGPSPoints(forRunId: UUID) async throws -> [GPSPointSnapshot] {
        if shouldThrowOnFetchGPS { throw MockDataStoreError.fetchFailed }
        gpsPointsFetched = true
        return mockGPSPoints
    }

    public func saveGPSPoints(_ points: [GPSPointData], forRunId: UUID) async throws {
        if shouldThrowOnSaveGPS { throw MockDataStoreError.saveFailed }
        mockGPSPoints = points.map { data in
            GPSPointSnapshot(
                latitude:          data.latitude,
                longitude:         data.longitude,
                altitude:          data.altitude,
                timestamp:         data.timestamp,
                speed:             data.speed,
                horizontalAccuracy: data.horizontalAccuracy
            )
        }
    }

    public func fetchSavedRoutes() async throws -> [SavedRouteSnapshot] {
        mockRoutes
    }

    public func saveSavedRoute(
        name: String,
        drawMode: DrawMode,
        waypointsData: Data,
        distanceMeters: Double
    ) async throws -> UUID {
        let id = UUID()
        mockRoutes.append(
            SavedRouteSnapshot(
                id: id,
                name: name,
                createdAt: Date(),
                distanceMeters: distanceMeters,
                drawMode: drawMode
            )
        )
        return id
    }

    public func deleteSavedRoute(id: UUID) async throws {
        mockRoutes.removeAll { $0.id == id }
    }

    public func fetchLastRunDate() async throws -> Date? {
        mockLastRunDate
    }

    public func updateEffortRating(runId: UUID, rating: EffortRating) async throws {
        guard let idx = mockRuns.firstIndex(where: { $0.id == runId }) else { return }
        let old = mockRuns[idx]
        mockRuns[idx] = CompletedRunSnapshot(
            id: old.id,
            weekNumber: old.weekNumber,
            sessionNumber: old.sessionNumber,
            date: old.date,
            distanceMeters: old.distanceMeters,
            durationSeconds: old.durationSeconds,
            calories: old.calories,
            averagePaceSecondsPerKm: old.averagePaceSecondsPerKm,
            averageHeartRate: old.averageHeartRate,
            effortRating: rating,
            isFreeRun: old.isFreeRun
        )
    }

    public func incrementCompletedSessions() async throws {
        incrementSessionsCalled = true
        guard let profile = mockProfile else { return }
        mockProfile = UserProfileSnapshot(
            heightCm: profile.heightCm,
            weightKg: profile.weightKg,
            birthYear: profile.birthYear,
            biologicalSex: profile.biologicalSex,
            currentWeek: profile.currentWeek,
            completedSessionsThisWeek: profile.completedSessionsThisWeek + 1,
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

    public func advanceWeek() async throws {
        advanceWeekCalled = true
        guard let profile = mockProfile else { return }
        if profile.currentWeek >= 9 {
            if profile.completedSessionsThisWeek >= 3 && !profile.hasGraduated {
                mockProfile = UserProfileSnapshot(
                    heightCm: profile.heightCm,
                    weightKg: profile.weightKg,
                    birthYear: profile.birthYear,
                    biologicalSex: profile.biologicalSex,
                    currentWeek: profile.currentWeek,
                    completedSessionsThisWeek: profile.completedSessionsThisWeek,
                    hasCompletedOnboarding: profile.hasCompletedOnboarding,
                    hasGraduated: true,
                    startingWeek: profile.startingWeek,
                    usesMetric: profile.usesMetric,
                    runDays: profile.runDays,
                    reminderHour: profile.reminderHour,
                    reminderMinute: profile.reminderMinute,
                    remindersEnabled: profile.remindersEnabled
                )
            }
            return
        }
        mockProfile = UserProfileSnapshot(
            heightCm: profile.heightCm,
            weightKg: profile.weightKg,
            birthYear: profile.birthYear,
            biologicalSex: profile.biologicalSex,
            currentWeek: profile.currentWeek + 1,
            completedSessionsThisWeek: 0,
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
}
