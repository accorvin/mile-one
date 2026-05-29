import Foundation

// MARK: - PaceFormatter

public enum PaceFormatter {

    /// Format a pace value as "M:SS" per kilometre.
    ///
    /// - Parameter secondsPerKm: Pace in seconds per kilometre.
    /// - Returns: A formatted string like "5:30" or "--:--" for invalid input.
    public static func format(secondsPerKm: Double) -> String {
        guard secondsPerKm > 0, secondsPerKm.isFinite else { return "--:--" }
        let totalSeconds = Int(secondsPerKm.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Format a pace value as "M:SS" per mile (convert from seconds/km).
    ///
    /// - Parameter secondsPerKm: Pace in seconds per kilometre.
    /// - Returns: A formatted string like "8:51" or "--:--" for invalid input.
    public static func formatPerMile(secondsPerKm: Double) -> String {
        guard secondsPerKm > 0, secondsPerKm.isFinite else { return "--:--" }
        let secondsPerMile = secondsPerKm * 1.60934
        return format(secondsPerKm: secondsPerMile)
    }
}
