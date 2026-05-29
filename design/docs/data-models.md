← [Back to Index](README.md)

# Mile One — Data Models

## 4. Data Models

### 4a. UserProfile

```swift
import SwiftData
import Foundation

@Model
final class UserProfile {
    @Attribute(.unique) var profileId: String  // always "singleton" — enforces one profile
    
    // Biometrics
    var heightCm: Double          // stored in cm, converted for display
    var weightKg: Double          // stored in kg, converted for display
    var birthYear: Int
    var biologicalSex: BiologicalSex  // .male or .female
    
    // Program Progress
    var currentWeek: Int          // 1–9, sequential program position
    var completedSessionsThisWeek: Int  // 0–3, resets when user advances week
    var programStartDate: Date?
    var hasGraduated: Bool
    var startingWeek: Int         // set at onboarding
    
    // Schedule
    // ⚠️ CloudKit does not guarantee array ordering after round-trip.
    // Always sort on read: `profile.runDays.sorted()`
    var runDays: [Int]            // weekday numbers (1=Sun, 2=Mon, ... 7=Sat)
    var reminderHour: Int         // 0–23
    var reminderMinute: Int       // 0–59
    var remindersEnabled: Bool
    
    // Preferences
    var usesMetric: Bool          // true = km, false = miles
    var iCloudSyncEnabled: Bool
    
    // Onboarding
    var hasCompletedOnboarding: Bool
    
    // Timestamps
    var createdAt: Date
    var updatedAt: Date
    
    init() {
        self.heightCm = 170
        self.weightKg = 70
        self.birthYear = 1990
        self.profileId = "singleton"
        self.biologicalSex = .male
        self.currentWeek = 1
        self.completedSessionsThisWeek = 0
        self.programStartDate = nil
        self.hasGraduated = false
        self.startingWeek = 1
        self.runDays = [2, 4, 6] // Mon, Wed, Fri default
        self.reminderHour = 7
        self.reminderMinute = 0
        self.remindersEnabled = true
        self.usesMetric = false
        self.iCloudSyncEnabled = true
        self.hasCompletedOnboarding = false
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
```

**Week tracking clarification**: 
- `currentWeek` = sequential program progress (which week's intervals to use). Controlled by user explicitly advancing.
- `completedSessionsThisWeek` = how many of the 3 required sessions the user has done for the current program week. This is NOT calendar-week based — it counts completions since the user last advanced.
- The **weekly ring** on the dashboard shows `completedSessionsThisWeek / 3`.
- When `completedSessionsThisWeek == 3`, show "Ready for Week N+1?" CTA. User taps to advance, which sets `currentWeek += 1` and `completedSessionsThisWeek = 0`.

### 4b. CompletedRun

```swift
@Model
final class CompletedRun {
    var id: UUID
    var date: Date
    var distanceMeters: Double
    var durationSeconds: Double
    var calories: Double
    var effortRating: EffortRating?  // .tooEasy, .justRight, .tooHard, or nil
    var weekNumber: Int           // which program week (1–9)
    var sessionNumber: Int        // which session in the week (1–3), 0 for free runs
    var isFreeRun: Bool           // post-graduation free runs
    var averagePaceSecondsPerKm: Double?
    var averageHeartRate: Double? // from HealthKit if available
    
    // HealthKit reference
    var healthKitWorkoutUUID: String?  // UUID string of the saved HKWorkout
    
    // Relationship — GPS points loaded lazily
    @Relationship(deleteRule: .cascade, inverse: \GPSPoint.run)
    var gpsPoints: [GPSPoint]?
    
    // Route used (if any)
    @Relationship(deleteRule: .nullify)
    var savedRoute: SavedRoute?
    
    var createdAt: Date
    
    init(weekNumber: Int, sessionNumber: Int, isFreeRun: Bool = false) {
        self.id = UUID()
        self.date = Date()
        self.distanceMeters = 0
        self.durationSeconds = 0
        self.calories = 0
        self.effortRating = nil
        self.weekNumber = weekNumber
        self.sessionNumber = sessionNumber
        self.isFreeRun = isFreeRun
        self.averagePaceSecondsPerKm = nil
        self.averageHeartRate = nil
        self.healthKitWorkoutUUID = nil
        self.gpsPoints = nil          // nil, NOT [] — CloudKit treats empty array differently from nil
        self.savedRoute = nil
        self.createdAt = Date()
    }
}
```

### 4c. GPSPoint

```swift
@Model
final class GPSPoint {
    var latitude: Double
    var longitude: Double
    var altitude: Double
    var horizontalAccuracy: Double
    var timestamp: Date
    var speedMetersPerSecond: Double
    
    // Relationship back to run
    var run: CompletedRun?
    
    init(latitude: Double, longitude: Double, altitude: Double,
         horizontalAccuracy: Double, timestamp: Date, speed: Double) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.horizontalAccuracy = horizontalAccuracy
        self.timestamp = timestamp
        self.speedMetersPerSecond = speed
    }
}
```

**Why separate model (not Data blob)**: CloudKit has a 1MB record size limit. A 30-minute run at 1Hz GPS = ~1,800 points. As a JSON blob, that's ~200KB per run — fine individually, but CloudKit syncs the entire record on any change. Separate `GPSPoint` records sync independently, stay well under limits, and enable lazy loading (don't fetch GPS when showing history list).

