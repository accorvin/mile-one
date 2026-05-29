import Foundation

// MARK: - Interval

/// Plain value type (not a SwiftData model) — lives in memory only.
/// Custom Equatable compares type and duration only, NOT the UUID.
public struct Interval: Identifiable, Sendable {
    public let id: UUID
    public let type: IntervalType
    public let durationSeconds: Int

    public init(type: IntervalType, durationSeconds: Int) {
        self.id = UUID()
        self.type = type
        self.durationSeconds = durationSeconds
    }

    public var label: String {
        switch type {
        case .warmUp:   return "Warm-Up Walk"
        case .run:      return "Run"
        case .walk:     return "Walk"
        case .coolDown: return "Cool-Down Walk"
        }
    }
}

extension Interval: Equatable {
    /// Compare type and duration only — two intervals are equal if they represent the same
    /// kind of activity with the same length, regardless of their UUID.
    public static func == (lhs: Interval, rhs: Interval) -> Bool {
        lhs.type == rhs.type && lhs.durationSeconds == rhs.durationSeconds
    }
}

// MARK: - SessionDefinition

public struct SessionDefinition: Identifiable, Sendable {
    public let id: String      // e.g. "W1D1"
    public let week: Int
    public let dayInWeek: Int  // 1, 2, or 3
    public let intervals: [Interval]

    public var totalDurationSeconds: Int {
        intervals.reduce(0) { $0 + $1.durationSeconds }
    }
}
