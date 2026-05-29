← [Back to Index](README.md)

# Mile One — Service Layer Design

## 5. Service Layer Design

### 5a. Protocol Abstractions

```swift
// MARK: - LocationProviding

protocol LocationProviding: AnyObject {
    var authorizationStatus: CLAuthorizationStatus { get }
    var onLocationUpdate: ((CLLocation) -> Void)? { get set }
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)? { get set }
    var onLocationError: ((Error) -> Void)? { get set }
    
    func requestWhenInUseAuthorization()
    func requestAlwaysAuthorization()
    func startUpdatingLocation()
    func stopUpdatingLocation()
}

// MARK: - HealthStoreProviding

protocol HealthStoreProviding: AnyObject {
    func requestAuthorization(
        toShare: Set<HKSampleType>,
        read: Set<HKObjectType>
    ) async throws -> Bool
    
    func saveWorkout(
        activityType: HKWorkoutActivityType,
        start: Date,
        end: Date,
        totalDistance: HKQuantity,
        totalEnergyBurned: HKQuantity
    ) async throws -> HKWorkout
    
    func createRouteBuilder() -> HKWorkoutRouteBuilder
    
    func readMostRecentSample(
        for type: HKQuantityType
    ) async throws -> HKQuantitySample?
    
    func queryHeartRateSamples(
        start: Date,
        end: Date
    ) async throws -> [HKQuantitySample]
}

// MARK: - AudioCoaching

protocol AudioCoaching: AnyObject {
    func configureAudioSession() throws
    func speak(_ text: String)
    func stop()
    func deactivateSession()
}

// MARK: - TimeProviding (injectable time source for testable wall-clock operations)

protocol TimeProviding {
    func now() -> Date
}

struct SystemTimeProvider: TimeProviding {
    func now() -> Date { Date() }
}

// MARK: - Snapshot Structs (returned from DataStore — never @Model objects)
// These are the CANONICAL definitions. All other files must match exactly.

struct UserProfileSnapshot: Sendable {
    let heightCm: Double
    let weightKg: Double
    let birthYear: Int
    let biologicalSex: BiologicalSex
    let currentWeek: Int
    let completedSessionsThisWeek: Int
    let hasCompletedOnboarding: Bool
    let hasGraduated: Bool
    let startingWeek: Int
    let usesMetric: Bool
    let runDays: [Int]
    let reminderHour: Int
    let reminderMinute: Int
    let remindersEnabled: Bool
}

struct CompletedRunSnapshot: Sendable, Identifiable {
    let id: UUID
    let weekNumber: Int
    let sessionNumber: Int
    let date: Date
    let distanceMeters: Double
    let durationSeconds: Double
    let calories: Double
    let averagePaceSecondsPerKm: Double?
    let averageHeartRate: Double?
    let effortRating: EffortRating?
    let isFreeRun: Bool
}

struct GPSPointSnapshot: Sendable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let timestamp: Date
    let speed: Double
    let horizontalAccuracy: Double
}

/// Plain-value struct for passing GPS data across actor boundaries.
/// Used instead of @Model GPSPoint objects to avoid cross-actor isolation violations.
struct GPSPointData: Sendable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let horizontalAccuracy: Double
    let timestamp: Date
    let speed: Double
}

struct SavedRouteSnapshot: Sendable, Identifiable {
    let id: UUID
    let name: String
    let createdAt: Date
    let distanceMeters: Double
    let drawMode: DrawMode
}

// MARK: - DataStoreProviding
// This is the CANONICAL protocol. All mocks and callers must match exactly.

protocol DataStoreProviding: Actor {
    func fetchUserProfile() async throws -> UserProfileSnapshot?
    func saveUserProfile(
        heightCm: Double, weightKg: Double, birthYear: Int,
        biologicalSex: BiologicalSex, currentWeek: Int,
        completedSessionsThisWeek: Int, hasCompletedOnboarding: Bool,
        hasGraduated: Bool, startingWeek: Int, usesMetric: Bool,
        runDays: [Int], reminderHour: Int, reminderMinute: Int,
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
    func fetchCompletedRuns(
        weekNumber: Int?, limit: Int?
    ) async throws -> [CompletedRunSnapshot]
    func fetchGPSPoints(forRunId: UUID) async throws -> [GPSPointSnapshot]
    /// Accepts plain GPSPointData values (not @Model objects) to avoid cross-actor violations.
    func saveGPSPoints(_ points: [GPSPointData], forRunId: UUID) async throws
    func fetchSavedRoutes() async throws -> [SavedRouteSnapshot]
    /// Accepts plain values (not @Model objects) to avoid cross-actor violations.
    func saveSavedRoute(
        name: String, drawMode: DrawMode,
        waypointsData: Data, distanceMeters: Double
    ) async throws -> UUID
    /// Accepts UUID (not @Model object) to avoid cross-actor violations.
    func deleteSavedRoute(id: UUID) async throws
    func fetchLastRunDate() async throws -> Date?
    func updateEffortRating(runId: UUID, rating: EffortRating) async throws
    func incrementCompletedSessions() async throws
}
```

