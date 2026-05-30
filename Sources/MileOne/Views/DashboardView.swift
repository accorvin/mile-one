#if canImport(UIKit)
import SwiftUI

// MARK: - DashboardView

/// Main dashboard showing weekly progress and the next run CTA.
public struct DashboardView: View {

    @State private var viewModel: DashboardViewModel

    public init(dataStore: any DataStoreProviding) {
        _viewModel = State(initialValue: DashboardViewModel(dataStore: dataStore))
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Weekly ring progress
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 12)
                    Circle()
                        .trim(from: 0, to: viewModel.completionRingProgress)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 120, height: 120)

                // Week / session label
                Text("Week \(viewModel.currentWeek) · Run \(viewModel.nextSessionNumber) of 3")
                    .font(.title2.bold())

                if viewModel.isLapsed {
                    LapsedUserCard()
                }

                if viewModel.hasGraduated {
                    Text("🎉 You've graduated the program!")
                        .font(.headline)
                        .foregroundStyle(.green)
                }

                Spacer()

                Button("Start Next Run") {}
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.hasGraduated)
            }
            .padding()
            .navigationTitle("Dashboard")
            .task {
                await viewModel.loadData()
                await viewModel.checkLapsedState()
            }
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
    }
}
#endif
