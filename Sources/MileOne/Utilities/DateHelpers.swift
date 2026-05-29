import Foundation

// MARK: - DateHelpers

public enum DateHelpers {

    private nonisolated(unsafe) static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private nonisolated(unsafe) static let shortTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    private nonisolated(unsafe) static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .full
        return f
    }()

    /// Format a date as a short date string, e.g. "May 29, 2026".
    public static func shortDate(_ date: Date) -> String {
        shortDateFormatter.string(from: date)
    }

    /// Format a date as a short time string, e.g. "7:00 AM".
    public static func shortTime(_ date: Date) -> String {
        shortTimeFormatter.string(from: date)
    }

    /// Format a date relative to now, e.g. "2 days ago".
    public static func relative(_ date: Date) -> String {
        relativeDateFormatter.localizedString(for: date, relativeTo: Date())
    }

    /// Format a duration in seconds as "H:MM:SS" or "M:SS" if under an hour.
    public static func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%d:%02d", m, s)
        }
    }

    /// Returns true if the date falls on today in the user's current calendar.
    public static func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
}
