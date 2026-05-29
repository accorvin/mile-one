import Foundation
import SwiftUI
import Observation

// MARK: - RunViewModel

/// View-layer model that receives `RunSnapshot` updates from `RunEngine`
/// and exposes formatted, display-ready properties for SwiftUI views.
@MainActor
@Observable
public final class RunViewModel {

    // MARK: - State

    public var snapshot: RunSnapshot = .empty

    // MARK: - Update

    /// Receive a new snapshot from RunEngine.
    public func update(with newSnapshot: RunSnapshot) {
        snapshot = newSnapshot
    }

    // MARK: - Formatted Properties

    /// Interval remaining formatted as "M:SS" (e.g. "1:30").
    public var formattedIntervalRemaining: String {
        formatTime(snapshot.intervalRemaining)
    }

    /// Total elapsed time formatted as "M:SS" or "MM:SS" (e.g. "12:05").
    public var formattedTotalElapsed: String {
        formatTime(snapshot.totalElapsed)
    }

    /// Session progress as 0.0–1.0 based on interval index.
    public var sessionProgress: Double {
        guard snapshot.totalIntervals > 0 else { return 0 }
        return Double(snapshot.currentIntervalIndex) / Double(snapshot.totalIntervals)
    }

    /// Color for the current interval type.
    public var intervalColor: Color {
        color(for: snapshot.currentIntervalType)
    }

    /// Distance formatted in miles with 2 decimal places.
    public var formattedDistance: String {
        let miles = snapshot.totalDistance / 1_609.344
        return String(format: "%.2f mi", miles)
    }

    /// Label for the next interval, or nil if none.
    public var nextIntervalLabel: String? {
        guard let next = snapshot.nextIntervalType else { return nil }
        switch next {
        case .warmUp:   return "Warm-Up"
        case .run:      return "Run"
        case .walk:     return "Walk"
        case .coolDown: return "Cool-Down"
        }
    }

    // MARK: - Helpers

    /// Format seconds as "M:SS" (e.g. 90 → "1:30", 725 → "12:05").
    private func formatTime(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Map interval type to a display color.
    public func color(for type: IntervalType) -> Color {
        switch type {
        case .run:      return .green
        case .walk:     return .blue
        case .warmUp:   return .orange
        case .coolDown: return .orange
        }
    }
}
