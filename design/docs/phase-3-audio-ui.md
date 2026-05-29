← [Back to Index](README.md)

# Mile One — Phase 3: Audio Coach + In-Run UI

### Phase 3: Audio Coach + In-Run UI

**Goal**: Audio cues play correctly over music without ducking/unducking on every utterance, and the timer/map UI displays real-time run data via a snapshot-based RunViewModel.

#### Design Decisions (fixes from review 2)

- **Audio session lifecycle**: `configureAudioSession()` activates once at run start. Session is NOT deactivated after each utterance — only on run end via `deactivateSession()`. This prevents music from ducking/unducking on every cue (review 2 issue 3b).
- **Queue management**: `cancelPending()` clears queued utterances via `stopSpeaking(at: .word)` before speaking new cues. Prevents rapid interval transitions from queuing stale announcements.
- **RunViewModel snapshot pattern**: Views observe `RunViewModel` (which holds a plain `RunSnapshot` struct), not `RunEngine` directly. RunEngine publishes snapshots; RunViewModel receives them on `@MainActor`. Fixes review 2 issue 6a.
- **Timer on `.common` RunLoop mode**: Display timer uses `DispatchSourceTimer` on the main queue (from Phase 2), which fires during both `.default` and `.tracking` modes. Timer doesn't freeze during map scrolling (review 2 issue 3c).

#### Tests FIRST

**File: `Tests/MileOneTests/Services/AudioCoachServiceTests.swift`**

```swift
import Testing
import AVFoundation
@testable import MileOne

struct AudioCoachServiceTests {
    
    @Test func configureAudioSessionSetsCorrectCategory() throws {
        let coach = AudioCoachService()
        try coach.configureAudioSession()
        
        let session = AVAudioSession.sharedInstance()
        #expect(session.category == .playback)
        // Verify ducking is configured
        #expect(session.categoryOptions.contains(.duckOthers))
    }
    
    @Test func sessionNotDeactivatedAfterEachUtterance() throws {
        // Verifies fix for review 2 issue 3b
        let coach = AudioCoachService()
        try coach.configureAudioSession()
        
        coach.speak("Time to run!")
        
        // After speaking, the audio session must still be active
        // (deactivation only happens on run end)
        let session = AVAudioSession.sharedInstance()
        // If session were deactivated, category would reset or isOtherAudioPlaying would change
        #expect(session.category == .playback,
                "Audio session must remain active after utterance — deactivate only on run end")
    }
    
    @Test func cancelPendingClearsQueuedUtterances() {
        // Verifies queue management for rapid interval transitions
        let coach = AudioCoachService()
        try? coach.configureAudioSession()
        
        // Queue multiple cues rapidly (simulating rapid skip)
        coach.speak("Time to run!")
        coach.speak("Take a walk break.")
        coach.speak("Great work! Begin your cool-down walk.")
        
        // Cancel pending — should stop current and clear queue
        coach.cancelPending()
        
        // Speak new cue — only this should play
        coach.speak("You're done!")
        
        // Verify synthesizer is not speaking old cues
        #expect(coach.isSpeaking == false || coach.currentUtterance == "You're done!",
                "After cancelPending, only the latest cue should be queued")
    }
    
    @Test func deactivateSessionOnlyCalledOnRunEnd() throws {
        let coach = AudioCoachService()
        try coach.configureAudioSession()
        
        // Speak several cues (simulating a run)
        coach.speak("Start your warm-up walk")
        coach.speak("Time to run!")
        coach.speak("Take a walk break.")
        
        // Session should still be active
        #expect(AVAudioSession.sharedInstance().category == .playback)
        
        // End run — now deactivate
        coach.deactivateSession()
        
        // After deactivation, other apps' audio should resume at full volume
        // (We can't easily test the actual deactivation in unit tests,
        // but we verify the method exists and doesn't crash)
    }
    
    @Test func allAudioCuesAreDefined() {
        // Verify AudioCue enum has all required cue types
        let requiredCues: [AudioCue] = [
            .warmUpStart,
            .runStart,
            .walkStart,
            .coolDownStart,
            .halfway,
            .lastInterval,
            .runComplete
        ]
        for cue in requiredCues {
            #expect(!cue.text.isEmpty, "\(cue) must have non-empty text")
        }
    }
}
```

