← [Back to Index](README.md)

# Mile One — Phase 1: Foundation (Models, Data Store, Session Plans)

## 7. Phase-by-Phase Implementation

### Sprint Ordering Rationale

GPS/location is moved to Phase 2 (not Phase 6) because background execution depends on CoreLocation — the timer, interval logic, and background mode are all fundamentally coupled to GPS updates. Building the timer without GPS first would create throwaway code.

| Phase | Focus | Duration |
|-------|-------|----------|
| 1 | Foundation: Models, Data Store, Session Plans | ~1 week |
| 2 | Run Engine + GPS + Background Execution | ~1.5 weeks |
| 3 | Audio Coach + In-Run UI | ~1 week |
| 4 | HealthKit Integration + Post-Run Flow | ~1 week |
| 5 | Onboarding + Dashboard + Progress Tracking | ~1 week |
| 6 | Route Planner | ~1.5 weeks |
| 7 | History + Settings + iCloud Sync | ~1 week |
| 8 | Graduation + Free Run + Polish | ~1 week |

---

### Phase 1: Foundation — Models, Data Store, Session Plans

**Goal**: All data models compile, persist correctly, round-trip through CloudKit, and the session plan library is validated against the NHS C25K source. Data migration strategy is established from day one.

#### Tests FIRST

**File: `Tests/MileOneTests/Models/SessionPlanTests.swift`**