### 5b. LocationService

```swift
final class LocationService: NSObject, LocationProviding, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    
    var authorizationStatus: CLAuthorizationStatus {
        manager.authorizationStatus
    }
    var onLocationUpdate: ((CLLocation) -> Void)?
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?
    var onLocationError: ((Error) -> Void)?
    
    // GPS accuracy ramp-up: accept all points for first 60 seconds,
    // then filter > 50m accuracy (not 20m — too aggressive)
    // Uses monotonic time (ProcessInfo.systemUptime) to avoid clock-change issues
    private var startUptime: TimeInterval?
    private let graceperiodSeconds: TimeInterval = 60
    private let accuracyThresholdMeters: Double = 50
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5  // meters — balance accuracy vs battery
        // NOTE: allowsBackgroundLocationUpdates set only after authorization granted
        manager.showsBackgroundLocationIndicator = true
        manager.pausesLocationUpdatesAutomatically = false
    }
    
    func requestWhenInUseAuthorization() {
        manager.requestWhenInUseAuthorization()
    }
    
    func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }
    
    func startUpdatingLocation() {
        startUptime = ProcessInfo.processInfo.systemUptime
        manager.startUpdatingLocation()
    }
    
    func stopUpdatingLocation() {
        manager.stopUpdatingLocation()
        startUptime = nil
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            // GPS accuracy ramp-up strategy (monotonic time)
            if let start = startUptime {
                let elapsed = ProcessInfo.processInfo.systemUptime - start
                if elapsed > graceperiodSeconds
                    && location.horizontalAccuracy > accuracyThresholdMeters {
                    continue // skip inaccurate points after grace period
                }
            }
            onLocationUpdate?(location)
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        // Enable background updates only after authorization granted
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            manager.allowsBackgroundLocationUpdates = true
        }
        onAuthorizationChange?(status)
    }
    
    func locationManager(_ manager: CLLocationManager,
                         didFailWithError error: Error) {
        onLocationError?(error)
    }
}
```

### 5c. HealthKitService

