import Foundation
import UserNotifications
@testable import MileOne

// MARK: - MockNotificationCenter

/// Test double for NotificationCenterProviding.
/// Tracks all pending requests and simulates authorization state.
final class MockNotificationCenter: NotificationCenterProviding, @unchecked Sendable {

    // MARK: - Configuration

    /// Whether notification permission has been granted.
    var authorizationGranted: Bool = true

    // MARK: - Call Tracking

    /// All currently pending notification requests.
    private(set) var pendingRequests: [UNNotificationRequest] = []

    /// Identifiers explicitly removed via removePendingNotificationRequests(withIdentifiers:).
    private(set) var removedIdentifiers: [String] = []

    /// Set to true when removeAllPendingNotificationRequests() is called.
    private(set) var didRemoveAll: Bool = false

    // MARK: - NotificationCenterProviding

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        authorizationGranted
    }

    func isAuthorized() async -> Bool {
        authorizationGranted
    }

    func add(_ request: UNNotificationRequest) async throws {
        pendingRequests.append(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
        pendingRequests.removeAll { identifiers.contains($0.identifier) }
    }

    func removeAllPendingNotificationRequests() {
        didRemoveAll = true
        pendingRequests.removeAll()
    }
}