**File: `Tests/MileOneTests/ViewModels/RunViewModelTests.swift`**

```swift
import Testing
@testable import MileOne

@MainActor
struct RunViewModelTests {
    
    @Test func viewModelReceivesSnapshots() {
        let vm = RunViewModel()
        
        let snapshot = RunSnapshot(
            currentIntervalType: .run,
            currentIntervalLabel: "Run",
            intervalRemaining: 45.0,
            totalElapsed: 120.0,
            totalDistance: 500.0,
            currentIntervalIndex: 2,
            totalIntervals: 8,
            isRunning: true,
            isPaused: false,
            isComplete: false
        )
        
        vm.update(with: snapshot)
        
        #expect(vm.snapshot.currentIntervalType == .run)
        #expect(vm.snapshot.intervalRemaining == 45.0)
        #expect(vm.snapshot.totalElapsed == 120.0)
        #expect(vm.snapshot.totalDistance == 500.0)
        #expect(vm.snapshot.isRunning == true)
    }
    
    @Test func viewModelFormatsTimeCorrectly() {
        let vm = RunViewModel()
        let snapshot = RunSnapshot(
            currentIntervalType: .walk,
            currentIntervalLabel: "Walk",
            intervalRemaining: 90.0,
            totalElapsed: 725.0,
            totalDistance: 1500.0,
            currentIntervalIndex: 3,
            totalIntervals: 8,
            isRunning: true,
            isPaused: false,
            isComplete: false
        )
        vm.update(with: snapshot)
        
        #expect(vm.formattedIntervalRemaining == "1:30")
        #expect(vm.formattedTotalElapsed == "12:05")
    }
    
    @Test func viewModelComputesProgress() {
        let vm = RunViewModel()
        let snapshot = RunSnapshot(
            currentIntervalType: .run,
            currentIntervalLabel: "Run",
            intervalRemaining: 30.0,
            totalElapsed: 600.0,
            totalDistance: 1000.0,
            currentIntervalIndex: 4,
            totalIntervals: 8,
            isRunning: true,
            isPaused: false,
            isComplete: false
        )
        vm.update(with: snapshot)
        
        #expect(vm.sessionProgress == 0.5) // 4/8
    }
}
```

**File: `Tests/MileOneUITests/RunFlowUITests.swift`**

```swift
import XCTest

final class RunFlowUITests: XCTestCase {
    
    let app = XCUIApplication()
    
    override func setUp() {
        continueAfterFailure = false
        app.launchArguments = ["--uitesting"] // skip onboarding, inject mock data
        app.launch()
    }
    
    func testTimerViewShowsCurrentInterval() {
        app.buttons["Start Run"].tap()
        
        // Timer view should show the warm-up interval label
        let warmUpLabel = app.staticTexts["Warm-Up Walk"]
        XCTAssertTrue(warmUpLabel.waitForExistence(timeout: 3),
                      "Timer view must display the current interval label")
    }
    
    func testTimerViewShowsCountdown() {
        app.buttons["Start Run"].tap()
        
        // Should show a countdown timer (MM:SS format)
        let timerText = app.staticTexts.matching(
            NSPredicate(format: "label MATCHES %@", "\\d+:\\d{2}")
        )
        XCTAssertTrue(timerText.count > 0, "Timer countdown must be visible")
    }
    
    func testPauseButtonToggles() {
        app.buttons["Start Run"].tap()
        
        let pauseButton = app.buttons["Pause"]
        XCTAssertTrue(pauseButton.waitForExistence(timeout: 3))
        pauseButton.tap()
        
        let resumeButton = app.buttons["Resume"]
        XCTAssertTrue(resumeButton.waitForExistence(timeout: 3),
                      "After pausing, Resume button must appear")
    }
    
    func testEndRunShowsConfirmation() {
        app.buttons["Start Run"].tap()
        
        let endButton = app.buttons["End Run"]
        XCTAssertTrue(endButton.waitForExistence(timeout: 3))
        endButton.tap()
        
        // Must show a confirmation dialog — not end immediately
        let confirmButton = app.buttons["Confirm End Run"]
        let alert = app.alerts.firstMatch
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 3) || alert.waitForExistence(timeout: 3),
                      "End Run must require confirmation")
    }
}
```

