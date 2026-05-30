import Foundation
import Testing
@testable import MileOne

@MainActor
struct GraduationTests {

    @Test func graduationTriggersAfterWeek9Day3() async throws {
        let mockStore = MockDataStore()
        // Before completing 3rd session
        await mockStore.setMockProfile(UserProfileSnapshot(
            heightCm: 170, weightKg: 70, birthYear: 1990,
            biologicalSex: .male, currentWeek: 9,
            completedSessionsThisWeek: 2, hasCompletedOnboarding: true,
            hasGraduated: false, startingWeek: 1, usesMetric: false,
            runDays: [2, 4, 6], reminderHour: 7, reminderMinute: 0,
            remindersEnabled: true
        ))

        let vm = DashboardViewModel(dataStore: mockStore)
        await vm.loadData()
        #expect(vm.hasGraduated == false)

        // Simulate completing the final session
        await mockStore.setMockProfile(UserProfileSnapshot(
            heightCm: 170, weightKg: 70, birthYear: 1990,
            biologicalSex: .male, currentWeek: 9,
            completedSessionsThisWeek: 3, hasCompletedOnboarding: true,
            hasGraduated: true, startingWeek: 1, usesMetric: false,
            runDays: [2, 4, 6], reminderHour: 7, reminderMinute: 0,
            remindersEnabled: true
        ))
        await vm.loadData()

        #expect(vm.hasGraduated == true, "Graduation must trigger at Week 9, Session 3")
    }

    @Test func graduationNotTriggeredEarly() async throws {
        let mockStore = MockDataStore()
        await mockStore.setMockProfile(UserProfileSnapshot(
            heightCm: 170, weightKg: 70, birthYear: 1990,
            biologicalSex: .male, currentWeek: 8,
            completedSessionsThisWeek: 3, hasCompletedOnboarding: true,
            hasGraduated: false, startingWeek: 1, usesMetric: false,
            runDays: [2, 4, 6], reminderHour: 7, reminderMinute: 0,
            remindersEnabled: true
        ))

        let vm = DashboardViewModel(dataStore: mockStore)
        await vm.loadData()

        #expect(vm.hasGraduated == false, "Week 8 completion must not trigger graduation")
    }

    @Test func graduationShowsLifetimeStats() async throws {
        let mockStore = MockDataStore()
        await mockStore.setMockProfile(UserProfileSnapshot(
            heightCm: 170, weightKg: 70, birthYear: 1990,
            biologicalSex: .male, currentWeek: 9,
            completedSessionsThisWeek: 3, hasCompletedOnboarding: true,
            hasGraduated: true, startingWeek: 1, usesMetric: false,
            runDays: [2, 4, 6], reminderHour: 7, reminderMinute: 0,
            remindersEnabled: true
        ))
        await mockStore.setMockRuns([
            CompletedRunSnapshot(id: UUID(), weekNumber: 1, sessionNumber: 1,
                                 date: Date(), distanceMeters: 2000,
                                 durationSeconds: 1800, calories: 200,
                                 averagePaceSecondsPerKm: nil, averageHeartRate: nil,
                                 effortRating: nil, isFreeRun: false),
            CompletedRunSnapshot(id: UUID(), weekNumber: 9, sessionNumber: 3,
                                 date: Date(), distanceMeters: 5000,
                                 durationSeconds: 2400, calories: 350,
                                 averagePaceSecondsPerKm: nil, averageHeartRate: nil,
                                 effortRating: nil, isFreeRun: false),
        ])

        let vm = HistoryViewModel(dataStore: mockStore)
        await vm.loadRuns()

        #expect(vm.lifetimeStats.totalRuns == 2)
        #expect(vm.lifetimeStats.totalDistance == 7000)
        #expect(vm.lifetimeStats.totalCalories == 550)
    }

    @Test func postGraduationDashboardShowsRunButton() async throws {
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
        #expect(vm.showFreeRunOption == true,
                "Post-graduation dashboard should show free run option")
    }
}
