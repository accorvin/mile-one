import Foundation

// MARK: - PrefilledBiometrics

/// Biometric data pre-populated from HealthKit during onboarding.
/// Fields are optional because HealthKit may not have all values.
public struct PrefilledBiometrics: Sendable {
    public var heightCm: Double?
    public var weightKg: Double?
    public var dateOfBirth: Date?
    public var biologicalSex: BiologicalSex?

    public init(
        heightCm: Double? = nil,
        weightKg: Double? = nil,
        dateOfBirth: Date? = nil,
        biologicalSex: BiologicalSex? = nil
    ) {
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.dateOfBirth = dateOfBirth
        self.biologicalSex = biologicalSex
    }
}
