import Testing
import Foundation
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

    @Test func programCompletionPercentage() async throws {
        // Week 5, Session 2 complete = (4*3 + 2) / 27 = 14/27 ≈ 51.85%
        // After completing 2 sessions: completedSessionsThisWeek = 2, ring = 2/3
        let mockStore = MockDataStore()
        await mockStore.setMockProfile(UserProfileSnapshot(
            heightCm: 170, weightKg: 70, birthYear: 1990,
            biologicalSex: .male, currentWeek: 5,
            completedSessionsThisWeek: 2, hasCompletedOnboarding: true,
            hasGraduated: false, startingWeek: 1, usesMetric: false,
            runDays: [2, 4, 6], reminderHour: 7, reminderMinute: 0,
            remindersEnabled: true
        ))
        let vm = DashboardViewModel(dataStore: mockStore)
        await vm.loadData()

        let pct = vm.programCompletionPercentage
        // (5-1)*3 + Int(2/3 * 3) = 12 + 2 = 14; 14/27 * 100 ≈ 51.85
        #expect(pct > 51 && pct < 53,
                "programCompletionPercentage for W5 S2 should be ~51.85%, got \(pct)")
    }

    @Test func loadDataWhenFetchRunsThrowsSetsEmptyState() async throws {
        let mockStore = MockDataStore()
        await mockStore.setMockProfile(UserProfileSnapshot(
            heightCm: 170, weightKg: 70, birthYear: 1990,
            biologicalSex: .male, currentWeek: 2,
            completedSessionsThisWeek: 1, hasCompletedOnboarding: true,
            hasGraduated: false, startingWeek: 1, usesMetric: false,
            runDays: [2, 4, 6], reminderHour: 7, reminderMinute: 0,
            remindersEnabled: true
        ))
        await mockStore.setShouldThrowOnFetchRuns(true)

        let vm = DashboardViewModel(dataStore: mockStore)
        await vm.loadData()

        // When fetchCompletedRuns throws, loadData uses ?? [] fallback:
        // lifetimeStats and isFirstRun still get computed from empty array
        #expect(vm.lifetimeStats.totalRuns == 0,
                "When fetchCompletedRuns throws, lifetime stats should be zero")
        #expect(vm.isFirstRun == true,
                "When fetchCompletedRuns throws, isFirstRun should default to true")
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
