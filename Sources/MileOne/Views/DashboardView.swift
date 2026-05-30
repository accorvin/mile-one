#if canImport(UIKit)
import SwiftUI

// MARK: - DashboardView

/// Main dashboard showing weekly progress and the next run CTA.
public struct DashboardView: View {

    @State private var viewModel: DashboardViewModel
    private var appState: AppState
    private let dataStore: any DataStoreProviding

    public init(dataStore: any DataStoreProviding, appState: AppState) {
        _viewModel = State(initialValue: DashboardViewModel(dataStore: dataStore))
        self.appState = appState
        self.dataStore = dataStore
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
        ScrollView {
            VStack(spacing: 20) {
                // Welcome header
                welcomeHeader

                // Program journey bar
                journeyBar

                // Lapsed user card
                if viewModel.isLapsed {
                    LapsedUserCard()
                        .padding(.horizontal)
                }

                // Week advance CTA
                if viewModel.canAdvanceWeek && !viewModel.hasGraduated {
                    weekAdvanceCTA
                }

                // Session preview card
                if let session = viewModel.nextSession {
                    sessionPreviewCard(session)
                }

                // Motivational quote
                motivationQuote

                // Start button
                startButton

                // Stats footer
                statsFooter
            }
            .padding(.bottom, 16)
        }
        .navigationTitle("Mile One")
        .task {
            await viewModel.loadData()
            await viewModel.checkLapsedState()
        }
    }

    // MARK: - Welcome Header

    private var welcomeHeader: some View {
        VStack(spacing: 4) {
            if viewModel.isFirstRun {
                Text("Ready for your first run? 🏃‍♂️")
                    .font(.title2.bold())
                if viewModel.startingWeek > 1 {
                    Text("You're starting at Week \(viewModel.currentWeek) — let's go!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Your journey to 5K starts now!")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Week \(viewModel.currentWeek) · Run \(viewModel.nextSessionNumber) of 3")
                    .font(.title2.bold())
                Text(weekEncouragement)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
    }

    private var weekEncouragement: String {
        switch viewModel.currentWeek {
        case 1...2: return "Building your foundation 💪"
        case 3...4: return "You're finding your rhythm!"
        case 5...6: return "Halfway there — keep pushing!"
        case 7...8: return "The finish line is in sight 🔥"
        case 9: return "Final week — you've got this!"
        default: return "Keep going!"
        }
    }

    // MARK: - Journey Bar

    private var journeyBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 3) {
                ForEach(1...Constants.totalWeeks, id: \.self) { week in
                    journeySegment(week: week)
                }
            }
            .padding(.horizontal)

            HStack {
                Text("Week 1")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Week \(viewModel.currentWeek)")
                    .font(.caption2.bold())
                    .foregroundStyle(Color.accentColor)
                Spacer()
                Text("5K! 🎉")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Program progress: Week \(viewModel.currentWeek) of \(Constants.totalWeeks)")
    }

    private func journeySegment(week: Int) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(weekColor(week))
            .frame(height: 6)
            .overlay {
                if week == viewModel.currentWeek {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 10, height: 10)
                }
            }
    }

    private func weekColor(_ week: Int) -> Color {
        if week < viewModel.currentWeek {
            return Color.accentColor
        } else if week == viewModel.currentWeek {
            return Color.accentColor.opacity(0.4)
        } else {
            return .secondary.opacity(0.2)
        }
    }

    // MARK: - Session Preview Card

