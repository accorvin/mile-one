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

    private static let key = "com.mileone.runCheckpoint"

    /// Save this checkpoint to UserDefaults.
    public func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: RunCheckpoint.key)
    }

    /// Load the most recent checkpoint from UserDefaults, if any.
    public static func load() -> RunCheckpoint? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(RunCheckpoint.self, from: data)
    }

    /// Clear any saved checkpoint.
    public static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