```swift
final class HealthKitService: HealthStoreProviding {
    private let store = HKHealthStore()
    
    func requestAuthorization(
        toShare: Set<HKSampleType>,
        read: Set<HKObjectType>
    ) async throws -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.healthDataNotAvailable
        }
        // Use native async API (no withCheckedThrowingContinuation needed)
        try await store.requestAuthorization(toShare: toShare, read: read)
        return true
    }
    
    /// Save an HKWorkout. Returns the saved workout for route association.
    func saveWorkout(
        activityType: HKWorkoutActivityType,
        start: Date,
        end: Date,
        totalDistance: HKQuantity,
        totalEnergyBurned: HKQuantity
    ) async throws -> HKWorkout {
        let config = HKWorkoutConfiguration()
        config.activityType = activityType
        config.locationType = .outdoor
        
        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        try await builder.beginCollection(at: start)
        
        // Add distance sample
        let distanceSample = HKQuantitySample(
            type: HKQuantityType(.distanceWalkingRunning),
            quantity: totalDistance,
            start: start, end: end
        )
        
        // Add calorie sample
        let calorieSample = HKQuantitySample(
            type: HKQuantityType(.activeEnergyBurned),
            quantity: totalEnergyBurned,
            start: start, end: end
        )
        
        try await builder.addSamples([distanceSample, calorieSample])
        try await builder.endCollection(at: end)
        
        // finishWorkout() can throw if HealthKit permission was revoked mid-run
        do {
            let workout = try await builder.finishWorkout()
            return workout
        } catch {
            throw HealthKitError.workoutFinishFailed(underlying: error)
        }
    }
    
    /// Create a route builder. NOTE: init takes healthStore + device only.
    /// Route is associated with the workout via finishRoute(with:metadata:) AFTER
    /// the workout is saved.
    func createRouteBuilder() -> HKWorkoutRouteBuilder {
        HKWorkoutRouteBuilder(healthStore: store, device: .local())
    }
    
    func readMostRecentSample(
        for type: HKQuantityType
    ) async throws -> HKQuantitySample? {
        try await withCheckedThrowingContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: type, predicate: nil,
                limit: 1, sortDescriptors: [sort]
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: samples?.first as? HKQuantitySample) }
            }
            store.execute(query)
        }
    }
    
    /// Query heart rate samples for a time range (e.g. during a workout).
    func queryHeartRateSamples(
        start: Date,
        end: Date
    ) async throws -> [HKQuantitySample] {
        let heartRateType = HKQuantityType(.heartRate)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    let hrSamples = (samples as? [HKQuantitySample]) ?? []
                    continuation.resume(returning: hrSamples)
                }
            }
            store.execute(query)
        }
    }
}

enum HealthKitError: Error {
    case healthDataNotAvailable
    case authorizationDenied
    case workoutFinishFailed(underlying: Error)
    case routeFinishFailed
}
```

**Route builder flow (correct API usage)**:
```swift
// 1. Create builder at run start (no workout parameter)
let routeBuilder = healthKitService.createRouteBuilder()

// 2. During run: RunEngine calls insertRouteData in batches via location callback
//    RunEngine accumulates GPS points and flushes to routeBuilder every ~200 points
locationProvider.onLocationUpdate = { [weak self] location in
    self?.handleLocationUpdate(location)
    self?.routeLocations.append(location)
    if self?.routeLocations.count ?? 0 >= 200 {
        let batch = self?.routeLocations ?? []
        self?.routeLocations.removeAll()
        Task { try await routeBuilder.insertRouteData(batch) }
    }
}

// 3. After run ends: flush remaining GPS points to route builder
if !routeLocations.isEmpty {
    try await routeBuilder.insertRouteData(routeLocations)
}

// 4. Save the workout FIRST
let workout = try await healthKitService.saveWorkout(...)

// 5. THEN associate the route with the saved workout
try await routeBuilder.finishRoute(with: workout, metadata: nil)
```

### 5d. AudioCoachService

```swift
import AVFoundation

final class AudioCoachService: NSObject, AudioCoaching, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    
    override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        // .duckOthers lowers other audio while speaking, then restores
        // Known limitation: unreliable with some third-party audio apps (Spotify)
        try session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers, .mixWithOthers])
        try session.setActive(true)
    }
    
    func speak(_ text: String) {
        // Cancel any queued utterances before speaking new one
        synthesizer.stopSpeaking(at: .immediate)
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.voice = AVSpeechSynthesisVoice(language: Locale.current.language.languageCode?.identifier ?? "en")
        utterance.volume = 1.0
        synthesizer.speak(utterance)
    }
    
    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
    
    /// Deactivate audio session when done speaking (call explicitly, not from delegate)
    func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false,
            options: .notifyOthersOnDeactivation)
    }
    
    // Delegate — no audio session deactivation here (can cause issues)
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           didFinish utterance: AVSpeechUtterance) {
        // Intentionally empty — deactivation handled by deactivateSession()
    }
}
```