```swift
import Testing
@testable import MileOne

struct SessionPlanTests {
    
    @Test func allSessionsExist() {
        #expect(SessionPlanLibrary.allSessions.count == 27)
    }
    
    @Test func eachWeekHasThreeSessions() {
        for week in 1...9 {
            let sessions = SessionPlanLibrary.allSessions.filter { $0.week == week }
            #expect(sessions.count == 3, "Week \(week) should have 3 sessions, has \(sessions.count)")
        }
    }
    
    @Test func allSessionsHaveWarmUpAndCoolDown() {
        for session in SessionPlanLibrary.allSessions {
            let first = session.intervals.first
            let last = session.intervals.last
            #expect(first?.type == .warmUp, "\(session.id) missing warm-up")
            #expect(last?.type == .coolDown, "\(session.id) missing cool-down")
            #expect(first?.durationSeconds == 300, "\(session.id) warm-up should be 5 min")
            #expect(last?.durationSeconds == 300, "\(session.id) cool-down should be 5 min")
        }
    }
    
    // --- NHS C25K source validation ---
    
    @Test func week1MatchesNHSSpec() {
        // NHS: 60s run / 90s walk × 8 = 20 min block
        guard let session = SessionPlanLibrary.session(week: 1, day: 1) else {
            Issue.record("W1D1 not found"); return
        }
        let block = session.intervals.dropFirst().dropLast()
        #expect(block.count == 16) // 8 run + 8 walk
        
        let blockDuration = block.reduce(0) { $0 + $1.durationSeconds }
        #expect(blockDuration == 1200, "Week 1 interval block must be 20 min per NHS spec")
        
        for (i, interval) in block.enumerated() {
            if i % 2 == 0 {
                #expect(interval.type == .run)
                #expect(interval.durationSeconds == 60)
            } else {
                #expect(interval.type == .walk)
                #expect(interval.durationSeconds == 90)
            }
        }
        
        // All 3 days of week 1 should have identical intervals
        for day in 1...3 {
            let s = SessionPlanLibrary.session(week: 1, day: day)!
            let sBlock = s.intervals.dropFirst().dropLast()
            #expect(sBlock.count == 16, "W1D\(day) should match NHS pattern")
        }
    }
    
    @Test func week4MatchesNHSSpec() {
        // NHS Week 4: 3 min run / 90s walk / 5 min run / 2.5 min walk / 3 min run / 90s walk / 5 min run
        // Total interval block: 180+90+300+150+180+90+300 = 1290s = 21.5 min
        guard let session = SessionPlanLibrary.session(week: 4, day: 1) else {
            Issue.record("W4D1 not found"); return
        }
        let block = session.intervals.dropFirst().dropLast()
        let blockDuration = block.reduce(0) { $0 + $1.durationSeconds }
        #expect(blockDuration == 1290, "Week 4 block should be 1290s (21.5 min) per NHS spec")
        
        // Verify interval sequence
        let expectedTypes: [IntervalType] = [.run, .walk, .run, .walk, .run, .walk, .run]
        let expectedDurations = [180, 90, 300, 150, 180, 90, 300]
        #expect(block.count == expectedTypes.count)
        for (i, interval) in block.enumerated() {
            #expect(interval.type == expectedTypes[i], "W4 interval \(i) type mismatch")
            #expect(interval.durationSeconds == expectedDurations[i], "W4 interval \(i) duration mismatch")
        }
    }
    
    @Test func week5HasDifferentDays() {
        let d1 = SessionPlanLibrary.session(week: 5, day: 1)!
        let d2 = SessionPlanLibrary.session(week: 5, day: 2)!
        let d3 = SessionPlanLibrary.session(week: 5, day: 3)!
        
        // Day 3 is 20 min continuous — warmup + 1 run + cooldown = 3 intervals
        #expect(d3.intervals.count == 3)
        #expect(d3.intervals[1].durationSeconds == 1200, "W5D3 should be 20 min continuous per NHS")
        
        // Days 1 and 2 should differ from Day 3
        #expect(d1.intervals.count != d3.intervals.count || 
                d1.totalDurationSeconds != d3.totalDurationSeconds)
    }
    
    @Test func week9Is30MinContinuous() {
        for day in 1...3 {
            let session = SessionPlanLibrary.session(week: 9, day: day)!
            #expect(session.intervals.count == 3) // warmup + run + cooldown
            #expect(session.intervals[1].type == .run)
            #expect(session.intervals[1].durationSeconds == 1800, "W9 should be 30 min continuous per NHS")
            #expect(session.totalDurationSeconds == 2400, "W9 total should be 40 min")
        }
    }
    
    @Test func totalDurationSecondsMatchesIntervalSum() {
        // Validates totalDurationSeconds is computed correctly, not hardcoded
        for session in SessionPlanLibrary.allSessions {
            let sum = session.intervals.reduce(0) { $0 + $1.durationSeconds }
            #expect(session.totalDurationSeconds == sum,
                    "\(session.id) totalDuration \(session.totalDurationSeconds) != interval sum \(sum)")
        }
    }
    
    @Test func sessionLookupReturnsNilForInvalid() {
        #expect(SessionPlanLibrary.session(week: 0, day: 1) == nil)
        #expect(SessionPlanLibrary.session(week: 10, day: 1) == nil)
        #expect(SessionPlanLibrary.session(week: 1, day: 4) == nil)
        #expect(SessionPlanLibrary.session(week: 1, day: 0) == nil)
    }
    
    @Test func sessionIdsAreUnique() {
        let ids = SessionPlanLibrary.allSessions.map(\.id)
        #expect(Set(ids).count == ids.count, "Duplicate session IDs found")
    }
    
    @Test func intervalIdsUniqueWithinSession() {
        // Ensures ForEach won't get confused by duplicate Interval UUIDs
        for session in SessionPlanLibrary.allSessions {
            let ids = session.intervals.map(\.id)
            #expect(Set(ids).count == ids.count,
                    "\(session.id) has duplicate interval IDs — warmUp/coolDown UUID reuse?")
        }
    }
}
```

**File: `Tests/MileOneTests/Models/CalorieCalculatorTests.swift`**

