import Testing
import Foundation
@testable import MileOne

// MARK: - OnboardingViewModelTests

@MainActor
@Suite("OnboardingViewModel Tests")
struct OnboardingViewModelTests {

    private func makeVM(store: MockDataStore = MockDataStore()) -> OnboardingViewModel {
        OnboardingViewModel(dataStore: store, notificationService: NotificationService(center: MockNotificationCenter()))
    }

    // MARK: - Navigation

    @Test("advance() increments currentStep")
    func advanceIncrementsStep() {
        let vm = makeVM()
        let initial = vm.currentStep
        vm.advance()
        let allCases = OnboardingStep.allCases
        let expectedNext = allCases[allCases.firstIndex(of: initial)! + 1]
        #expect(vm.currentStep == expectedNext,
                "advance() must move to the next step")
    }

    @Test("advance() at the last step does not go out of bounds")
    func advanceAtLastStepIsNoOp() {
        let vm = makeVM()
        let lastStep = OnboardingStep.allCases.last!

        // Advance to the last step
        while vm.currentStep != lastStep {
            vm.advance()
        }
        #expect(vm.currentStep == lastStep)

        // Advancing again must not crash or overflow
        vm.advance()
        #expect(vm.currentStep == lastStep,
                "advance() at the last step must stay at the last step")
    }

    @Test("goBack() decrements currentStep")
    func goBackDecrementsStep() {
        let vm = makeVM()
        vm.advance()  // move to step 1
        let beforeBack = vm.currentStep

        vm.goBack()

        let allCases = OnboardingStep.allCases
        let expectedPrev = allCases[allCases.firstIndex(of: beforeBack)! - 1]
        #expect(vm.currentStep == expectedPrev,
                "goBack() must move to the previous step")
    }

    @Test("goBack() at step 0 stays at step 0 (no underflow)")
    func goBackAtFirstStepIsNoOp() {
        let vm = makeVM()
        #expect(vm.currentStep == .welcome)

        vm.goBack()
        #expect(vm.currentStep == .welcome,
                "goBack() at the first step must stay at welcome")
    }

    // MARK: - Completion

    @Test("completeOnboarding() when saveUserProfile throws surfaces the error")
    func completeOnboardingThrowingSurfacesError() async throws {
        let store = MockDataStore()
        await store.setShouldThrowOnSave(true)
        let vm = makeVM(store: store)

        do {
            try await vm.completeOnboarding()
            Issue.record("completeOnboarding() should have thrown when saveUserProfile throws")
        } catch {
            // Error is surfaced (not swallowed) — any error is acceptable
        }
    }

    @Test("completeOnboarding() saves profile to store")
    func completeOnboardingSavesProfile() async throws {
        let store = MockDataStore()
        let vm = makeVM(store: store)
        vm.heightCm = 180
        vm.weightKg = 80
        vm.birthYear = 1990
        vm.biologicalSex = .male
        vm.remindersEnabled = false  // skip notification scheduling

        try await vm.completeOnboarding()

        let profile = try await store.fetchUserProfile()
        #expect(profile != nil, "Profile should be saved after completeOnboarding()")
        #expect(profile?.heightCm == 180)
        #expect(profile?.weightKg == 80)
    }
}