### 5e. RouteService (MKDirections with Rate Limiting)

```swift
import MapKit

actor RouteService {
    private var lastRequestTime: Date = .distantPast
    private let minimumInterval: TimeInterval = 2.0 // seconds between requests
    private var cache: [String: MKRoute] = [:]      // keyed by "lat,lng->lat,lng"
    private var cacheOrder: [String] = []            // LRU order (oldest first)
    private let maxCacheSize = 50
    
    /// Calculate a route between two points with rate limiting and caching.
    func calculateRoute(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) async throws -> MKRoute {
        let cacheKey = String(format: "%.6f,%.6f->%.6f,%.6f",
                              from.latitude, from.longitude,
                              to.latitude, to.longitude)
        
        if let cached = cache[cacheKey] {
            // Move to end of LRU order (most recently used)
            cacheOrder.removeAll { $0 == cacheKey }
            cacheOrder.append(cacheKey)
            return cached
        }
        
        // Rate limiting: wait if too soon (with cancellation support)
        let elapsed = Date().timeIntervalSince(lastRequestTime)
        if elapsed < minimumInterval {
            try Task.checkCancellation()
            try await Task.sleep(for: .seconds(minimumInterval - elapsed))
            try Task.checkCancellation()
        }
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        request.transportType = .walking
        
        lastRequestTime = Date()
        let directions = MKDirections(request: request)
        let response = try await directions.calculate()
        
        guard let route = response.routes.first else {
            throw RouteError.noRouteFound
        }
        
        // LRU eviction: remove oldest if at capacity
        if cache.count >= maxCacheSize, let oldest = cacheOrder.first {
            cacheOrder.removeFirst()
            cache.removeValue(forKey: oldest)
        }
        
        cache[cacheKey] = route
        cacheOrder.append(cacheKey)
        return route
    }
    
    /// Calculate a multi-waypoint route (sequential segments).
    /// Handles rate limiting automatically between segments.
    func calculateMultiWaypointRoute(
        waypoints: [CLLocationCoordinate2D]
    ) async throws -> [MKRoute] {
        guard waypoints.count >= 2 else { throw RouteError.insufficientWaypoints }
        
        var routes: [MKRoute] = []
        for i in 0..<(waypoints.count - 1) {
            let route = try await calculateRoute(from: waypoints[i], to: waypoints[i + 1])
            routes.append(route)
        }
        return routes
    }
    
    func clearCache() {
        cache.removeAll()
        cacheOrder.removeAll()
    }
}

enum RouteError: Error {
    case noRouteFound
    case insufficientWaypoints
    case rateLimited
}
```

### 5f. DataStore

