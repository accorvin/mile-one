import Foundation

// MARK: - UnitPreference

/// User's preferred unit system for distances and weights.
public enum UnitPreference: String, Codable, Sendable {
    case imperial
    case metric

    /// Returns the default unit preference based on the locale's measurement system.
    /// US locale → imperial; all others → metric.
    public static func `default`(for locale: Locale = .current) -> UnitPreference {
        if #available(iOS 16, macOS 13, *) {
            return locale.measurementSystem == .us ? .imperial : .metric
        }
        // Fallback: check locale identifier for US
        let id = locale.identifier.lowercased()
        if id.hasPrefix("en_us") || id == "en-us" {
            return .imperial
        }
        return .metric
    }
}
