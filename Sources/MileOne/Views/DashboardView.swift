#if canImport(UIKit)
import SwiftUI

// MARK: - DashboardView

/// Main dashboard showing weekly progress and the next run CTA.
public struct DashboardView: View {

    @State private var viewModel: DashboardViewModel
    @State private var lifetimeStats: LifetimeStats = .zero

    public init(dataStore: any DataStoreProviding) {
        _viewModel = State(initialValue: DashboardViewModel(dataStore: dataStore))
    }

    public var body: some View {
        NavigationStack {
            if viewModel.hasGraduated {
                graduatedBody
            } else {
                programBody
            }
        }
    }

    // MARK: - Program Body (active training)

    private var programBody: some View {
        VStack(spacing: 24) {
            // Weekly ring progress
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: viewModel.completionRingProgress)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: viewModel.completionRingProgress)
            }
            .frame(width: 120, height: 120)
            .accessibilityLabel("Week progress: \(Int(viewModel.completionRingProgress * 3)) of 3 sessions complete")

            // Week / session label
            Text("Week \(viewModel.currentWeek) · Run \(viewModel.nextSessionNumber) of 3")
                .font(.title2.bold())
                .accessibilityLabel("Week \(viewModel.currentWeek), run \(viewModel.nextSessionNumber) of 3")

            if viewModel.isLapsed {
                LapsedUserCard()
            }

            Spacer()

            Button("Start Next Run") {}
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Start run \(viewModel.nextSessionNumber) of week \(viewModel.currentWeek)")
        }
        .padding()
        .navigationTitle("Dashboard")
        .task {
            await viewModel.loadData()
            await viewModel.checkLapsedState()
        }
    }

    // MARK: - Graduated Body (post-program)

    private var graduatedBody: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 12) {
                Text("🎉")
                    .font(.system(size: 64))
                    .accessibilityLabel("Celebration")
                Text("You've Graduated!")
                    .font(.largeTitle.bold())
                Text("9 weeks. 5K. You did it.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            // Lifetime stats summary
            HStack(spacing: 24) {
                StatSummaryTile(value: "\(lifetimeStats.totalRuns)", label: "Runs")
                StatSummaryTile(
                    value: String(format: "%.1f", lifetimeStats.totalDistance / 1609.344),
                    label: "Miles"
                )
                StatSummaryTile(
                    value: "\(Int(lifetimeStats.totalCalories))",
                    label: "Calories"
                )
            }
            .padding()
            .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            Spacer()

            if viewModel.showFreeRunOption {
                Button("Start a Run") {}
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Start a free run")
                    .padding(.horizontal)
            }
        }
        .padding(.vertical, 32)
        .navigationTitle("Dashboard")
        .task {
            await viewModel.loadData()
        }
    }
}

// MARK: - LapsedUserCard

struct LapsedUserCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Welcome back! 👋")
                .font(.headline)
            Text("It's been a while. Ready to get back on track?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - StatSummaryTile

private struct StatSummaryTile: View {
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