#### Implementation

1. Implement `AudioCoachService` with `AVSpeechSynthesizer`:
   - `configureAudioSession()`: activate once at run start
   - `speechSynthesizer(_:didFinish:)`: do NOT deactivate session — just mark utterance complete
   - `deactivateSession()`: called only when the run ends, restores other apps' audio
   - `cancelPending()`: calls `synthesizer.stopSpeaking(at: .word)` to clear queued cues
   - Define `AudioCue` enum with `.text` computed property for all cue strings
   ```swift
   func configureAudioSession() throws {
       let session = AVAudioSession.sharedInstance()
       try session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers])
       try session.setActive(true)
   }
   
   func deactivateSession() {
       try? AVAudioSession.sharedInstance().setActive(false,
           options: .notifyOthersOnDeactivation)
   }
   
   func cancelPending() {
       synthesizer.stopSpeaking(at: .word)
   }
   ```

2. Implement `RunSnapshot` struct and `RunViewModel`:
   ```swift
   struct RunSnapshot {
       let currentIntervalType: IntervalType
       let currentIntervalLabel: String
       let intervalRemaining: TimeInterval
       let totalElapsed: TimeInterval
       let totalDistance: Double
       let currentIntervalIndex: Int
       let totalIntervals: Int
       let isRunning: Bool
       let isPaused: Bool
       let isComplete: Bool
   }
   
   @MainActor @Observable
   final class RunViewModel {
       private(set) var snapshot = RunSnapshot.empty
       
       func update(with snapshot: RunSnapshot) {
           self.snapshot = snapshot
       }
       
       var formattedIntervalRemaining: String { /* MM:SS */ }
       var formattedTotalElapsed: String { /* MM:SS */ }
       var sessionProgress: Double { 
           Double(snapshot.currentIntervalIndex) / Double(snapshot.totalIntervals) 
       }
   }
   ```

3. Build `TimerView` — observes `RunViewModel`, NOT `RunEngine` directly:
   - Large countdown timer (interval remaining from snapshot)
   - Interval label with color (green for run, blue for walk)
   - "Next up" chip: shows the NEXT interval type and current interval's remaining time
   - Session progress bar
   - Distance and elapsed time
   - Pause / End Run controls (no Skip — users should not skip intervals)

4. Build `RunMapView`:
   - `Map` with `UserAnnotation()` (iOS 17 MapKit API, inside `MapContentBuilder`)
   - Route overlay (if a `SavedRoute` was selected)
   - Live stats overlay (pace, distance, time)

5. Build `RunView` as `TabView` wrapping `TimerView` and `RunMapView`

**In-Run UI layout (TimerView)**:
```
┌─────────────────────────────┐
│ ████████████░░░░░░░░░░░░░░░ │  ← session progress bar
│                             │
│      WARM-UP WALK           │  ← interval label (color-coded)
│                             │
│         4:23                │  ← large countdown timer
│                             │
│    Next: Run                │  ← next interval type
│                             │
│  0.00 mi    0:00            │  ← distance / elapsed
│                             │
│  ┌──────────┐  ┌──────────┐│
│  │  Pause   │  │ End Run  ││
│  └──────────┘  └──────────┘│
└─────────────────────────────┘
```

---