```swift
import SwiftData

@ModelActor
actor DataStore: DataStoreProviding {
    
    func fetchUserProfile() throws -> UserProfileSnapshot? {
        let descriptor = FetchDescriptor<UserProfile>()
        guard let profile = try modelContext.fetch(descriptor).first else { return nil }
        return UserProfileSnapshot(
            heightCm: profile.heightCm,
            weightKg: profile.weightKg,
            birthYear: profile.birthYear,
            biologicalSex: profile.biologicalSex,
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
    
    /// Accept plain values (not @Model objects) to avoid cross-actor violations.
    func saveUserProfile(
        heightCm: Double, weightKg: Double, birthYear: Int,
        biologicalSex: BiologicalSex, currentWeek: Int,
        completedSessionsThisWeek: Int, hasCompletedOnboarding: Bool,
        hasGraduated: Bool, startingWeek: Int, usesMetric: Bool,
        runDays: [Int], reminderHour: Int, reminderMinute: Int,
        remindersEnabled: Bool
    ) throws {
        let descriptor = FetchDescriptor<UserProfile>()
        if let existing = try modelContext.fetch(descriptor).first {
            existing.heightCm = heightCm
            existing.weightKg = weightKg
            existing.birthYear = birthYear
            existing.biologicalSex = biologicalSex
            existing.currentWeek = currentWeek
            existing.completedSessionsThisWeek = completedSessionsThisWeek
            existing.hasCompletedOnboarding = hasCompletedOnboarding
            existing.hasGraduated = hasGraduated
            existing.startingWeek = startingWeek
            existing.usesMetric = usesMetric
            existing.runDays = runDays
            existing.reminderHour = reminderHour
            existing.reminderMinute = reminderMinute
            existing.remindersEnabled = remindersEnabled
        } else {
            let profile = UserProfile()
            profile.heightCm = heightCm
            profile.weightKg = weightKg
            profile.birthYear = birthYear
            profile.biologicalSex = biologicalSex
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
            modelContext.insert(profile)
        }
        try modelContext.save()
    }
    
    /// Accept plain values and construct CompletedRun inside the actor.
    /// Returns the UUID of the saved run.
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
    ) throws -> UUID {
        let run = CompletedRun(weekNumber: weekNumber, sessionNumber: sessionNumber, isFreeRun: isFreeRun)
        run.date = date
        run.distanceMeters = distanceMeters
        run.durationSeconds = durationSeconds
        run.calories = calories
        run.averagePaceSecondsPerKm = averagePaceSecondsPerKm
        run.averageHeartRate = averageHeartRate
        run.effortRating = effortRating
        modelContext.insert(run)
        try modelContext.save()
        return run.id
    }
    
    func fetchCompletedRuns(weekNumber: Int?, limit: Int?) throws -> [CompletedRunSnapshot] {
        var descriptor = FetchDescriptor<CompletedRun>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        if let limit { descriptor.fetchLimit = limit }
        
        if let weekNumber {
            descriptor.predicate = #Predicate { $0.weekNumber == weekNumber }
        }
        
        let runs = try modelContext.fetch(descriptor)
        return runs.map { run in
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
                effortRating: run.effortRating,
                isFreeRun: run.isFreeRun
            )
        }
    }
    
    func fetchGPSPoints(forRunId runId: UUID) throws -> [GPSPointSnapshot] {
        let descriptor = FetchDescriptor<CompletedRun>(
            predicate: #Predicate { $0.id == runId }
        )
        guard let run = try modelContext.fetch(descriptor).first else { return [] }
        let points = run.gpsPoints ?? []
        return points.map { pt in
            GPSPointSnapshot(
                latitude: pt.latitude,
                longitude: pt.longitude,
                altitude: pt.altitude,
                timestamp: pt.timestamp,
                speed: pt.speedMetersPerSecond,
                horizontalAccuracy: pt.horizontalAccuracy
            )
        }
    }
    
    /// Accepts plain GPSPointData values (not @Model objects) to avoid cross-actor violations.
    /// Batch GPS saves in chunks of 50.
    func saveGPSPoints(_ points: [GPSPointData], forRunId runId: UUID) throws {
        let descriptor = FetchDescriptor<CompletedRun>(
            predicate: #Predicate { $0.id == runId }
        )
        guard let run = try modelContext.fetch(descriptor).first else { return }
        
        let chunkSize = 50
        for chunkStart in stride(from: 0, to: points.count, by: chunkSize) {
            let end = min(chunkStart + chunkSize, points.count)
            for i in chunkStart..<end {
                let pt = points[i]
                let gpsPoint = GPSPoint(
                    latitude: pt.latitude,
                    longitude: pt.longitude,
                    altitude: pt.altitude,
                    horizontalAccuracy: pt.horizontalAccuracy,
                    timestamp: pt.timestamp,
                    speed: pt.speed
                )
                gpsPoint.run = run
                modelContext.insert(gpsPoint)
            }
            try modelContext.save()
        }
    }
    
    func fetchSavedRoutes() throws -> [SavedRouteSnapshot] {
        let descriptor = FetchDescriptor<SavedRoute>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let routes = try modelContext.fetch(descriptor)
        return routes.map { route in
            SavedRouteSnapshot(
                id: route.id,
                name: route.name,
                createdAt: route.createdAt,
                distanceMeters: route.distanceMeters,
                drawMode: route.drawMode
            )
        }
    }
    
    /// Accepts plain values (not @Model objects) to avoid cross-actor violations.
    func saveSavedRoute(
        name: String, drawMode: DrawMode,
        waypointsData: Data, distanceMeters: Double
    ) throws -> UUID {
        let route = SavedRoute(name: name, drawMode: drawMode, waypoints: waypointsData)
        route.distanceMeters = distanceMeters
        modelContext.insert(route)
        try modelContext.save()
        return route.id
    }
    
    /// Accepts UUID (not @Model object) to avoid cross-actor violations.
    func deleteSavedRoute(id: UUID) throws {
        let descriptor = FetchDescriptor<SavedRoute>(
            predicate: #Predicate { $0.id == id }
        )
        guard let route = try modelContext.fetch(descriptor).first else { return }
        modelContext.delete(route)
        try modelContext.save()
    }
    
    func fetchLastRunDate() throws -> Date? {
        var descriptor = FetchDescriptor<CompletedRun>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first?.date
    }
    
    func updateEffortRating(runId: UUID, rating: EffortRating) throws {
        let descriptor = FetchDescriptor<CompletedRun>(
            predicate: #Predicate { $0.id == runId }
        )
        guard let run = try modelContext.fetch(descriptor).first else { return }
        run.effortRating = rating
        try modelContext.save()
    }
    
    func incrementCompletedSessions() throws {
        let descriptor = FetchDescriptor<UserProfile>()
        guard let profile = try modelContext.fetch(descriptor).first else { return }
        profile.completedSessionsThisWeek += 1
        profile.updatedAt = Date()
        try modelContext.save()
    }
}
```