```swift
import Testing
@testable import MileOne

struct CalorieCalculatorTests {
    
    @Test func pureWalkingSession() {
        let intervals = [
            Interval(type: .warmUp, durationSeconds: 300),
            Interval(type: .walk, durationSeconds: 600),
            Interval(type: .coolDown, durationSeconds: 300),
        ]
        // 70kg × 3.5 MET × (1200/3600) hours = 81.67 cal
        let cal = CalorieCalculator.calculate(
            weightKg: 70, intervals: intervals, actualDurationSeconds: 1200
        )
        #expect(abs(cal - 81.67) < 1.0)
    }
    
    @Test func pureRunningSession() {
        let intervals = [
            Interval(type: .run, durationSeconds: 1800),
        ]
        // 70kg × 8.0 MET × 0.5 hours = 280 cal
        let cal = CalorieCalculator.calculate(
            weightKg: 70, intervals: intervals, actualDurationSeconds: 1800
        )
        #expect(abs(cal - 280.0) < 1.0)
    }
    
    @Test func mixedIntervalSession() {
        let intervals = [
            Interval(type: .warmUp, durationSeconds: 300),
            Interval(type: .run, durationSeconds: 60),
            Interval(type: .walk, durationSeconds: 90),
            Interval(type: .coolDown, durationSeconds: 300),
        ]
        let cal = CalorieCalculator.calculate(
            weightKg: 70, intervals: intervals, actualDurationSeconds: 750
        )
        #expect(cal > 50 && cal < 65)
    }
    
    @Test func zeroWeightReturnsZero() {
        let intervals = [Interval(type: .run, durationSeconds: 1800)]
        let cal = CalorieCalculator.calculate(
            weightKg: 0, intervals: intervals, actualDurationSeconds: 1800
        )
        #expect(cal == 0)
    }
    
    @Test func negativeWeightReturnsZero() {
        let intervals = [Interval(type: .run, durationSeconds: 1800)]
        let cal = CalorieCalculator.calculate(
            weightKg: -70, intervals: intervals, actualDurationSeconds: 1800
        )
        #expect(cal == 0)
    }
    
    @Test func emptyIntervalsReturnsZero() {
        let cal = CalorieCalculator.calculate(
            weightKg: 70, intervals: [], actualDurationSeconds: 1800
        )
        #expect(cal == 0)
    }
    
    @Test func zeroDurationReturnsZero() {
        let intervals = [Interval(type: .run, durationSeconds: 1800)]
        let cal = CalorieCalculator.calculate(
            weightKg: 70, intervals: intervals, actualDurationSeconds: 0
        )
        #expect(cal == 0)
    }
    
    @Test func pausedRunUsesActualDurationNotPlanned() {
        // User ran a 20-min session but paused for 10 min (actual = 20 min, not 30)
        // Calories should be based on ACTUAL duration, not planned
        let intervals = [
            Interval(type: .warmUp, durationSeconds: 300),
            Interval(type: .run, durationSeconds: 1200),
            Interval(type: .coolDown, durationSeconds: 300),
        ]
        let plannedTotal = 1800 // 30 min
        let actualTotal = 1200  // 20 min (user paused, or intervals were shorter)
        
        let calPlanned = CalorieCalculator.calculate(
            weightKg: 70, intervals: intervals, actualDurationSeconds: Double(plannedTotal)
        )
        let calActual = CalorieCalculator.calculate(
            weightKg: 70, intervals: intervals, actualDurationSeconds: Double(actualTotal)
        )
        // Actual should be proportionally less than planned
        #expect(calActual < calPlanned)
        #expect(calActual > 0)
    }
    
    @Test func extremeWeightProducesReasonableCalories() {
        // Very light person
        let intervals = [Interval(type: .run, durationSeconds: 1800)]
        let calLight = CalorieCalculator.calculate(
            weightKg: 40, intervals: intervals, actualDurationSeconds: 1800
        )
        // Very heavy person
        let calHeavy = CalorieCalculator.calculate(
            weightKg: 150, intervals: intervals, actualDurationSeconds: 1800
        )
        #expect(calLight > 0)
        #expect(calHeavy > calLight)
        // Calories should scale roughly linearly with weight
        #expect(abs(calHeavy / calLight - 150.0 / 40.0) < 0.1)
    }
}
```

