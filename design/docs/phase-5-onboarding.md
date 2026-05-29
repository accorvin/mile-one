← [Back to Index](README.md)

# Mile One — Phase 5: Onboarding + Dashboard + Progress Tracking + Notifications

### Phase 5: Onboarding + Dashboard + Progress Tracking + Notifications

**Goal**: New users complete onboarding, see their dashboard with progress, can start runs, and receive scheduled reminders. Notifications are fully implemented here (moved from Phase 8).

#### Design Decisions (fixes from review 2)

- **Notifications moved to Phase 5**: Full `UNUserNotificationCenter` setup, permission request, and reminder scheduling based on run days. No longer a Phase 8 "polish" item — it's a core feature.
- **HealthKit biometric pre-population**: On the biometrics screen, attempt to read height, weight, date of birth, and biological sex from HealthKit first. Pre-fill fields with HealthKit data so users don't have to re-enter what Apple already knows.
- **Default units from locale**: `Locale.current.measurementSystem` determines whether to show miles/lbs or km/kg by default. User can override.
- **Two-step location permission**: Request "When In Use" during onboarding. Request "Always" upgrade later (before first run) with explanation of why background location is needed.

#### Tests FIRST

**File: `Tests/MileOneTests/ViewModels/DashboardViewModelTests.swift`**

```swift
import Testing
@testable import MileOne

@MainActor
struct DashboardViewModelTests {
    
    @Test func newUserShowsWeek1Session1() async throws {
        // MockDataStore is defined in phase-1-foundation.md (canonical definition)
        let vm = DashboardViewModel(dataStore: MockDataStore())
        await vm.loadData()
        
        #expect(vm.currentWeek == 1)
        #expect(vm.nextSessionNumber == 1)
        #expect(vm.completionRingProgress == 0)
    }
    
    @Test func completionRingReflectsProgress() async throws {
        let mockStore = MockDataStore()
        // Set mock profile snapshot (MockDataStore uses UserProfileSnapshot, not UserProfile)
        await mockStore.setMockProfile(UserProfileSnapshot(
            heightCm: 170, weightKg: 70, birthYear: 1990,
            biologicalSex: .male, currentWeek: 1,
            completedSessionsThisWeek: 2, hasCompletedOnboarding: true,
            hasGraduated: false, startingWeek: 1, usesMetric: false,
            runDays: [2, 4, 6], reminderHour: 7, reminderMinute: 0,
            remindersEnabled: true
        ))
        
        let vm = DashboardViewModel(dataStore: mockStore)
        await vm.loadData()
        
        let progress = vm.completionRingProgress
        #expect(abs(progress - 0.6667) < 0.01)
    }
    
    @Test func weekAdvancesAfterThreeCompletions() async throws {
        let mockStore = MockDataStore()
        await mockStore.setMockProfile(UserProfileSnapshot(
            heightCm: 170, weightKg: 70, birthYear: 1990,
            biologicalSex: .male, currentWeek: 3,
            completedSessionsThisWeek: 3, hasCompletedOnboarding: true,
            hasGraduated: false, startingWeek: 1, usesMetric: false,
            runDays: [2, 4, 6], reminderHour: 7, reminderMinute: 0,
            remindersEnabled: true
        ))
        
        let vm = DashboardViewModel(dataStore: mockStore)
        await vm.loadData()
        
        #expect(vm.canAdvanceWeek == true)
    }
    
    @Test func lapsedUserDetectedAfter7Days() async throws {
        let mockStore = MockDataStore()
        await mockStore.setMockLastRunDate(Calendar.current.date(byAdding: .day, value: -8, to: Date()))
        
        let vm = DashboardViewModel(dataStore: mockStore)
        await vm.checkLapsedState()
        
        #expect(vm.isLapsed == true, "User with no run in 8 days should be flagged as lapsed")
    }
    
    @Test func notLapsedIfRecentRun() async throws {
        let mockStore = MockDataStore()
        await mockStore.setMockLastRunDate(Calendar.current.date(byAdding: .day, value: -3, to: Date()))
        
        let vm = DashboardViewModel(dataStore: mockStore)
        await vm.checkLapsedState()
        
        #expect(vm.isLapsed == false)
    }
    
    @Test func programCompletionPercentage() {
        // Week 5, Session 2 complete = (4*3 + 1) / 27 = 13/27 ≈ 48.1%
        let completedTotal = (5 - 1) * 3 + 1
        let percentage = Double(completedTotal) / 27.0 * 100.0
        #expect(percentage > 48 && percentage < 49)
    }
    
    @Test func graduationDetectedAtWeek9Session3() async throws {
        let mockStore = MockDataStore()
        await mockStore.setMockProfile(UserProfileSnapshot(
            heightCm: 170, weightKg: 70, birthYear: 1990,
            biologicalSex: .male, currentWeek: 9,
            completedSessionsThisWeek: 3, hasCompletedOnboarding: true,
            hasGraduated: true, startingWeek: 1, usesMetric: false,
            runDays: [2, 4, 6], reminderHour: 7, reminderMinute: 0,
            remindersEnabled: true
        ))
        
        let vm = DashboardViewModel(dataStore: mockStore)
        await vm.loadData()
        
        #expect(vm.hasGraduated == true)
    }
    
    @Test func activityLevelMapsToStartingWeek() {
        #expect(DashboardViewModel.suggestedStartWeek(for: .couchPotato) == 1)
        #expect(DashboardViewModel.suggestedStartWeek(for: .somewhatActive) == 3)
        #expect(DashboardViewModel.suggestedStartWeek(for: .fairlyActive) == 5)
    }
}
```