### 5g. RunEngine (Core Orchestrator)

```swift
import Foundation
import CoreLocation
import Observation

@Observable
@MainActor
final class RunEngine {
    // MARK: - Published State
    var currentInterval: Interval?
    var currentIntervalIndex: Int = 0
    var currentIntervalElapsed: TimeInterval = 0
    var currentIntervalRemaining: TimeInterval = 0
    var totalElapsed: TimeInterval = 0
    var totalDistance: Double = 0     // meters
    var currentPace: Double = 0      // seconds per km
    var isRunning: Bool = false
    var isPaused: Bool = false
    var isComplete: Bool = false
    
    // MARK: - Dependencies (injected)
    private let locationProvider: LocationProviding
    private let audioCoach: AudioCoaching
    private let sessionDefinition: SessionDefinition
    private let timeProvider: TimeProviding
    
    // MARK: - Wall-Clock Timing (NOT Timer-based)
    private var runStartTime: Date?
    private var intervalStartTime: Date?
    private var pauseStartTime: Date?
    private var totalPauseDuration: TimeInterval = 0
    
    // MARK: - GPS State
    private var locations: [CLLocation] = []
    private var lastLocation: CLLocation?
    
    // MARK: - Display Timer (UI refresh only — NOT used for interval logic)
    private var displayTimer: Timer?
    
    // MARK: - Interval Timer (DispatchSourceTimer — primary interval advancement)
    private var intervalTimer: DispatchSourceTimer?
    
    // MARK: - Re-entry guard
    private var isAdvancingInterval = false
    
    // MARK: - Callbacks
    var onRunComplete: (([CLLocation], TimeInterval, Double) -> Void)?
    var onIntervalChange: ((Interval) -> Void)?
    
    private var halfwayAnnounced = false
    
    init(sessionDefinition: SessionDefinition,
         locationProvider: LocationProviding,
         audioCoach: AudioCoaching,
         timeProvider: TimeProviding = SystemTimeProvider()) {
        self.sessionDefinition = sessionDefinition
        self.locationProvider = locationProvider
        self.audioCoach = audioCoach
        self.timeProvider = timeProvider
    }
    
    deinit {
        displayTimer?.invalidate()
        displayTimer = nil
        intervalTimer?.cancel()
        intervalTimer = nil
    }
    
    func start() throws {
        try audioCoach.configureAudioSession()
        
        let now = timeProvider.now()
        runStartTime = now
        intervalStartTime = now
        currentIntervalIndex = 0
        currentInterval = sessionDefinition.intervals[0]
        isRunning = true
        isPaused = false
        halfwayAnnounced = false
        
        // Start GPS
        locationProvider.onLocationUpdate = { [weak self] location in
            self?.handleLocationUpdate(location)
        }
        locationProvider.startUpdatingLocation()
        
        // Audio cue for first interval
        audioCoach.speak(currentInterval?.label == "Warm-Up Walk"
            ? "Start your warm-up walk"
            : "Let's go!")
        
        // Display timer: 1 Hz for UI refresh ONLY
        startDisplayTimer()
        
        // Interval timer: DispatchSourceTimer for reliable interval advancement
        scheduleIntervalTimer(durationSeconds: sessionDefinition.intervals[0].durationSeconds)
    }
    
    func pause() {
        guard isRunning, !isPaused else { return }
        isPaused = true
        pauseStartTime = timeProvider.now()
        locationProvider.stopUpdatingLocation()
        displayTimer?.invalidate()
        displayTimer = nil
        intervalTimer?.suspend()
    }
    
    func resume() {
        guard isRunning, isPaused else { return }
        if let pauseStart = pauseStartTime {
            totalPauseDuration += timeProvider.now().timeIntervalSince(pauseStart)
        }
        isPaused = false
        pauseStartTime = nil
        locationProvider.startUpdatingLocation()
        
        // Invalidate existing timer before creating new one
        displayTimer?.invalidate()
        displayTimer = nil
        startDisplayTimer()
        
        intervalTimer?.resume()
    }
    
    func skipInterval() {
        advanceToNextInterval(at: timeProvider.now())
    }
    
    func endRun() {
        completeRun()
    }
    
    // MARK: - Timer Helpers
    
    private func startDisplayTimer() {
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshDisplay()
        }
        RunLoop.main.add(timer, forMode: .common)
        displayTimer = timer
    }
    
    private func scheduleIntervalTimer(durationSeconds: Int) {
        intervalTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + .seconds(durationSeconds))
        timer.setEventHandler { [weak self] in
            // DispatchSourceTimer handler runs outside @MainActor isolation.
            // Must dispatch back to MainActor since RunEngine is @MainActor.
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.advanceToNextInterval(at: self.timeProvider.now())
            }
        }
        timer.resume()
        intervalTimer = timer
    }
    
    // MARK: - Core Logic (wall-clock based)
    
    private func handleLocationUpdate(_ location: CLLocation) {
        guard isRunning, !isPaused else { return }
        
        // Track distance
        if let last = lastLocation {
            totalDistance += location.distance(from: last)
        }
        lastLocation = location
        locations.append(location)
        
        // Update pace
        if totalDistance > 0, let start = runStartTime {
            let activeTime = location.timestamp.timeIntervalSince(start) - totalPauseDuration
            currentPace = activeTime / (totalDistance / 1000.0) // sec/km
        }
        
        // Update interval display from GPS timestamp
        checkIntervalProgress(at: location.timestamp)
    }
    
    private func checkIntervalProgress(at now: Date) {
        guard let intervalStart = intervalStartTime,
              let interval = currentInterval else { return }
        
        let elapsed = now.timeIntervalSince(intervalStart)
        currentIntervalElapsed = elapsed
        currentIntervalRemaining = max(0, Double(interval.durationSeconds) - elapsed)
        
        // Update total elapsed
        if let runStart = runStartTime {
            totalElapsed = now.timeIntervalSince(runStart) - totalPauseDuration
        }
        
        // Halfway announcement
        if !halfwayAnnounced,
           let total = totalSessionDuration,
           totalElapsed >= Double(total) / 2.0 {
            audioCoach.speak("Halfway there!")
            halfwayAnnounced = true
        }
    }
    
    private var totalSessionDuration: Int? {
        sessionDefinition.totalDurationSeconds
    }
    
    private func advanceToNextInterval(at now: Date) {
        // Re-entry guard
        guard !isAdvancingInterval else { return }
        isAdvancingInterval = true
        defer { isAdvancingInterval = false }
        
        let nextIndex = currentIntervalIndex + 1
        
        if nextIndex >= sessionDefinition.intervals.count {
            // Session complete
            completeRun()
            return
        }
        
        currentIntervalIndex = nextIndex
        let nextInterval = sessionDefinition.intervals[nextIndex]
        currentInterval = nextInterval
        intervalStartTime = now
        currentIntervalElapsed = 0
        currentIntervalRemaining = Double(nextInterval.durationSeconds)
        
        // Schedule next interval timer
        scheduleIntervalTimer(durationSeconds: nextInterval.durationSeconds)
        
        // Audio cues
        let cue = intervalAudioCue(for: nextInterval, isLast: nextIndex == sessionDefinition.intervals.count - 1)
        audioCoach.speak(cue)
        
        onIntervalChange?(nextInterval)
    }
    
    private func intervalAudioCue(for interval: Interval, isLast: Bool) -> String {
        if interval.type == .coolDown {
            return "Great work! Begin your cool-down walk."
        }
        if isLast {
            return "Last interval — finish strong!"
        }
        switch interval.type {
        case .run: return "Time to run!"
        case .walk: return "Take a walk break."
        case .warmUp: return "Start your warm-up walk."
        case .coolDown: return "Begin your cool-down walk."
        }
    }
    
    private func completeRun() {
        isRunning = false
        isComplete = true
        displayTimer?.invalidate()
        displayTimer = nil
        intervalTimer?.cancel()
        intervalTimer = nil
        locationProvider.stopUpdatingLocation()
        audioCoach.speak("You're done! Amazing work today.")
        
        let finalDuration = totalElapsed
        let finalDistance = totalDistance
        onRunComplete?(locations, finalDuration, finalDistance)
    }
    
    /// Display-only refresh — does NOT advance intervals
    private func refreshDisplay() {
        guard let runStart = runStartTime, !isPaused else { return }
        let now = timeProvider.now()
        totalElapsed = now.timeIntervalSince(runStart) - totalPauseDuration
        
        if let intervalStart = intervalStartTime, let interval = currentInterval {
            let elapsed = now.timeIntervalSince(intervalStart)
            currentIntervalElapsed = elapsed
            currentIntervalRemaining = max(0, Double(interval.durationSeconds) - elapsed)
        }
    }
}
```