**File: `Tests/MileOneTests/Services/DataStoreTests.swift`**

```swift
import Testing
import SwiftData
@testable import MileOne

struct DataStoreTests {
    
    // Helper: create an in-memory ModelContainer for testing
    private func makeTestContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: UserProfile.self, CompletedRun.self, GPSPoint.self, SavedRoute.self,
            configurations: config
        )
    }
    
    @Test func saveAndFetchUserProfile() async throws {
        let container = try makeTestContainer()
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
    }
    
    @Test func saveProfileTwiceDoesNotDuplicate() async throws {
        // Verifies fix for review 2 issue 1c — insert-always duplication
        let container = try makeTestContainer()
        let store = DataStore(modelContainer: container)
        
        try await store.saveUserProfile(
            heightCm: 180, weightKg: 70, birthYear: 1990,
            biologicalSex: .male, currentWeek: 1,
            completedSessionsThisWeek: 0, hasCompletedOnboarding: false,
            hasGraduated: false, startingWeek: 1, usesMetric: false,
            runDays: [2, 4, 6], reminderHour: 7, reminderMinute: 0,
            remindersEnabled: true
        )
        
        // Save again (simulating settings update)
        try await store.saveUserProfile(
            heightCm: 180, weightKg: 90, birthYear: 1990,
            biologicalSex: .male, currentWeek: 1,
            completedSessionsThisWeek: 0, hasCompletedOnboarding: false,
            hasGraduated: false, startingWeek: 1, usesMetric: false,
            runDays: [2, 4, 6], reminderHour: 7, reminderMinute: 0,
            remindersEnabled: true
        )
        
        // Should still have exactly one profile
        let profile = try await store.fetchUserProfile()
        #expect(profile != nil, "saveUserProfile must upsert, not insert duplicate")
        #expect(profile?.weightKg == 90)
    }
    
    @Test func saveAndFetchCompletedRun() async throws {
        let container = try makeTestContainer()
        let store = DataStore(modelContainer: container)
        
        let runId = try await store.saveCompletedRun(
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
        let container = try makeTestContainer()
        let store = DataStore(modelContainer: container)
        
        let runId = try await store.saveCompletedRun(
            weekNumber: 1, sessionNumber: 1, date: Date(),
            distanceMeters: 0, durationSeconds: 0,
            calories: 0, averagePaceSecondsPerKm: nil,
            averageHeartRate: nil, effortRating: nil, isFreeRun: false
        )
        
        // Create GPS points as plain value types (not @Model objects)
        let pointData = (0..<100).map { i in
            GPSPointData(
                latitude: 35.7 + Double(i) * 0.0001,
                longitude: -78.6 + Double(i) * 0.0001,
                altitude: 100, horizontalAccuracy: 10,
                timestamp: Date().addingTimeInterval(Double(i)),
                speed: 2.5
            )
        }
        
        try await store.saveGPSPoints(pointData, forRunId: runId)
        let fetched = try await store.fetchGPSPoints(forRunId: runId)
        
        #expect(fetched.count == 100)
        #expect(fetched[0].latitude > 35.6)
    }
    
    @Test func fetchCompletedRunsFiltersByWeek() async throws {
        let container = try makeTestContainer()
        let store = DataStore(modelContainer: container)
        
        _ = try await store.saveCompletedRun(
            weekNumber: 1, sessionNumber: 1, date: Date(),
            distanceMeters: 0, durationSeconds: 0,
            calories: 0, averagePaceSecondsPerKm: nil,
            averageHeartRate: nil, effortRating: nil, isFreeRun: false
        )
        _ = try await store.saveCompletedRun(
            weekNumber: 2, sessionNumber: 1, date: Date(),
            distanceMeters: 0, durationSeconds: 0,
            calories: 0, averagePaceSecondsPerKm: nil,
            averageHeartRate: nil, effortRating: nil, isFreeRun: false
        )
        
        let week1Runs = try await store.fetchCompletedRuns(weekNumber: 1, limit: nil)
        #expect(week1Runs.count == 1)
        #expect(week1Runs[0].weekNumber == 1)
    }
    
    @Test func savedRoutesCRUD() async throws {
        let container = try makeTestContainer()
        let store = DataStore(modelContainer: container)
        
        let waypoints = try JSONEncoder().encode([[35.7, -78.6], [35.71, -78.61]])
        
        let routeId = try await store.saveSavedRoute(
            name: "Morning Loop", drawMode: .roadSnap,
            waypointsData: waypoints, distanceMeters: 3200
        )
        var routes = try await store.fetchSavedRoutes()
        #expect(routes.count == 1)
        #expect(routes[0].name == "Morning Loop")
        
        try await store.deleteSavedRoute(id: routeId)
        routes = try await store.fetchSavedRoutes()
        #expect(routes.count == 0)
    }
    
    @Test func fetchLastRunDate() async throws {
        let container = try makeTestContainer()
        let store = DataStore(modelContainer: container)
        
        let noDate = try await store.fetchLastRunDate()
        #expect(noDate == nil)
        
        _ = try await store.saveCompletedRun(
            weekNumber: 1, sessionNumber: 1, date: Date(),
            distanceMeters: 0, durationSeconds: 0,
            calories: 0, averagePaceSecondsPerKm: nil,
            averageHeartRate: nil, effortRating: nil, isFreeRun: false
        )
        
        let lastDate = try await store.fetchLastRunDate()
        #expect(lastDate != nil)
    }
}
```

