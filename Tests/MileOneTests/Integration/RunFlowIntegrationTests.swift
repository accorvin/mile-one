import Testing
import Foundation
import CoreLocation
@testable import MileOne

/// Integration tests covering the run start → interval progression → completion flow.
/// These tests expose the bugs that prevented the user from starting a run.
@MainActor
@Suite("Run Flow Integration Tests")
struct RunFlowIntegrationTests {

    private func makeSession() -> SessionDefinition {
        SessionDefinition(
            id: "TEST_INTEGRATION",
            week: 1,
            dayInWeek: 1,
            intervals: [
                Interval(type: .warmUp, durationSeconds: 5),
                Interval(type: .run, durationSeconds: 5),
                Interval(type: .coolDown, durationSeconds: 5)
            ]
        )
    }

    @Test("AppState exposes isShowingRun and activeSession")
    func appStateHasRunNavigationState() {
        let appState = AppState()
        #expect(appState.isShowingRun == false)
        #expect(appState.activeSession == nil)
    }

    @Test("Setting activeSession and isShowingRun prepares navigation")
    func settingActiveSessionPreparesNavigation() {
        let appState = AppState()
        let session = makeSession()
        appState.activeSession = session
        appState.isShowingRun = true
        #expect(appState.isShowingRun == true)
        #expect(appState.activeSession?.id == "TEST_INTEGRATION")
    }

    @Test("RunEngine snapshot callbacks update RunViewModel")
    func engineSnapshotUpdatesViewModel() throws {
        let session = makeSession()
        let time = MockTimeProvider()
        let baseDate = Date(timeIntervalSince1970: 1_000_000)
        time.currentTime = baseDate

        let locationProvider = MockLocationProvider()
        let audioCoach = MockAudioCoach()

        let engine = RunEngine(
            sessionDefinition: session,
            locationProvider: locationProvider,
            audioCoach: audioCoach,
            timeProvider: time
        )

        let viewModel = RunViewModel()
        engine.onSnapshot = { snapshot in
            viewModel.update(with: snapshot)
        }

        try engine.start()

        #expect(viewModel.snapshot.isRunning == true)
        #expect(viewModel.snapshot.isComplete == false)
        #expect(viewModel.snapshot.currentIntervalType == .warmUp)
    }

    @Test("Full run flow: engine drives viewModel through all intervals to completion")
    func fullRunFlowDrivesViewModelToCompletion() throws {
        let session = makeSession()
        let time = MockTimeProvider()
        let baseDate = Date(timeIntervalSince1970: 1_000_000)
        time.currentTime = baseDate

        let locationProvider = MockLocationProvider()
        let audioCoach = MockAudioCoach()

        let engine = RunEngine(
            sessionDefinition: session,
            locationProvider: locationProvider,
            audioCoach: audioCoach,
            timeProvider: time
        )

        let viewModel = RunViewModel()
        engine.onSnapshot = { snapshot in
            viewModel.update(with: snapshot)
        }

        var completionFired = false
        engine.onRunComplete = { _, _, _ in completionFired = true }

        try engine.start()
        #expect(viewModel.snapshot.isRunning == true)

        var elapsed: TimeInterval = 0
        for interval in session.intervals {
            elapsed += Double(interval.durationSeconds)
            time.currentTime = baseDate.addingTimeInterval(elapsed)
            locationProvider.simulateLocation(timestamp: baseDate.addingTimeInterval(elapsed))
        }

        #expect(completionFired == true)
        #expect(viewModel.snapshot.isComplete == true)
        #expect(viewModel.snapshot.isRunning == false)
    }

    @Test("DashboardViewModel.nextSession returns a valid session for week 1")
    func dashboardViewModelNextSessionIsNonNil() async {
        let vm = DashboardViewModel(dataStore: MockDataStore())
        await vm.loadData()

        let session = vm.nextSession
        #expect(session != nil, "nextSession must not be nil — dashboard Start button has nothing to launch")
        #expect(session?.week == 1)
        #expect(session?.dayInWeek == 1)
    }

    @Test("SessionPlanLibrary has all 27 sessions (9 weeks × 3 days)")
    func sessionPlanLibraryHasAll27Sessions() {
        #expect(SessionPlanLibrary.allSessions.count == 27)
        for week in 1...9 {
            for day in 1...3 {
                let session = SessionPlanLibrary.session(week: week, day: day)
                #expect(session != nil, "Missing session W\(week)D\(day)")
                #expect(session?.intervals.isEmpty == false, "W\(week)D\(day) has no intervals")
            }
        }
    }

    @Test("Pausing engine does not clear AppState.isShowingRun")
    func pauseDoesNotClearRunFlag() throws {
        let appState = AppState()
        let session = makeSession()
        let time = MockTimeProvider()
        let baseDate = Date(timeIntervalSince1970: 1_000_000)
        time.currentTime = baseDate

        let engine = RunEngine(
            sessionDefinition: session,
            locationProvider: MockLocationProvider(),
            audioCoach: MockAudioCoach(),
            timeProvider: time
        )

        appState.activeSession = session
        appState.isShowingRun = true

        try engine.start()
        engine.pause()

        #expect(appState.isShowingRun == true, "Pausing the run must not dismiss the run screen")
        #expect(engine.isPaused == true)
    }

    @Test("onRunComplete callback can clear AppState.isShowingRun")
    func onRunCompleteCanClearRunState() throws {
        let appState = AppState()
        let session = makeSession()
        let time = MockTimeProvider()
        let baseDate = Date(timeIntervalSince1970: 1_000_000)
        time.currentTime = baseDate

        let locationProvider = MockLocationProvider()
        let engine = RunEngine(
            sessionDefinition: session,
            locationProvider: locationProvider,
            audioCoach: MockAudioCoach(),
            timeProvider: time
        )

        engine.onRunComplete = { _, _, _ in
            appState.isShowingRun = false
        }

        appState.isShowingRun = true
        try engine.start()

        var elapsed: TimeInterval = 0
        for interval in session.intervals {
            elapsed += Double(interval.durationSeconds)
            time.currentTime = baseDate.addingTimeInterval(elapsed)
            locationProvider.simulateLocation(timestamp: baseDate.addingTimeInterval(elapsed))
        }

        #expect(appState.isShowingRun == false, "Run screen must dismiss after completion")
    }
}