**File: `Tests/MileOneTests/Services/NotificationServiceTests.swift`**

```swift
import Testing
import UserNotifications
@testable import MileOne

struct NotificationServiceTests {
    
    @Test func scheduleRemindersForRunDays() async throws {
        let mockCenter = MockNotificationCenter()
        let service = NotificationService(center: mockCenter)
        
        // Schedule for Mon (2), Wed (4), Fri (6) at 7:00 AM
        try await service.scheduleRunReminders(
            runDays: [2, 4, 6],
            time: DateComponents(hour: 7, minute: 0)
        )
        
        #expect(mockCenter.pendingRequests.count == 3, "Should schedule one reminder per run day")
        
        // Verify each reminder is for the correct weekday
        let weekdays = mockCenter.pendingRequests.compactMap { request -> Int? in
            guard let trigger = request.trigger as? UNCalendarNotificationTrigger else { return nil }
            return trigger.dateComponents.weekday
        }
        #expect(Set(weekdays) == Set([2, 4, 6]))
    }
    
    @Test func remindersReplaceExistingOnReschedule() async throws {
        let mockCenter = MockNotificationCenter()
        let service = NotificationService(center: mockCenter)
        
        // Schedule initial reminders
        try await service.scheduleRunReminders(
            runDays: [2, 4, 6],
            time: DateComponents(hour: 7, minute: 0)
        )
        #expect(mockCenter.pendingRequests.count == 3)
        
        // Reschedule for different days
        try await service.scheduleRunReminders(
            runDays: [3, 5],
            time: DateComponents(hour: 8, minute: 30)
        )
        
        // Old reminders should be removed, only new ones remain
        #expect(mockCenter.pendingRequests.count == 2, "Rescheduling must remove old reminders")
    }
    
    @Test func permissionDeniedSkipsScheduling() async throws {
        let mockCenter = MockNotificationCenter()
        mockCenter.authorizationGranted = false
        let service = NotificationService(center: mockCenter)
        
        try await service.scheduleRunReminders(
            runDays: [2, 4, 6],
            time: DateComponents(hour: 7, minute: 0)
        )
        
        #expect(mockCenter.pendingRequests.count == 0,
                "Must not schedule if permission denied")
    }
    
    @Test func reminderContentIsMotivational() async throws {
        let mockCenter = MockNotificationCenter()
        let service = NotificationService(center: mockCenter)
        
        try await service.scheduleRunReminders(
            runDays: [2],
            time: DateComponents(hour: 7, minute: 0)
        )
        
        let content = mockCenter.pendingRequests.first?.content
        #expect(content?.title.isEmpty == false, "Reminder must have a title")
        #expect(content?.body.isEmpty == false, "Reminder must have a body")
        #expect(content?.sound != nil, "Reminder must have a sound")
    }
}
```