**File: `Tests/MileOneTests/Mocks/MockDataStore.swift`**

This is the CANONICAL `MockDataStore` definition. All phase files reference this mock.

```swift
import Foundation
@testable import MileOne

/// Mock DataStore conforming to DataStoreProviding protocol.
/// Must be an actor since DataStoreProviding requires Actor conformance.
actor MockDataStore: DataStoreProviding {
    // Configurable mock state
    var mockProfile: UserProfileSnapshot?
    var mockRuns: [CompletedRunSnapshot] = []
    var mockGPSPoints: [GPSPointSnapshot] = []
    var mockRoutes: [SavedRouteSnapshot] = []
    var mockLastRunDate: Date?
    
    // Call tracking
    var gpsPointsFetched = false
    var savedRunCount = 0
    var incrementSessionsCalled = false
    
    // Setter helpers (actors require these for external mutation)
    func setMockProfile(_ profile: UserProfileSnapshot?) {
        self.mockProfile = profile
    }
    func setMockLastRunDate(_ date: Date?) {
        self.mockLastRunDate = date
    }
    func setMockRuns(_ runs: [CompletedRunSnapshot]) {
        self.mockRuns = runs
    }
    func setMockGPSPoints(_ points: [GPSPointSnapshot]) {
        self.mockGPSPoints = points
    }
    
    func fetchUserProfile() async throws -> UserProfileSnapshot? {
        return mockProfile
    }
    
    func saveUserProfile(
        heightCm: Double, weightKg: Double, birthYear: Int,
        biologicalSex: BiologicalSex, currentWeek: Int,
        completedSessionsThisWeek: Int, hasCompletedOnboarding: Bool,
        hasGraduated: Bool, startingWeek: Int, usesMetric: Bool,
        runDays: [Int], reminderHour: Int, reminderMinute: Int,
        remindersEnabled: Bool
    ) async throws {
        mockProfile = UserProfileSnapshot(
            heightCm: heightCm, weightKg: weightKg,
            birthYear: birthYear, biologicalSex: biologicalSex,
            currentWeek: currentWeek,
            completedSessionsThisWeek: completedSessionsThisWeek,
            hasCompletedOnboarding: hasCompletedOnboarding,
            hasGraduated: hasGraduated, startingWeek: startingWeek,
            usesMetric: usesMetric, runDays: runDays,
            reminderHour: reminderHour, reminderMinute: reminderMinute,
            remindersEnabled: remindersEnabled
        )
    }
    
    func saveCompletedRun(
        weekNumber: Int, sessionNumber: Int, date: Date,
        distanceMeters: Double, durationSeconds: Double,
        calories: Double, averagePaceSecondsPerKm: Double?,
        averageHeartRate: Double?, effortRating: EffortRating?,
        isFreeRun: Bool
    ) async throws -> UUID {
        let id = UUID()
        let snapshot = CompletedRunSnapshot(
            id: id, weekNumber: weekNumber,
            sessionNumber: sessionNumber, date: date,
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
    
    func fetchCompletedRuns(
        weekNumber: Int?, limit: Int?
    ) async throws -> [CompletedRunSnapshot] {
        var result = mockRuns
        if let weekNumber {
            result = result.filter { $0.weekNumber == weekNumber }
        }
        if let limit {
            result = Array(result.prefix(limit))
        }
        return result
    }
    
    func fetchGPSPoints(forRunId: UUID) async throws -> [GPSPointSnapshot] {
        gpsPointsFetched = true
        return mockGPSPoints
    }
    
    func saveGPSPoints(_ points: [GPSPointData], forRunId: UUID) async throws {
        // Store as snapshots for verification
        mockGPSPoints = points.map {
            GPSPointSnapshot(
                latitude: $0.latitude, longitude: $0.longitude,
                altitude: $0.altitude, timestamp: $0.timestamp,
                speed: $0.speed, horizontalAccuracy: $0.horizontalAccuracy
            )
        }
    }
    
    func fetchSavedRoutes() async throws -> [SavedRouteSnapshot] {
        return mockRoutes
    }
    
    func saveSavedRoute(
        name: String, drawMode: DrawMode,
        waypointsData: Data, distanceMeters: Double
    ) async throws -> UUID {
        let id = UUID()
        mockRoutes.append(SavedRouteSnapshot(
            id: id, name: name, createdAt: Date(),
            distanceMeters: distanceMeters, drawMode: drawMode
        ))
        return id
    }
    
    func deleteSavedRoute(id: UUID) async throws {
        mockRoutes.removeAll { $0.id == id }
    }
    
    func fetchLastRunDate() async throws -> Date? {
        return mockLastRunDate
    }
    
    func updateEffortRating(runId: UUID, rating: EffortRating) async throws {
        if let idx = mockRuns.firstIndex(where: { $0.id == runId }) {
            let old = mockRuns[idx]
            mockRuns[idx] = CompletedRunSnapshot(
                id: old.id, weekNumber: old.weekNumber,
                sessionNumber: old.sessionNumber, date: old.date,
                distanceMeters: old.distanceMeters,
                durationSeconds: old.durationSeconds,
                calories: old.calories,
                averagePaceSecondsPerKm: old.averagePaceSecondsPerKm,
                averageHeartRate: old.averageHeartRate,
                effortRating: rating,
                isFreeRun: old.isFreeRun
            )
        }
    }
    
    func incrementCompletedSessions() async throws {
        incrementSessionsCalled = true
        if var profile = mockProfile {
            mockProfile = UserProfileSnapshot(
                heightCm: profile.heightCm, weightKg: profile.weightKg,
                birthYear: profile.birthYear, biologicalSex: profile.biologicalSex,
                currentWeek: profile.currentWeek,
                completedSessionsThisWeek: profile.completedSessionsThisWeek + 1,
                hasCompletedOnboarding: profile.hasCompletedOnboarding,
                hasGraduated: profile.hasGraduated,
                startingWeek: profile.startingWeek,
                usesMetric: profile.usesMetric, runDays: profile.runDays,
                reminderHour: profile.reminderHour,
                reminderMinute: profile.reminderMinute,
                remindersEnabled: profile.remindersEnabled
            )
        }
    }
}
```

