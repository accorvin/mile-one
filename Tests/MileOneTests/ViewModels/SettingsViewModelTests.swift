import Testing
import Foundation
@testable import MileOne

// MARK: - SettingsViewModelTests

@MainActor
@Suite("SettingsViewModel Tests")
struct SettingsViewModelTests {

    // Build a mock store pre-loaded with a full profile
    private func makeStore(
        usesMetric: Bool = false,
        runDays: [Int] = [2, 4, 6],
        reminderHour: Int = 8,
        reminderMinute: Int = 0,
        remindersEnabled: Bool = true,
        startingWeek: Int = 1,
        heightCm: Double = 175,
        weightKg: Double = 70,
        birthYear: Int = 1990,
        biologicalSex: BiologicalSex = .male,
        currentWeek: Int = 1,
        completedSessionsThisWeek: Int = 0,
        hasGraduated: Bool = false
    ) async -> MockDataStore {
        let mock = MockDataStore()
        await mock.setMockProfile(UserProfileSnapshot(
            heightCm: heightCm,
            weightKg: weightKg,
            birthYear: birthYear,
            biologicalSex: biologicalSex,
            currentWeek: currentWeek,
            completedSessionsThisWeek: completedSessionsThisWeek,
            hasCompletedOnboarding: true,
            hasGraduated: hasGraduated,
            startingWeek: startingWeek,
            usesMetric: usesMetric,
            runDays: runDays,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            remindersEnabled: remindersEnabled
        ))
        return mock
    }

    private func makeVM(store: MockDataStore) -> (SettingsViewModel, MockNotificationCenter) {
        let center = MockNotificationCenter()
        let vm = SettingsViewModel(
            dataStore: store,
            notificationService: NotificationService(center: center)
        )
        return (vm, center)
    }

    // MARK: - loadSettings

    @Test("loadSettings populates all fields from profile")
    func loadSettingsPopulatesAllFields() async throws {
        let store = await makeStore(
            usesMetric: true,
            runDays: [3, 5],
            reminderHour: 7,
            reminderMinute: 30,
            remindersEnabled: false,
            startingWeek: 3,
            heightCm: 180,
            weightKg: 85,
            birthYear: 1985,
            biologicalSex: .female
        )
        let (vm, _) = makeVM(store: store)

        await vm.loadSettings()

        #expect(vm.usesMetric == true)
        #expect(vm.runDays == [3, 5])
        #expect(vm.reminderHour == 7)
        #expect(vm.reminderMinute == 30)
        #expect(vm.remindersEnabled == false)
        #expect(vm.startingWeek == 3)
        #expect(vm.heightCm == 180)
        #expect(vm.weightKg == 85)
        #expect(vm.birthYear == 1985)
        #expect(vm.biologicalSex == .female)
    }

    @Test("loadSettings clears isLoading after completion")
    func loadSettingsClearsLoading() async {
        let store = await makeStore()
        let (vm, _) = makeVM(store: store)

        await vm.loadSettings()

        #expect(vm.isLoading == false)
    }

    @Test("loadSettings sets errorMessage on DataStore failure")
    func loadSettingsSetsErrorOnFailure() async {
        let store = MockDataStore()
        await store.setShouldThrowOnFetch(true)
        let (vm, _) = makeVM(store: store)

        await vm.loadSettings()

        #expect(vm.errorMessage != nil)
        #expect(vm.isLoading == false)
    }

    @Test("loadSettings with no profile leaves defaults unchanged")
    func loadSettingsNoProfileLeavesDefaults() async {
        let store = MockDataStore() // no profile set
        let (vm, _) = makeVM(store: store)

        await vm.loadSettings()

        // Should stay at struct defaults, no crash
        #expect(vm.errorMessage == nil)
        #expect(vm.isLoading == false)
    }

    // MARK: - saveSettings

    @Test("saveSettings persists mutated fields")
    func saveSettingsPersistsMutatedFields() async throws {
        let store = await makeStore(runDays: [2, 4, 6])
        let (vm, _) = makeVM(store: store)
        await vm.loadSettings()

        vm.runDays = [1, 3, 7]
        vm.reminderHour = 6
        vm.reminderMinute = 45
        vm.usesMetric = true
        vm.heightCm = 182
        vm.weightKg = 90
        vm.birthYear = 1988
        vm.biologicalSex = .female

        await vm.saveSettings()

        let profile = try await store.fetchUserProfile()
        #expect(profile?.runDays == [1, 3, 7])
        #expect(profile?.reminderHour == 6)
        #expect(profile?.reminderMinute == 45)
        #expect(profile?.usesMetric == true)
        #expect(profile?.heightCm == 182)
        #expect(profile?.weightKg == 90)
        #expect(profile?.birthYear == 1988)
        #expect(profile?.biologicalSex == .female)
    }

