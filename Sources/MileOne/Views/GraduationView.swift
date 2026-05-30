#if canImport(UIKit)
import SwiftUI

// MARK: - GraduationView

/// Full-screen celebration shown when the user completes the 9-week program.
public struct GraduationView: View {

    let lifetimeStats: LifetimeStats
    let onKeepRunning: () -> Void

    public init(lifetimeStats: LifetimeStats, onKeepRunning: @escaping () -> Void) {
        self.lifetimeStats = lifetimeStats
        self.onKeepRunning = onKeepRunning
    }

    public var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // MARK: Celebration Header
            VStack(spacing: 12) {
                Text("🎉")
                    .font(.system(size: 72))
                    .accessibilityLabel("Celebration emoji")

                Text("You ran 5K.")
                    .font(.largeTitle.bold())

                Text("You did it.")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            // MARK: Lifetime Stats
            VStack(spacing: 16) {
                Text("Your Journey")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 24) {
                    StatTile(
                        value: "\(lifetimeStats.totalRuns)",
                        label: "Runs"
                    )
                    StatTile(
                        value: formattedDistance,
                        label: "Miles"
                    )
                    StatTile(
                        value: formattedDuration,
                        label: "Time"
                    )
                }

                StatTile(
                    value: "\(Int(lifetimeStats.totalCalories))",
                    label: "Calories"
                )
            }
            .padding()
            .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            Spacer()

            // MARK: CTA
            Button(action: onKeepRunning) {
                Text("Keep Running")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
            .accessibilityLabel("Keep Running — start a free run")
        }
        .padding(.vertical, 32)
        .navigationTitle("Congratulations!")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers

    private var formattedDistance: String {
        let miles = lifetimeStats.totalDistance / 1609.344
        return String(format: "%.1f", miles)
    }

    private var formattedDuration: String {
        let hours = Int(lifetimeStats.totalDuration) / 3600
        let minutes = (Int(lifetimeStats.totalDuration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - StatTile

private struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }
}
#endif
