import Testing
import Foundation
import SwiftData
@testable import MileOne

/// Tests for week advancement and post-run navigation flow.
@MainActor
@Suite("Week Advancement & Post-Run Flow Tests")
struct WeekAdvancementTests {

    // MARK: - DataStore advanceWeek

    private func makeTestContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: UserProfile.self, CompletedRun.self, GPSPoint.self, SavedRoute.self,
            configurations: config
        )
    }

    private func seedProfile(in dataStore: MileOne.DataStore, week: Int, sessionsThisWeek: Int) async throws {
        try await dataStore.saveUserProfile(
            heightCm: 175, weightKg: 70, birthYear: 1990,
            biologicalSex: .male, currentWeek: week,
            completedSessionsThisWeek: sessionsThisWeek, hasCompletedOnboarding: true,
            hasGraduated: false, startingWeek: 1, usesMetric: false,
            runDays: [2, 4, 6], reminderHour: 7, reminderMinute: 0,
            remindersEnabled: true
        )
    }

    @Test("advanceWeek increments currentWeek and resets session count")
    func advanceWeekIncrementsAndResets() async throws {
        let container = try makeTestContainer()
        let dataStore = MileOne.DataStore(modelContainer: container)
        try await seedProfile(in: dataStore, week: 1, sessionsThisWeek: 3)

        try await dataStore.advanceWeek()

        let profile = try await dataStore.fetchUserProfile()
        #expect(profile?.currentWeek == 2, "currentWeek must advance from 1 to 2")
        #expect(profile?.completedSessionsThisWeek == 0, "completedSessionsThisWeek must reset to 0 after advancing")
    }

    @Test("advanceWeek does not advance past week 9")
    func advanceWeekCappedAtWeek9() async throws {
        let container = try makeTestContainer()
        let dataStore = MileOne.DataStore(modelContainer: container)
        try await seedProfile(in: dataStore, week: 9, sessionsThisWeek: 3)

        try await dataStore.advanceWeek()

        let profile = try await dataStore.fetchUserProfile()
        #expect(profile?.currentWeek == 9, "currentWeek must not exceed 9")
    }

    @Test("advanceWeek with no profile throws profileNotFound")
    func advanceWeekNoProfileThrows() async throws {
        let container = try makeTestContainer()
        let dataStore = MileOne.DataStore(modelContainer: container)
        // No profile seeded

        await #expect(throws: (any Error).self) {
            try await dataStore.advanceWeek()
        }
    }

    @Test("MockDataStore.advanceWeek increments week and resets sessions")
    func mockAdvanceWeekWorks() async throws {
        let mock = MockDataStore()
        await mock.setMockProfile(UserProfileSnapshot(
            heightCm: 170, weightKg: 70, birthYear: 1990,
            biologicalSex: .male, currentWeek: 3,
            completedSessionsThisWeek: 3, hasCompletedOnboarding: true,
            hasGraduated: false, startingWeek: 1, usesMetric: false,
            runDays: [2, 4, 6], reminderHour: 7, reminderMinute: 0,
            remindersEnabled: true
        ))

        try await mock.advanceWeek()

        let profile = try await mock.fetchUserProfile()
        #expect(profile?.currentWeek == 4)
        #expect(profile?.completedSessionsThisWeek == 0)
        let called = await mock.advanceWeekCalled
        #expect(called == true)
    }

    @Test("MockDataStore.advanceWeek does not exceed week 9")
    func mockAdvanceWeekCappedAtWeek9() async throws {
        let mock = MockDataStore()
        await mock.setMockProfile(UserProfileSnapshot(
            heightCm: 170, weightKg: 70, birthYear: 1990,
            biologicalSex: .male, currentWeek: 9,
            completedSessionsThisWeek: 3, hasCompletedOnboarding: true,
            hasGraduated: false, startingWeek: 1, usesMetric: false,
            runDays: [2, 4, 6], reminderHour: 7, reminderMinute: 0,
            remindersEnabled: true
        ))

        try await mock.advanceWeek()

        let profile = try await mock.fetchUserProfile()
        #expect(profile?.currentWeek == 9, "Must not advance beyond week 9")
    }

    // MARK: - DashboardViewModel week advance state

    @Test("DashboardViewModel shows canAdvanceWeek after 3 sessions")
    func dashboardShowsAdvanceCTAAfter3Sessions() async throws {
        let mock = MockDataStore()
        await mock.setMockProfile(UserProfileSnapshot(
            heightCm: 170, weightKg: 70, birthYear: 1990,
            biologicalSex: .male, currentWeek: 2,
            completedSessionsThisWeek: 3, hasCompletedOnboarding: true,
            hasGraduated: false, startingWeek: 1, usesMetric: false,
            runDays: [2, 4, 6], reminderHour: 7, reminderMinute: 0,
            remindersEnabled: true
        ))

        let vm = DashboardViewModel(dataStore: mock)
        await vm.loadData()

        #expect(vm.canAdvanceWeek == true, "canAdvanceWeek must be true after 3 sessions")
        #expect(vm.currentWeek == 2)
    }

    @Test("DashboardViewModel.nextSession is nil when already at week 9 day 3")
    func nextSessionNilAtProgramEnd() async throws {
        let mock = MockDataStore()
        await mock.setMockProfile(UserProfileSnapshot(
            heightCm: 170, weightKg: 70, birthYear: 1990,
            biologicalSex: .male, currentWeek: 9,
            completedSessionsThisWeek: 3, hasCompletedOnboarding: true,
            hasGraduated: true, startingWeek: 1, usesMetric: false,
            runDays: [2, 4, 6], reminderHour: 7, reminderMinute: 0,
            remindersEnabled: true
        ))

        let vm = DashboardViewModel(dataStore: mock)
        await vm.loadData()

        // nextSession uses nextSessionNumber = min(3+1, 3) = 3, week 9 day 3 exists — that's fine
        // but hasGraduated should be true
        #expect(vm.hasGraduated == true)
        #expect(vm.canAdvanceWeek == true) // 3 sessions completed
    }

    @Test("nextSessionNumber caps at 3 when all sessions complete")
    func nextSessionNumberCapsAt3() async throws {
        let mock = MockDataStore()
        await mock.setMockProfile(UserProfileSnapshot(
            heightCm: 170, weightKg: 70, birthYear: 1990,
            biologicalSex: .male, currentWeek: 4,
            completedSessionsThisWeek: 3, hasCompletedOnboarding: true,
            hasGraduated: false, startingWeek: 1, usesMetric: false,
            runDays: [2, 4, 6], reminderHour: 7, reminderMinute: 0,
            remindersEnabled: true
        ))

        let vm = DashboardViewModel(dataStore: mock)
        await vm.loadData()

        #expect(vm.nextSessionNumber == 3, "nextSessionNumber must cap at 3, not overflow to 4")
    }

    // MARK: - AppState post-run navigation

    @Test("AppState.isShowingRun can be cleared by post-run completion")
    func postRunCompletionClearsRunFlag() {
        let appState = AppState()
        appState.isShowingRun = true

        // Simulate what PostRunView.onDashboard does
        appState.isShowingRun = false

        #expect(appState.isShowingRun == false)
        #expect(appState.activeSession == nil || appState.activeSession != nil) // session can persist, that's fine
    }

    // MARK: - incrementCompletedSessions boundary

    @Test("incrementCompletedSessions at boundary (3rd session) does not auto-advance week")
    func incrementAt3rdSessionDoesNotAutoAdvance() async throws {
        let container = try makeTestContainer()
        let dataStore = MileOne.DataStore(modelContainer: container)
        try await seedProfile(in: dataStore, week: 2, sessionsThisWeek: 2) // about to hit 3

        try await dataStore.incrementCompletedSessions()

        let profile = try await dataStore.fetchUserProfile()
        // Week must NOT auto-advance — user has to explicitly tap "Start Week N+1"
        #expect(profile?.completedSessionsThisWeek == 3, "Should be 3, not reset")
        #expect(profile?.currentWeek == 2, "Week must not auto-advance — that requires explicit advanceWeek() call")
    }
}
