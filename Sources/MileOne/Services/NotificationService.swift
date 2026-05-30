import Foundation
import UserNotifications

// MARK: - NotificationService

/// Manages scheduling of run reminder notifications.
/// Uses a `NotificationCenterProviding` for testability.
public final class NotificationService: Sendable {

    private let center: any NotificationCenterProviding

    public init(center: any NotificationCenterProviding = UNUserNotificationCenter.current()) {
        self.center = center
    }

    // MARK: - Permission

    /// Request notification authorization. Returns true if granted.
    @discardableResult
    public func requestPermission() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    // MARK: - Cancel

    /// Cancel all pending run reminders.
    public func cancelAllReminders() {
        center.removeAllPendingNotificationRequests()
    }

    // MARK: - Scheduling

    /// Schedule weekly repeating run reminders for the given weekdays and time.
    /// - Parameters:
    ///   - runDays: Weekday numbers (1 = Sunday, 2 = Monday … 7 = Saturday)
    ///   - time: DateComponents containing hour and minute
    ///
    /// Removes all existing pending notifications before scheduling new ones.
    /// Silently skips scheduling if notification permission has not been granted.
    public func scheduleRunReminders(
        runDays: [Int],
        time: DateComponents
    ) async throws {
        // Remove all existing pending requests first
        center.removeAllPendingNotificationRequests()

        // Check authorization status
        guard await center.isAuthorized() else { return }

        for day in runDays {
            var dateComponents = time
            dateComponents.weekday = day

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: dateComponents,
                repeats: true
            )

            let content = UNMutableNotificationContent()
            content.title = "Time to Run! 🏃"
            content.body = "Your run is scheduled for today. Lace up and let's go!"
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "run-reminder-\(day)",
                content: content,
                trigger: trigger
            )
            try await center.add(request)
        }
    }
}
