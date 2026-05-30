import Testing
import Foundation
import SwiftData
@testable import MileOne

/// Tests for graduation detection and hasGraduated flag.
@MainActor
@Suite("Graduation Fix Tests")
struct GraduationFixTests {

    private func makeTestContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: UserProfile.self, CompletedRun.self, GPSPoint.self, SavedRoute.self,
            configurations: config
        )
    }

    private func seedProfile(
        in dataStore: MileOne.DataStore,
        week: Int,
        sessions: Int,
        graduated: Bool = false
    ) async throws {
        try await dataStore.saveUserProfile(
            heightCm: 175, weightKg: 70, birthYear: 1990,
            biologicalSex: .male, currentWeek: week,
            completedSessionsThisWeek: sessions, hasCompletedOnboarding: true,
            hasGraduated: graduated, startingWeek: 1, usesMetric: false,
            runDays: [2, 4, 6], reminderHour: 7, reminderMinute: 0,
            remindersEnabled: true
        )
    }

    @Test("advanceWeek on week 9 with 3 sessions sets hasGraduated = true")
    func advanceWeekAt9SetsGraduated() async throws {
        let container = try makeTestContainer()
        let dataStore = MileOne.DataStore(modelContainer: container)
        try await seedProfile(in: dataStore, week: 9, sessions: 3)

        try await dataStore.advanceWeek()

        let profile = try await dataStore.fetchUserProfile()
        #expect(profile?.hasGraduated == true,
                "hasGraduated must be set to true after completing week 9")
        #expect(profile?.currentWeek == 9,
                "currentWeek should stay at 9 after graduation")
    }

    @Test("advanceWeek on week 9 with fewer than 3 sessions does not graduate")
    func advanceWeekAt9WithoutSessionsDoesNotGraduate() async throws {
        let container = try makeTestContainer()
        let dataStore = MileOne.DataStore(modelContainer: container)
        try await seedProfile(in: dataStore, week: 9, sessions: 2)

        try await dataStore.advanceWeek()

        let profile = try await dataStore.fetchUserProfile()
        #expect(profile?.hasGraduated == false,
                "hasGraduated must not be set without 3 completed sessions")
    }

    @Test("advanceWeek on week 9 when already graduated is idempotent")
    func advanceWeekAt9AlreadyGraduatedIsIdempotent() async throws {
        let container = try makeTestContainer()
        let dataStore = MileOne.DataStore(modelContainer: container)
        try await seedProfile(in: dataStore, week: 9, sessions: 3, graduated: true)

        try await dataStore.advanceWeek()

        let profile = try await dataStore.fetchUserProfile()
        #expect(profile?.hasGraduated == true)
        #expect(profile?.currentWeek == 9)
    }

    @Test("MockDataStore.advanceWeek on week 9 sets hasGraduated = true")
    func mockAdvanceWeekAt9SetsGraduated() async throws {
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
        #expect(profile?.hasGraduated == true,
                "Mock must also set hasGraduated on week 9 completion")
        #expect(profile?.currentWeek == 9)
    }

    @Test("MockDataStore.advanceWeek on week 9 with < 3 sessions does not graduate")
    func mockAdvanceWeekAt9WithoutSessionsDoesNotGraduate() async throws {
        let mock = MockDataStore()
        await mock.setMockProfile(UserProfileSnapshot(
            heightCm: 170, weightKg: 70, birthYear: 1990,
            biologicalSex: .male, currentWeek: 9,
            completedSessionsThisWeek: 2, hasCompletedOnboarding: true,
            hasGraduated: false, startingWeek: 1, usesMetric: false,
            runDays: [2, 4, 6], reminderHour: 7, reminderMinute: 0,
            remindersEnabled: true
        ))

        try await mock.advanceWeek()

        let profile = try await mock.fetchUserProfile()
        #expect(profile?.hasGraduated == false)
    }

    @Test("DashboardViewModel.hasGraduated = true triggers graduated UI state")
    func dashboardViewModelReflectsGraduation() async throws {
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

        #expect(vm.hasGraduated == true)
        #expect(vm.showFreeRunOption == true)
    }

    @Test("Completing week 8 advances to week 9 and does not set hasGraduated")
    func completingWeek8DoesNotGraduate() async throws {
        let container = try makeTestContainer()
        let dataStore = MileOne.DataStore(modelContainer: container)
        try await seedProfile(in: dataStore, week: 8, sessions: 3)

        try await dataStore.advanceWeek()

        let profile = try await dataStore.fetchUserProfile()
        #expect(profile?.hasGraduated == false,
                "Graduation only triggers at week 9, not week 8")
        #expect(profile?.currentWeek == 9,
                "Week 8 should advance to week 9")
    }
}
