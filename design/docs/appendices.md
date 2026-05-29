← [Back to Index](README.md)

# Mile One — Appendices

## Appendix A: Info.plist Keys

```xml
<!-- Location -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>Mile One uses your location to track your running route and calculate distance.</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Mile One needs background location access to track your run while your phone is in your pocket.</string>

<!-- HealthKit -->
<key>NSHealthShareUsageDescription</key>
<string>Mile One reads your health data to personalize calorie calculations and show heart rate during runs.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>Mile One saves your workouts, calories, and route data to Apple Health.</string>

<!-- Background Modes -->
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
</array>

<!-- Privacy Policy (required for HealthKit App Store review) -->
<key>NSPrivacyPolicyURL</key>
<string>https://TODO-ADD-PRIVACY-POLICY-URL.example.com/privacy</string>
```

## Appendix B: CloudKit Configuration

```swift
// ModelContainer setup with CloudKit:
let schema = Schema([
    UserProfile.self,
    CompletedRun.self,
    GPSPoint.self,
    SavedRoute.self,
])

let config = ModelConfiguration(
    schema: schema,
    cloudKitDatabase: .automatic  // Uses iCloud.com.mileone.app
)

let container = try ModelContainer(for: schema, configurations: [config])
```

## Appendix C: Test Coverage Summary

> **Note on test quality:** Many of the 71 tests listed below are hollow — they test
> property assignment, stdlib operations (array append, reduce), or inline arithmetic
> rather than actual app behavior. The "Effective" column estimates tests that validate
> real application logic. Hollow tests should be replaced with behavioral tests before
> shipping.

| Component | Test File | Test Count | Effective | Type | Notes |
|-----------|-----------|------------|-----------|------|-------|
| SessionPlan | `SessionPlanTests.swift` | 7 | 7 | Unit | Solid — validates interval data |
| CalorieCalculator | `CalorieCalculatorTests.swift` | 5 | 3 | Unit | 2 tests don't cover actual vs planned duration bug |
| DataStore | `DataStoreTests.swift` | 5 | 3 | Integration | Missing: duplicate-on-save, cross-context |
| RunEngine | `RunEngineTests.swift` | 11 | 6 | Unit (mocked) | Pause test is boolean-only; no timer leak test |
| AudioCoach | `AudioCoachServiceTests.swift` | 3 | 1 | Unit | 2 tests are no-ops (non-empty string, no-crash) |
| HealthKit | `HealthKitServiceTests.swift` | 3 | 1 | Unit + Doc | 1 is `#expect(true)`, 1 is arithmetic |
| RouteService | `RouteServiceTests.swift` | 3 | 1 | Integration | 1 makes real API calls, 1 tests nothing |
| Dashboard VM | `DashboardViewModelTests.swift` | 7 | 0 | Unit | All test inline math, no actual ViewModel |
| RoutePlanner VM | `RoutePlannerViewModelTests.swift` | 6 | 0 | Unit | All test array ops / arithmetic |
| History VM | `HistoryViewModelTests.swift` | 3 | 0 | Unit | Tests stdlib grouping/reduce |
| PostRun | `PostRunFlowTests.swift` | 4 | 0 | Unit | Tests property assignment only |
| Graduation | `GraduationTests.swift` | 5 | 0 | Unit | Tests property assignment only |
| Onboarding UI | `OnboardingUITests.swift` | 5 | 2 | UI | 3 have empty bodies |
| Run Flow UI | `RunFlowUITests.swift` | 4 | 2 | UI | 1 asserts nothing, 1 has weak OR assertion |
| **Total** | | **71** | **~26** | | |

## Appendix D: Entitlements File

The `.entitlements` file is required for HealthKit, CloudKit, and background modes to function on device. Without it, these capabilities silently fail and App Store review will reject.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- HealthKit -->
    <key>com.apple.developer.healthkit</key>
    <true/>
    <key>com.apple.developer.healthkit.access</key>
    <array/>

    <!-- iCloud / CloudKit -->
    <key>com.apple.developer.icloud-services</key>
    <array>
        <string>CloudKit</string>
    </array>
    <key>com.apple.developer.icloud-container-identifiers</key>
    <array>
        <string>iCloud.com.mileone.app</string>
    </array>
    <key>com.apple.developer.icloud-container-environment</key>
    <string>Production</string>

    <!-- Background Modes -->
    <key>com.apple.developer.background-modes</key>
    <array>
        <string>location</string>
    </array>
</dict>
</plist>
```

> **Note**: The `com.apple.developer.healthkit` and `com.apple.developer.healthkit.access`
> keys are *entitlements*, not Info.plist keys. They must appear in the `.entitlements` file
> (configured via Xcode's Signing & Capabilities tab), not in Info.plist. Placing them in
> Info.plist has no effect — HealthKit calls will silently fail on device.

---

*End of technical implementation plan. This document is the single source of truth for building Mile One.*
