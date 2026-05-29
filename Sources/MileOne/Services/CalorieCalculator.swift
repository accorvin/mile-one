import Foundation

// MARK: - CalorieCalculator

/// Estimates calories burned during a run session.
///
/// Formula: weightedMET × weightKg × (actualDurationSeconds / 3600)
///
/// The weightedMET is computed from the planned interval ratios (run vs walk time),
/// but the duration multiplier uses the ACTUAL duration the runner was active —
/// so pauses reduce calories proportionally.
public enum CalorieCalculator {

    private static let walkingMET: Double = 3.5
    private static let runningMET: Double = 8.0

    /// Calculate calories burned.
    ///
    /// - Parameters:
    ///   - weightKg: Runner's weight in kilograms. Zero or negative returns 0.
    ///   - intervals: Planned session intervals used to compute the MET weighting.
    ///   - actualDurationSeconds: How long the runner was actually active (not planned duration).
    ///                            Zero returns 0.
    /// - Returns: Estimated kilocalories burned.
    public static func calculate(
        weightKg: Double,
        intervals: [Interval],
        actualDurationSeconds: Double
    ) -> Double {
        guard weightKg > 0 else { return 0 }
        guard actualDurationSeconds > 0 else { return 0 }
        guard !intervals.isEmpty else { return 0 }

        // Sum planned run time and walk/warmup/cooldown time from intervals
        var plannedRunSeconds: Double = 0
        var plannedWalkSeconds: Double = 0

        for interval in intervals {
            let s = Double(interval.durationSeconds)
            switch interval.type {
            case .run:
                plannedRunSeconds += s
            case .walk, .warmUp, .coolDown:
                plannedWalkSeconds += s
            }
        }

        let totalPlanned = plannedRunSeconds + plannedWalkSeconds
        guard totalPlanned > 0 else { return 0 }

        // Weighted MET based on proportion of run vs walk in the planned session
        let runFraction  = plannedRunSeconds  / totalPlanned
        let walkFraction = plannedWalkSeconds / totalPlanned
        let weightedMET  = (runFraction * runningMET) + (walkFraction * walkingMET)

        // Calories = MET × kg × hours (using ACTUAL duration)
        return weightedMET * weightKg * (actualDurationSeconds / 3600.0)
    }
}
