import Foundation

// MARK: - DataStoreProviding

/// Protocol that all DataStore implementations and mocks must conform to.
/// Requires Actor conformance to enforce structured concurrency.
/// All methods are async throws to support SwiftData and error propagation.
public protocol DataStoreProviding: Actor {

    func fetchUserProfile() async throws -> UserProfileSnapshot?

    func saveUserProfile(
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
    ) async throws

    func saveCompletedRun(
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
    ) async throws -> UUID

    /// Fetch runs, optionally filtered by weekNumber. Nil weekNumber = all runs.
    func fetchCompletedRuns(weekNumber: Int?, limit: Int?) async throws -> [CompletedRunSnapshot]

    func fetchGPSPoints(forRunId: UUID) async throws -> [GPSPointSnapshot]

    /// Accepts plain GPSPointData values (not @Model objects) to avoid cross-actor isolation violations.
    func saveGPSPoints(_ points: [GPSPointData], forRunId: UUID) async throws

    func fetchSavedRoutes() async throws -> [SavedRouteSnapshot]

    func saveSavedRoute(
        name: String,
        drawMode: DrawMode,
        waypointsData: Data,
        distanceMeters: Double
    ) async throws -> UUID

    func deleteSavedRoute(id: UUID) async throws

    func fetchLastRunDate() async throws -> Date?

    func updateEffortRating(runId: UUID, rating: EffortRating) async throws

    func incrementCompletedSessions() async throws
}