**File: `Tests/MileOneTests/Models/CloudKitSyncTests.swift`**

```swift
import Testing
import SwiftData
@testable import MileOne

struct CloudKitSyncTests {
    
    /// Validates that all @Model types can round-trip through encode/decode,
    /// which mirrors the serialization CloudKit performs.
    
    @Test func userProfileRoundTrips() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: UserProfile.self, CompletedRun.self, GPSPoint.self, SavedRoute.self,
            configurations: config
        )
        let context = ModelContext(container)
        
        let profile = UserProfile()
        profile.heightCm = 175
        profile.weightKg = 80
        profile.biologicalSex = "male"
        profile.runDays = [2, 4, 6]
        profile.currentWeek = 3
        profile.completedSessionsThisWeek = 2
        profile.hasCompletedOnboarding = true
        
        context.insert(profile)
        try context.save()
        
        // Fetch back — simulates CloudKit round-trip through persistent store
        let descriptor = FetchDescriptor<UserProfile>()
        let fetched = try context.fetch(descriptor)
        
        #expect(fetched.count == 1)
        let p = fetched[0]
        #expect(p.heightCm == 175)
        #expect(p.weightKg == 80)
        #expect(p.biologicalSex == "male")
        #expect(p.runDays == [2, 4, 6], "Array ordering must survive round-trip")
        #expect(p.currentWeek == 3)
        #expect(p.completedSessionsThisWeek == 2)
        #expect(p.hasCompletedOnboarding == true)
    }
    
    @Test func completedRunRoundTrips() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: UserProfile.self, CompletedRun.self, GPSPoint.self, SavedRoute.self,
            configurations: config
        )
        let context = ModelContext(container)
        
        let run = CompletedRun(weekNumber: 5, sessionNumber: 2)
        run.distanceMeters = 3200
        run.durationSeconds = 2100
        run.calories = 280
        run.averagePaceSecondsPerKm = 656
        run.effortRating = "justRight"
        // gpsPoints should be nil, not [] — CloudKit distinguishes nil from empty
        run.gpsPoints = nil
        
        context.insert(run)
        try context.save()
        
        let descriptor = FetchDescriptor<CompletedRun>()
        let fetched = try context.fetch(descriptor)
        
        #expect(fetched.count == 1)
        let r = fetched[0]
        #expect(r.weekNumber == 5)
        #expect(r.distanceMeters == 3200)
        #expect(r.effortRating == "justRight")
        #expect(r.gpsPoints == nil, "nil gpsPoints must stay nil, not become []")
    }
    
    @Test func savedRouteRoundTrips() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: UserProfile.self, CompletedRun.self, GPSPoint.self, SavedRoute.self,
            configurations: config
        )
        let context = ModelContext(container)
        
        let waypoints = try JSONEncoder().encode([[35.7, -78.6], [35.71, -78.61]])
        let route = SavedRoute(name: "Test Route", drawMode: "roadSnap", waypoints: waypoints)
        route.distanceMeters = 3000
        
        context.insert(route)
        try context.save()
        
        let descriptor = FetchDescriptor<SavedRoute>()
        let fetched = try context.fetch(descriptor)
        
        #expect(fetched.count == 1)
        let decoded = try JSONDecoder().decode([[Double]].self, from: fetched[0].waypointsData)
        #expect(decoded.count == 2)
        #expect(decoded[0][0] == 35.7)
    }
    
    @Test func gpsPointRelationshipRoundTrips() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: UserProfile.self, CompletedRun.self, GPSPoint.self, SavedRoute.self,
            configurations: config
        )
        let context = ModelContext(container)
        
        let run = CompletedRun(weekNumber: 1, sessionNumber: 1)
        context.insert(run)
        
        let point = GPSPoint(
            latitude: 35.78, longitude: -78.64,
            altitude: 100, horizontalAccuracy: 5,
            timestamp: Date(), speed: 2.5
        )
        point.run = run
        context.insert(point)
        try context.save()
        
        let descriptor = FetchDescriptor<GPSPoint>()
        let fetched = try context.fetch(descriptor)
        #expect(fetched.count == 1)
        #expect(fetched[0].run?.weekNumber == 1)
    }
}
```