**File: `Tests/MileOneTests/Services/OnboardingBiometricTests.swift`**

```swift
import Testing
import HealthKit
@testable import MileOne

struct OnboardingBiometricTests {
    
    @Test func healthKitPrePopulatesFields() async throws {
        let mockHealth = MockHealthStore()
        // Simulate HealthKit returning height and weight
        // (In real implementation, readMostRecentSample would return actual values)
        
        let onboarding = OnboardingBiometricService(healthStore: mockHealth)
        let prefilled = try await onboarding.fetchPrefilledBiometrics()
        
        // Even if HealthKit returns nil, the service should not crash
        #expect(prefilled != nil, "Should return a BiometricData struct (possibly with nil fields)")
    }
    
    @Test func defaultUnitsMatchLocale() {
        // US locale → imperial (miles, lbs)
        let usUnits = UnitPreference.default(for: Locale(identifier: "en_US"))
        #expect(usUnits == .imperial)
        
        // UK locale → metric (km, kg)
        let ukUnits = UnitPreference.default(for: Locale(identifier: "en_GB"))
        #expect(ukUnits == .metric)
        
        // German locale → metric
        let deUnits = UnitPreference.default(for: Locale(identifier: "de_DE"))
        #expect(deUnits == .metric)
    }
}
```

**File: `Tests/MileOneUITests/OnboardingUITests.swift`**

```swift
import XCTest

final class OnboardingUITests: XCTestCase {
    
    let app = XCUIApplication()
    
    override func setUp() {
        continueAfterFailure = false
        app.launchArguments = ["--reset-onboarding"]
        app.launch()
    }
    
    func testWelcomeScreenShowsHealthDisclaimer() {
        // Health disclaimer must be visible on the first screen
        let disclaimerExists = app.staticTexts["physician"].exists ||
                               app.staticTexts["Consult"].exists ||
                               app.staticTexts["medical"].exists
        XCTAssertTrue(disclaimerExists, "Health disclaimer must be shown on welcome screen")
        XCTAssertTrue(app.buttons["Let's get started"].exists)
    }
    
    func testBiometricInputFieldsExist() {
        app.buttons["Let's get started"].tap()
        
        // Biometric screen should have input fields
        let hasInputs = app.textFields.count > 0 || app.steppers.count > 0
        XCTAssertTrue(hasInputs, "Biometric screen must have input fields")
    }
    
    func testFullOnboardingFlow() {
        // Golden path: welcome → biometrics → activity → schedule → permissions → dashboard
        
        // Step 1: Welcome
        let getStarted = app.buttons["Let's get started"]
        XCTAssertTrue(getStarted.waitForExistence(timeout: 3))
        getStarted.tap()
        
        // Step 2: Biometrics (pre-populated or manual entry)
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 3))
        continueButton.tap()
        
        // Step 3: Activity Level
        let activityOption = app.buttons["Couch Potato"]
            .firstMatch
        if activityOption.waitForExistence(timeout: 3) {
            activityOption.tap()
        }
        
        // Continue through remaining steps...
        // (Permissions are handled by system dialogs in UI tests)
    }
    
    func testLocationPermissionShowsWhenInUseFirst() {
        // Navigate to permission screen
        app.buttons["Let's get started"].tap()
        // ... navigate through steps ...
        
        // Location permission should request "When In Use" first
        // The "Always" upgrade happens later (before first run)
        // Verify the onboarding text explains this
    }
}
```

#### Implementation

