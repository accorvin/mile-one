#if canImport(HealthKit)
import Foundation
import HealthKit

// MARK: - OnboardingBiometricService (HealthKit)

/// Reads biometric data from HealthKit to pre-populate onboarding fields.
/// On non-HealthKit platforms this type still exists but returns empty data.
public final class OnboardingBiometricService: Sendable {

    private let healthStore: any HealthStoreProviding

    public init(healthStore: any HealthStoreProviding) {
        self.healthStore = healthStore
    }

    /// Fetch biometric data from HealthKit.
    /// Returns a `PrefilledBiometrics` struct — fields are nil if HealthKit data
    /// is unavailable or permission was not granted.
    public func fetchPrefilledBiometrics() async throws -> PrefilledBiometrics {
        var bio = PrefilledBiometrics()

        // Request read permission for height and weight
        let readTypes: Set<HKObjectType> = [
            HKQuantityType(.height),
            HKQuantityType(.bodyMass),
        ]
        guard (try? await healthStore.requestAuthorization(toShare: [], read: readTypes)) == true else {
            return bio
        }

        // Use a concrete HKHealthStore for the sample query (not on the shared protocol)
        let store = HKHealthStore()

        // Read height (most recent sample)
        if let sample = try? await readMostRecentSample(for: HKQuantityType(.height), store: store) {
            bio.heightCm = sample.quantity.doubleValue(for: .meterUnit(with: .centi))
        }

        // Read weight (most recent sample)
        if let sample = try? await readMostRecentSample(for: HKQuantityType(.bodyMass), store: store) {
            bio.weightKg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
        }

        return bio
    }

    // MARK: - Private Helpers

    private func readMostRecentSample(
        for type: HKQuantityType,
        store: HKHealthStore
    ) async throws -> HKQuantitySample? {
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)],
            limit: 1
        )
        let results = try await descriptor.result(for: store)
        return results.first
    }
}

#else
import Foundation

// MARK: - OnboardingBiometricService (stub for macOS)

public final class OnboardingBiometricService: Sendable {

    public init() {}

    /// On non-HealthKit platforms, returns an empty `PrefilledBiometrics`.
    public func fetchPrefilledBiometrics() async throws -> PrefilledBiometrics {
        PrefilledBiometrics()
    }
}

#endif