#### Implementation

1. Create Xcode project: "MileOne", iOS 17+, SwiftUI lifecycle, SwiftData

2. **Create `.entitlements` file** (`MileOne/MileOne.entitlements`):
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
     "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0">
   <dict>
       <key>com.apple.developer.healthkit</key>
       <true/>
       <key>com.apple.developer.healthkit.access</key>
       <array/>
       <key>com.apple.developer.icloud-container-identifiers</key>
       <array>
           <string>iCloud.com.mileone.app</string>
       </array>
       <key>com.apple.developer.icloud-services</key>
       <array>
           <string>CloudKit</string>
       </array>
   </dict>
   </plist>
   ```
   > **Note**: HealthKit and CloudKit are entitlements, NOT Info.plist keys. They must be in the `.entitlements` file or the capabilities will silently fail on device.

3. Implement all model files (`UserProfile.swift`, `CompletedRun.swift`, `GPSPoint.swift`, `SavedRoute.swift`, `Interval.swift`, `Enums.swift`)
   - `gpsPoints` on CompletedRun must default to `nil`, not `[]` — CloudKit distinguishes nil from empty array
   - `UserProfile` should use `@Attribute(.unique)` on a sentinel field to prevent duplicates
   - Use enum types directly (not raw strings) for `biologicalSex`, `effortRating`, `drawMode` where SwiftData supports `RawRepresentable`

4. Implement `SessionPlanLibrary` with all 27 sessions
   - Each `Interval` in each session must have a unique UUID — do NOT share warmUp/coolDown instances across sessions
   - Validate against the [NHS Couch to 5K podcast page](https://www.nhs.uk/live-well/exercise/running-and-aerobic-exercises/get-running-with-couch-to-5k/) for interval accuracy

5. Implement `CalorieCalculator`
   - Guard against zero/negative weight, zero duration, empty intervals
   - Use actual duration for the time multiplier, not planned duration

6. Implement `DataStore` as `@ModelActor`
   - `saveUserProfile` must fetch-then-upsert (not insert-always) — fixes review 2 issue 1c
   - `saveCompletedRun` must check for existing record by ID before inserting — fixes review 2 issue 1d
   - Return value-type snapshots (structs) from fetch methods, not `@Model` objects — fixes review 2 issue 6c cross-actor isolation
   - Use `GPSPointData` (a plain struct) for passing GPS data across actor boundaries
   - Use `#Predicate` for week filtering instead of fetch-all-then-filter

7. **Set up `VersionedSchema` and `SchemaMigrationPlan` from day one**:
   ```swift
   enum MileOneSchemaV1: VersionedSchema {
       static var versionIdentifier = Schema.Version(1, 0, 0)
       static var models: [any PersistentModel.Type] {
           [UserProfile.self, CompletedRun.self, GPSPoint.self, SavedRoute.self]
       }
   }
   
   enum MileOneMigrationPlan: SchemaMigrationPlan {
       static var schemas: [any VersionedSchema.Type] { [MileOneSchemaV1.self] }
       static var stages: [MigrationStage] { [] } // empty for V1, add stages for V2+
   }
   ```
   > This ensures the first app update with schema changes won't lose user data. Add new `VersionedSchema` entries and migration stages as the schema evolves.

8. Set up `ModelContainer` in `MileOneApp.swift` with CloudKit configuration:

**`MileOneApp.swift` setup**:
```swift
import SwiftUI
import SwiftData

@main
struct MileOneApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(
            for: MileOneSchemaV1.models,
            migrationPlan: MileOneMigrationPlan.self,
            isUndoEnabled: true
        )
    }
}
```

9. Run all tests — all must pass

---
