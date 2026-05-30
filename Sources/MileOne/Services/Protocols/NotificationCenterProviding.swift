import Foundation
import UserNotifications

// MARK: - NotificationCenterProviding

/// Abstracts UNUserNotificationCenter for testability.
public protocol NotificationCenterProviding: Sendable {

    /// Request authorization for notifications.
    /// Returns true when authorized.
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool

    /// Returns true if notification permission has been granted (authorized).
    func isAuthorized() async -> Bool

    /// Add a notification request.
    func add(_ request: UNNotificationRequest) async throws

    /// Remove pending notification requests with the given identifiers.
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])

    /// Remove all pending notification requests.
    func removeAllPendingNotificationRequests()
}

// MARK: - UNUserNotificationCenter + NotificationCenterProviding

extension UNUserNotificationCenter: NotificationCenterProviding {

    public func isAuthorized() async -> Bool {
        let settings = await notificationSettings()
        return settings.authorizationStatus == .authorized
    }
}
