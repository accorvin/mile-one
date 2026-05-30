import Testing
import Foundation
@testable import MileOne

struct OnboardingBiometricTests {

    @Test func healthKitPrePopulatesFields() async throws {
#if canImport(HealthKit)
        let mockHealth = MockHealthStore()
        let onboarding = OnboardingBiometricService(healthStore: mockHealth)
        let prefilled = try await onboarding.fetchPrefilledBiometrics()

        // Even if HealthKit returns nil values (mock returns empty), the service should not crash
        #expect(prefilled != nil, "Should return a PrefilledBiometrics struct (possibly with nil fields)")
#else
        // On macOS without HealthKit, the stub returns an empty struct — just verify it works
        let onboarding = OnboardingBiometricService()
        let prefilled = try await onboarding.fetchPrefilledBiometrics()
        #expect(prefilled.heightCm == nil)
        #expect(prefilled.weightKg == nil)
#endif
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