    @Test("saveSettings preserves currentWeek and completedSessionsThisWeek")
    func saveSettingsPreservesProgressFields() async throws {
        let store = await makeStore(currentWeek: 5, completedSessionsThisWeek: 2)
        let (vm, _) = makeVM(store: store)
        await vm.loadSettings()

        vm.heightCm = 170  // mutate something
        await vm.saveSettings()

        let profile = try await store.fetchUserProfile()
        #expect(profile?.currentWeek == 5,
                "saveSettings must not reset currentWeek")
        #expect(profile?.completedSessionsThisWeek == 2,
                "saveSettings must not reset completedSessionsThisWeek")
    }

    @Test("saveSettings preserves hasGraduated = true")
    func saveSettingsPreservesGraduationFlag() async throws {
        let store = await makeStore(hasGraduated: true)
        let (vm, _) = makeVM(store: store)
        await vm.loadSettings()

        vm.usesMetric = true  // unrelated change
        await vm.saveSettings()

        let profile = try await store.fetchUserProfile()
        #expect(profile?.hasGraduated == true,
                "saveSettings must not clear hasGraduated")
    }

    @Test("saveSettings clears isLoading after completion")
    func saveSettingsClearsLoading() async {
        let store = await makeStore()
        let (vm, _) = makeVM(store: store)
        await vm.loadSettings()

        await vm.saveSettings()

        #expect(vm.isLoading == false)
    }

    @Test("saveSettings sets errorMessage on DataStore failure")
    func saveSettingsSetsErrorOnFailure() async {
        let store = await makeStore()
        let (vm, _) = makeVM(store: store)
        await vm.loadSettings()

        await store.setShouldThrowOnSave(true)
        await vm.saveSettings()

        #expect(vm.errorMessage != nil)
        #expect(vm.isLoading == false)
    }

    // MARK: - Notification rescheduling

    @Test("saveSettings reschedules notifications when reminders enabled")
    func saveSettingsReschedulesNotifications() async {
        let store = await makeStore(runDays: [2, 4, 6], remindersEnabled: true)
        let (vm, center) = makeVM(store: store)
        center.authorizationGranted = true
        await vm.loadSettings()

        vm.runDays = [1, 3, 5]
        await vm.saveSettings()

        #expect(center.addedRequests.count == 3,
                "Should schedule 3 notifications for 3 run days")
    }

    @Test("saveSettings does not schedule notifications when reminders disabled")
    func saveSettingsSkipsNotificationsWhenDisabled() async {
        let store = await makeStore(remindersEnabled: false)
        let (vm, center) = makeVM(store: store)
        center.authorizationGranted = true
        await vm.loadSettings()

        vm.remindersEnabled = false
        await vm.saveSettings()

        #expect(center.addedRequests.isEmpty,
                "Must not schedule notifications when reminders are off")
    }

    @Test("saveSettings schedules correct number of notifications for run days")
    func saveSettingsSchedulesCorrectCount() async {
        let store = await makeStore(runDays: [2], remindersEnabled: true)
        let (vm, center) = makeVM(store: store)
        center.authorizationGranted = true
        await vm.loadSettings()

        // Change to 5 run days
        vm.runDays = [1, 2, 3, 4, 5]
        await vm.saveSettings()

        #expect(center.addedRequests.count == 5)
    }

    @Test("saveSettings with reminders disabled calls cancelAllReminders")
    func saveSettingsWithRemindersDisabledCallsCancelAll() async {
        let store = await makeStore(remindersEnabled: false)
        let (vm, center) = makeVM(store: store)
        center.authorizationGranted = true
        await vm.loadSettings()

        vm.remindersEnabled = false
        await vm.saveSettings()

        #expect(center.removeAllCalled == true,
                "Saving with reminders disabled must call cancelAllReminders")
    }

    // MARK: - errorMessage reset

    @Test("errorMessage is nil after successful loadSettings")
    func errorMessageClearedOnSuccessfulLoad() async {
        let store = await makeStore()
        let (vm, _) = makeVM(store: store)

        // Inject a pre-existing error state by failing first, then succeeding
        await store.setShouldThrowOnFetch(true)
        await vm.loadSettings()
        #expect(vm.errorMessage != nil)

        await store.setShouldThrowOnFetch(false)
        await vm.loadSettings()
        #expect(vm.errorMessage == nil)
    }

    @Test("errorMessage is nil after successful saveSettings")
    func errorMessageClearedOnSuccessfulSave() async {
        let store = await makeStore()
        let (vm, _) = makeVM(store: store)
        await vm.loadSettings()

        await store.setShouldThrowOnSave(true)
        await vm.saveSettings()
        #expect(vm.errorMessage != nil)

        await store.setShouldThrowOnSave(false)
        await vm.saveSettings()
        #expect(vm.errorMessage == nil)
    }

    // MARK: - Metric / imperial toggle

    @Test("toggling usesMetric to true is persisted")
    func metricTogglePersisted() async throws {
        let store = await makeStore(usesMetric: false)
        let (vm, _) = makeVM(store: store)
        await vm.loadSettings()

        vm.usesMetric = true
        await vm.saveSettings()

        let profile = try await store.fetchUserProfile()
        #expect(profile?.usesMetric == true)
    }

    @Test("toggling usesMetric to false is persisted")
    func imperialTogglePersisted() async throws {
        let store = await makeStore(usesMetric: true)
        let (vm, _) = makeVM(store: store)
        await vm.loadSettings()

        vm.usesMetric = false
        await vm.saveSettings()

        let profile = try await store.fetchUserProfile()
        #expect(profile?.usesMetric == false)
    }
}