### 5h. CalorieCalculator

```swift
struct CalorieCalculator {
    /// MET values for calorie estimation
    static let walkingMET: Double = 3.5
    static let runningMET: Double = 8.0
    
    /// Calculate calories for a completed run.
    /// Formula: calories = MET × weight(kg) × duration(hours)
    /// We use a weighted average MET based on run vs walk time ratio,
    /// applied to the ACTUAL duration (not planned interval durations).
    static func calculate(
        weightKg: Double,
        intervals: [Interval],
        actualDurationSeconds: Double
    ) -> Double {
        var runSeconds: Double = 0
        var walkSeconds: Double = 0
        
        for interval in intervals {
            switch interval.type {
            case .run:
                runSeconds += Double(interval.durationSeconds)
            case .walk, .warmUp, .coolDown:
                walkSeconds += Double(interval.durationSeconds)
            }
        }
        
        let totalPlanned = runSeconds + walkSeconds
        guard totalPlanned > 0 else { return 0 }
        
        // Use run/walk ratio from plan but apply to actual duration
        let runFraction = runSeconds / totalPlanned
        let walkFraction = walkSeconds / totalPlanned
        let weightedMET = (runningMET * runFraction) + (walkingMET * walkFraction)
        
        let hours = actualDurationSeconds / 3600.0
        return weightedMET * weightKg * hours
    }
}
```

---