### 4d. SavedRoute

```swift
@Model
final class SavedRoute {
    var id: UUID
    var name: String
    var createdAt: Date
    var distanceMeters: Double
    var drawMode: DrawMode        // .roadSnap or .freeDraw
    
    // Waypoints as JSON Data (zlib-compressed for CloudKit CKAsset efficiency)
    // For roadSnap: array of {lat, lng} waypoints (the tapped points, not the full polyline)
    // For freeDraw: array of {lat, lng} points (the drawn path, simplified with Douglas-Peucker)
    @Attribute(.externalStorage)
    var waypointsData: Data
    
    // The full rendered polyline (from MKDirections for roadSnap, or the simplified freeDraw path)
    // JSON array of {lat, lng}, zlib-compressed
    @Attribute(.externalStorage)
    var polylineData: Data?
    
    init(name: String, drawMode: DrawMode, waypoints: Data) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.distanceMeters = 0
        self.drawMode = drawMode
        self.waypointsData = waypoints
        self.polylineData = nil
    }
    
    // MARK: - Zlib Compression Helpers
    
    /// Compress JSON data with zlib before storing.
    static func compress(_ data: Data) -> Data {
        return (try? (data as NSData).compressed(using: .zlib)) as Data? ?? data
    }
    
    /// Decompress zlib data when reading.
    static func decompress(_ data: Data) -> Data {
        return (try? (data as NSData).decompressed(using: .zlib)) as Data? ?? data
    }
}
```

### 4e. Enums & Value Types

```swift
// MARK: - Enums

enum IntervalType: String, Codable {
    case warmUp = "warmUp"
    case run = "run"
    case walk = "walk"
    case coolDown = "coolDown"
}

enum BiologicalSex: String, Codable {
    case male = "male"
    case female = "female"
}

enum EffortRating: String, Codable, CaseIterable {
    case tooEasy = "tooEasy"
    case justRight = "justRight"
    case tooHard = "tooHard"
    
    var label: String {
        switch self {
        case .tooEasy: return "Too Easy"
        case .justRight: return "Just Right"
        case .tooHard: return "Too Hard"
        }
    }
}

enum DrawMode: String, Codable {
    case roadSnap = "roadSnap"
    case freeDraw = "freeDraw"
}

enum ActivityLevel: String {
    case couchPotato    // → Week 1
    case somewhatActive // → Week 2–3
    case fairlyActive   // → Week 4–5
}

// MARK: - Value Types (not persisted, in-memory only)

struct Interval: Equatable, Identifiable {
    let id = UUID()
    let type: IntervalType
    let durationSeconds: Int
    
    var label: String {
        switch type {
        case .warmUp: return "Warm-Up Walk"
        case .run: return "Run"
        case .walk: return "Walk"
        case .coolDown: return "Cool-Down Walk"
        }
    }
    
    // Custom Equatable: compare type and duration only, NOT id.
    // Two intervals with the same type/duration should be equal regardless of UUID.
    static func == (lhs: Interval, rhs: Interval) -> Bool {
        lhs.type == rhs.type && lhs.durationSeconds == rhs.durationSeconds
    }
}

struct SessionDefinition: Identifiable {
    let id: String          // e.g., "W1D1"
    let week: Int
    let dayInWeek: Int      // 1, 2, or 3
    let intervals: [Interval]
    
    var totalDurationSeconds: Int {
        intervals.reduce(0) { $0 + $1.durationSeconds }
    }
}
```

---

