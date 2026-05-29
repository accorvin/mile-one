← [Back to Index](README.md)

# Mile One — Phase 7: History + Settings + iCloud Sync

### Phase 7: History + Settings + iCloud Sync

**Goal**: Users can view past runs in calendar/list format, adjust settings, and data syncs via iCloud.

#### Design Decisions (fixes from review 2)

- **iCloud sync is a first-launch-only setting**: Instead of a runtime toggle that "requires app restart" (review 2 issue 4c), the iCloud sync preference is set during onboarding or first launch. The `ModelContainer` is configured once at startup based on this setting. No runtime swapping of containers. If a user wants to change this later, they must reset the app (with clear documentation of what that means).
- **VersionedSchema already in place**: From Phase 1, we have `MileOneSchemaV1` and `MileOneMigrationPlan`. Phase 7 validates that CloudKit round-trips work correctly with this schema.

#### Tests FIRST

**File: `Tests/MileOneTests/ViewModels/HistoryViewModelTests.swift`**

```swift
import Testing
import Foundation
@testable import MileOne

@MainActor
struct HistoryViewModelTests {
    
    @Test func runsGroupedByMonth() async throws {
        let mockStore = MockDataStore()
        // MockDataStore is an actor; use setter methods
        await mockStore.setMockRuns([
            makeRun(week: 1, session: 1, date: makeDate(2026, 5, 1)),
            makeRun(week: 1, session: 2, date: makeDate(2026, 5, 15)),
            makeRun(week: 2, session: 1, date: makeDate(2026, 6, 1)),
        ])
        
        let vm = HistoryViewModel(dataStore: mockStore)
        await vm.loadRuns()
        
        #expect(vm.groupedRuns.count == 2, "Should group into May and June")
        
        // May should have 2 runs
        let mayKey = vm.groupedRuns.keys.first { key in
            Calendar.current.component(.month, from: key) == 5
        }
        #expect(vm.groupedRuns[mayKey!]?.count == 2)
    }
    
    @Test func lifetimeStatsAccumulate() async throws {
        let mockStore = MockDataStore()
        await mockStore.setMockRuns([
            makeRun(distance: 2500, duration: 1800, calories: 200),
            makeRun(distance: 3000, duration: 2100, calories: 250),
            makeRun(distance: 2800, duration: 1950, calories: 220),
        ])
        
        let vm = HistoryViewModel(dataStore: mockStore)
        await vm.loadRuns()
        
        #expect(vm.lifetimeStats.totalDistance == 8300)
        #expect(vm.lifetimeStats.totalDuration == 5850)
        #expect(vm.lifetimeStats.totalCalories == 670)
        #expect(vm.lifetimeStats.totalRuns == 3)
    }
    
    @Test func emptyHistoryShowsZeroStats() async throws {
        let mockStore = MockDataStore()
        await mockStore.setMockRuns([])
        
        let vm = HistoryViewModel(dataStore: mockStore)
        await vm.loadRuns()
        
        #expect(vm.lifetimeStats.totalRuns == 0)
        #expect(vm.lifetimeStats.totalDistance == 0)
        #expect(vm.groupedRuns.isEmpty)
    }
    
    @Test func gpsPointsFetchedOnDetailLoad() async throws {
        // GPS points should NOT be loaded when showing the list —
        // only when the user taps into RunDetailView
        let mockStore = MockDataStore()
        let run = makeRun(week: 1, session: 1)
        await mockStore.setMockRuns([run])
        await mockStore.setMockGPSPoints([
            GPSPointSnapshot(latitude: 35.78, longitude: -78.64, altitude: 100,
                             timestamp: Date(), speed: 2.5, horizontalAccuracy: 5)
        ])
        
        let vm = HistoryViewModel(dataStore: mockStore)
        await vm.loadRuns()
        
        // List load should not fetch GPS points
        let gpsFetched = await mockStore.gpsPointsFetched
        #expect(gpsFetched == false, "GPS points must not be fetched for list view")
        
        // Detail load should fetch GPS points
        await vm.loadGPSPoints(forRunId: run.id)
        let gpsFetchedAfter = await mockStore.gpsPointsFetched
        #expect(gpsFetchedAfter == true)
    }
    
    // Helpers
    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
    }
    
    /// Creates a CompletedRunSnapshot matching the canonical definition from services.md
    private func makeRun(week: Int = 1, session: Int = 1, date: Date = Date(),
                         distance: Double = 0, duration: Double = 0, calories: Double = 0) -> CompletedRunSnapshot {
        CompletedRunSnapshot(
            id: UUID(), weekNumber: week, sessionNumber: session,
            date: date, distanceMeters: distance,
            durationSeconds: duration, calories: calories,
            averagePaceSecondsPerKm: nil, averageHeartRate: nil,
            effortRating: nil, isFreeRun: false
        )
    }
}
```

#### Implementation

1. Build `HistoryView`:
   - Calendar view (month grid, dots on days with runs)
   - List view (grouped by month, showing distance/time/effort per run)
   - Toggle between calendar and list
   - **Lazy loading**: only show run metadata in list; fetch GPS when user taps into detail

2. Build `RunDetailView`:
   - Full post-run summary (same layout as post-run screen)
   - GPS trace on map (fetched on-demand via value-type `GPSPointData`, not `@Model` objects)
   - All stats: distance, time, pace, calories, effort, heart rate

3. Build `SettingsView`:
   - Units (miles/km) toggle — defaults from `Locale.current.measurementSystem`
   - Run days picker (multi-select weekdays) — reschedules notifications on change
   - Reminder time picker — reschedules notifications on change
   - Notifications toggle
   - Starting week adjustment
   - Biometrics editing
   - iCloud sync info (shows current status, not a toggle — set at first launch)
   - About / health disclaimer (accessible anytime, not just onboarding)

4. **iCloud sync — first-launch-only configuration**:
   ```swift
   // In MileOneApp.swift:
   @main
   struct MileOneApp: App {
       var body: some Scene {
           WindowGroup {
               ContentView()
           }
           .modelContainer(Self.makeContainer())
       }
       
       static func makeContainer() -> ModelContainer {
           let useCloud = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
           
           let config: ModelConfiguration
           if useCloud {
               config = ModelConfiguration(
                   cloudKitContainerIdentifier: "iCloud.com.mileone.app"
               )
           } else {
               config = ModelConfiguration()
           }
           
           return try! ModelContainer(
               for: MileOneSchemaV1.models,
               migrationPlan: MileOneMigrationPlan.self,
               configurations: config
           )
       }
   }
   ```
   
   - During onboarding, present iCloud sync as a choice: "Sync your runs across devices?"
   - Once chosen, the preference is saved to `UserDefaults` and the container is configured on next launch
   - Settings screen shows "iCloud Sync: Enabled" or "iCloud Sync: Off (local only)" — informational, not toggleable
   - If user wants to change: Settings → "Reset iCloud Preference" → requires app data reset with confirmation dialog explaining data implications

5. **Return value-type snapshots from DataStore** for history views:
   `CompletedRunSnapshot` is defined canonically in `services.md`. See that file for the complete definition.
   Fields include: `id`, `weekNumber`, `sessionNumber`, `date`, `distanceMeters`, `durationSeconds`, `calories`, `averagePaceSecondsPerKm`, `averageHeartRate`, `effortRating`, `isFreeRun`.
   This avoids the cross-actor isolation violation (review 2 issue 6c) — no `@Model` objects cross actor boundaries.

---
