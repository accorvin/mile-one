import Foundation

// MARK: - RunCheckpoint

/// Lightweight snapshot of in-progress run state, persisted to UserDefaults every 60 seconds.
/// Used for crash recovery — if the app is killed mid-run, the checkpoint lets us detect
/// and optionally resume the session.
public struct RunCheckpoint: Codable, Sendable {
    public let sessionId: String
    public let currentIntervalIndex: Int
    public let totalElapsed: TimeInterval
    public let totalDistance: Double
    public let timestamp: Date

    public init(
        sessionId: String,
        currentIntervalIndex: Int,
        totalElapsed: TimeInterval,
        totalDistance: Double,
        timestamp: Date = Date()
    ) {
        self.sessionId = sessionId
        self.currentIntervalIndex = currentIntervalIndex
        self.totalElapsed = totalElapsed
        self.totalDistance = totalDistance
        self.timestamp = timestamp
    }

    /// A checkpoint is valid if it was created less than 2 hours ago.
    public var isValid: Bool {
        abs(timestamp.timeIntervalSinceNow) < 7200
    }

    // MARK: - Persistence

    public static let key = "com.mileone.runCheckpoint"

    /// Save this checkpoint to a UserDefaults store (defaults to `.standard`).
    public func save(to store: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        store.set(data, forKey: RunCheckpoint.key)
    }

    /// Load the most recent checkpoint from a UserDefaults store.
    public static func load(from store: UserDefaults = .standard) -> RunCheckpoint? {
        guard let data = store.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(RunCheckpoint.self, from: data)
    }

    /// Clear any saved checkpoint from a UserDefaults store.
    public static func clear(from store: UserDefaults = .standard) {
        store.removeObject(forKey: key)
    }
}