    private func sessionPreviewCard(_ session: SessionDefinition) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TODAY'S SESSION")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text("Week \(session.week) · Run \(session.dayInWeek) of 3")
                        .font(.headline)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatDuration(session.totalDurationSeconds))
                        .font(.subheadline.bold())
                }
            }

            Divider()

            // Visual timeline bar
            HStack(spacing: 2) {
                ForEach(session.intervals) { interval in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(intervalColor(interval.type))
                        .frame(height: 24)
                        .frame(maxWidth: CGFloat(interval.durationSeconds) / CGFloat(session.totalDurationSeconds) * 300)
                }
            }
            .accessibilityLabel("Session timeline showing walk and run intervals")

            // Legend
            HStack(spacing: 16) {
                Label("Walk", systemImage: "figure.walk")
                    .font(.caption)
                    .foregroundStyle(.green)
                Label("Run", systemImage: "figure.run")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Divider()

            // Interval breakdown
            VStack(alignment: .leading, spacing: 6) {
                ForEach(session.intervals) { interval in
                    HStack(spacing: 8) {
                        Text(intervalEmoji(interval.type))
                            .frame(width: 24)
                        Text(intervalLabel(interval))
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Motivation

    private var motivationQuote: some View {
        Text(dailyQuote)
            .font(.footnote.italic())
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
    }

    private var dailyQuote: String {
        let quotes = [
            "\"The miracle isn't that I finished. The miracle is that I had the courage to start.\"",
            "\"Every mile is two thousand steps. Every run starts with one.\"",
            "\"You don't have to be great to start, but you have to start to be great.\"",
            "\"Run when you can, walk if you have to, crawl if you must; just never give up.\"",
            "\"The hardest step is the one out the door.\"",
            "\"Your body can stand almost anything. It's your mind you have to convince.\"",
            "\"A year from now you'll wish you started today.\"",
        ]
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return quotes[dayOfYear % quotes.count]
    }

    // MARK: - Week Advance CTA

    private var weekAdvanceCTA: some View {
        VStack(spacing: 12) {
            Text("🎉 Week \(viewModel.currentWeek) Complete!")
                .font(.headline)
            Text("You've finished all 3 sessions. Ready for Week \(viewModel.currentWeek + 1)?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task {
                    try? await dataStore.advanceWeek()
                    await viewModel.loadData()
                }
            } label: {
                Text("Start Week \(viewModel.currentWeek + 1) →")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Start Button

    private var startButton: some View {
        Button {
            appState.activeSession = viewModel.nextSession
            appState.isShowingRun = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                Text(viewModel.isFirstRun ? "Start Your First Run" : "Start Next Run")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(.horizontal)
        .accessibilityLabel(viewModel.isFirstRun
            ? "Start your first run"
            : "Start run \(viewModel.nextSessionNumber) of week \(viewModel.currentWeek)")
    }

    // MARK: - Stats Footer

    private var statsFooter: some View {
        HStack(spacing: 0) {
            StatSummaryTile(
                icon: "figure.run",
                value: "\(viewModel.lifetimeStats.totalRuns)",
                label: "Runs"
            )
            Divider().frame(height: 40)
            StatSummaryTile(
                icon: "map",
                value: formattedDistance,
                label: "Distance"
            )
            Divider().frame(height: 40)
            StatSummaryTile(
                icon: "flame",
                value: "\(Int(viewModel.lifetimeStats.totalCalories))",
                label: "Calories"
            )
        }
        .padding(.vertical, 14)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private var formattedDistance: String {
        let meters = viewModel.lifetimeStats.totalDistance
        if viewModel.usesMetric {
            return String(format: "%.1f km", meters / 1000.0)
        } else {
            return String(format: "%.1f mi", meters / 1609.344)
        }
    }

    // MARK: - Interval Helpers

    private func intervalColor(_ type: IntervalType) -> Color {
        switch type {
        case .warmUp, .walk, .coolDown: return .green
        case .run: return .orange
        }
    }

    private func intervalEmoji(_ type: IntervalType) -> String {
        switch type {
        case .warmUp, .walk, .coolDown: return "🚶"
        case .run: return "🏃"
        }
    }

    private func intervalLabel(_ interval: Interval) -> String {
        let seconds = interval.durationSeconds
        let prefix: String
        switch interval.type {
        case .warmUp: prefix = "Warm-up walk"
        case .coolDown: prefix = "Cool-down walk"
        case .walk: prefix = "Walk"
        case .run: prefix = "Run"
        }
        return "\(prefix) \(formatDuration(seconds))"
    }

    private func formatDuration(_ seconds: Int) -> String {
        if seconds >= 60 && seconds % 60 == 0 {
            return "\(seconds / 60) min"
        } else if seconds < 60 {
            return "\(seconds)s"
        } else {
            let min = seconds / 60
            let sec = seconds % 60
            return "\(min):\(String(format: "%02d", sec))"
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
                StatSummaryTile(
                    icon: "figure.run",
                    value: "\(viewModel.lifetimeStats.totalRuns)",
                    label: "Runs"
                )
                StatSummaryTile(
                    icon: "map",
                    value: formattedDistance,
                    label: "Distance"
                )
                StatSummaryTile(
                    icon: "flame",
                    value: "\(Int(viewModel.lifetimeStats.totalCalories))",
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
                    .controlSize(.large)
                    .accessibilityLabel("Start a free run")
                    .padding(.horizontal)
            }
        }
        .padding(.vertical, 32)
        .navigationTitle("Mile One")
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
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }
}
#endif