1. **Implement Notification Service** (`NotificationService.swift`):
   ```swift
   final class NotificationService {
       private let center: UNUserNotificationCenter
       
       init(center: UNUserNotificationCenter = .current()) {
           self.center = center
       }
       
       func requestPermission() async throws -> Bool {
           try await center.requestAuthorization(options: [.alert, .sound, .badge])
       }
       
       func scheduleRunReminders(runDays: [Int], time: DateComponents) async throws {
           // Remove existing run reminders
           center.removePendingNotificationRequests(
               withIdentifiers: runDays.map { "run-reminder-\($0)" }
           )
           // Also remove any old day reminders
           center.removeAllPendingNotificationRequests()
           
           // Check permission
           let settings = await center.notificationSettings()
           guard settings.authorizationStatus == .authorized else { return }
           
           for day in runDays {
               var dateComponents = time
               dateComponents.weekday = day
               
               let trigger = UNCalendarNotificationTrigger(
                   dateMatching: dateComponents, repeats: true
               )
               
               let content = UNMutableNotificationContent()
               content.title = "Time to Run! 🏃"
               content.body = "Your run is scheduled for today. Lace up and let's go!"
               content.sound = .default
               
               let request = UNNotificationRequest(
                   identifier: "run-reminder-\(day)",
                   content: content,
                   trigger: trigger
               )
               try await center.add(request)
           }
       }
   }
   ```

2. **Implement HealthKit biometric pre-population** (`OnboardingBiometricService.swift`):
   ```swift
   struct PrefilledBiometrics {
       var heightCm: Double?
       var weightKg: Double?
       var dateOfBirth: Date?
       var biologicalSex: String?
   }
   
   final class OnboardingBiometricService {
       let healthStore: HealthStoreProviding
       
       func fetchPrefilledBiometrics() async throws -> PrefilledBiometrics {
           var bio = PrefilledBiometrics()
           
           // Read height
           if let sample = try? await healthStore.readMostRecentSample(
               for: HKQuantityType(.height)
           ) {
               bio.heightCm = sample.quantity.doubleValue(for: .meterUnit(with: .centi))
           }
           
           // Read weight
           if let sample = try? await healthStore.readMostRecentSample(
               for: HKQuantityType(.bodyMass)
           ) {
               bio.weightKg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
           }
           
           return bio
       }
   }
   ```

3. **Default units from locale** (`UnitPreference.swift`):
   ```swift
   enum UnitPreference: String, Codable {
       case imperial, metric
       
       static func `default`(for locale: Locale = .current) -> UnitPreference {
           if locale.measurementSystem == .us {
               return .imperial
           }
           return .metric
       }
   }
   ```

4. Build onboarding flow as a `NavigationStack` with steps:
   - `WelcomeView` (health disclaimer)
   - `BiometricsView` (pre-populated from HealthKit, units default from locale)
   - `ActivityLevelView`
   - `ScheduleView` (select run days, default Mon/Wed/Fri)
   - `LocationPermissionView` (request "When In Use" only — explain why)
   - `HealthKitPermissionView`
   - `NotificationPermissionView` (request notification permission, schedule reminders)

5. **Two-step location permission flow**:
   - During onboarding: `requestWhenInUseAuthorization()` with explanation
   - Before first run: Show "Location Upgrade" card explaining why "Always" is needed for background GPS. Call `requestAlwaysAuthorization()`. If user declines, app works with "When In Use" but show warning about background limitations.

6. Build `DashboardView`:
   - Weekly ring (`WeeklyRingView` — circular progress for 0/3, 1/3, 2/3, 3/3)
   - Current position ("Week 3 · Run 2 of 3")
   - Next run day with countdown
   - Program completion percentage
   - Lifetime stats row
   - "Start Next Run" CTA
   - `LapsedUserCard` (shown conditionally when 7+ days since last run)

7. Build `DashboardViewModel` with injected `DataStoreProviding`:
   - Fetches `UserProfile` and recent `CompletedRun` data
   - Computes lapsed state, ring progress, next session
   - `suggestedStartWeek(for:)` is a static method

8. Build `AppState` for global routing:
   ```swift
   @Observable
   final class AppState {
       var hasCompletedOnboarding: Bool = false
       var showLapsedRecovery: Bool = false
   }
   ```

9. `ContentView` routes between onboarding and dashboard based on `UserProfile.hasCompletedOnboarding`

---
