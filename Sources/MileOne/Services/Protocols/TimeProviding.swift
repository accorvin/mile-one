import Foundation

// MARK: - TimeProviding

/// Injectable time source for testable wall-clock operations.
/// Replace with a mock in tests to control time precisely.
public protocol TimeProviding: Sendable {
    func now() -> Date
}

// MARK: - SystemTimeProvider

/// Production implementation — returns the real system clock.
public struct SystemTimeProvider: TimeProviding, Sendable {
    public init() {}
    public func now() -> Date { Date() }
}
