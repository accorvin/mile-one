#if canImport(UIKit)
import SwiftUI

// MARK: - DashboardView

/// Main dashboard showing the next run CTA with a no-scroll, full-screen layout.
public struct DashboardView: View {

    @State private var viewModel: DashboardViewModel
    private var appState: AppState
    private let dataStore: any DataStoreProviding
    @State private var showSettings = false
    @State private var showRoutePlanner = false
    /// When non-nil, the UI previews this session instead of `viewModel.nextSession`.
    /// The Start Run button always uses `viewModel.nextSession`.
    @State private var previewSession: SessionDefinition? = nil

    public init(dataStore: any DataStoreProviding, appState: AppState) {
        _viewModel = State(initialValue: DashboardViewModel(dataStore: dataStore))
        self.appState = appState
        self.dataStore = dataStore
    }

    /// The session shown in the header and interval strip (preview or actual next session).
    private var displaySession: SessionDefinition? {
        previewSession ?? viewModel.nextSession
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
        GeometryReader { geo in
            VStack(spacing: 0) {
                // 1. Gradient hero header
                heroHeader

                // 2. Interval strip (full width, proportional tiles)
                if let session = displaySession {
                    intervalStrip(session: session, totalWidth: geo.size.width)
                }

                Spacer(minLength: 8)

                // 3. Week advance banner (above start button)
                if viewModel.canAdvanceWeek {
                    weekAdvanceBanner
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }

                // 4. Big centered Start Run button
                startButton
                    .padding(.bottom, 12)

                // 5. Stats strip
                statsStrip
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                // 6. Day selector strip
                daySelectorStrip
                    .padding(.bottom, 8)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showRoutePlanner = true
                } label: {
                    Image(systemName: "map")
                }
                .accessibilityLabel("Route Planner")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(viewModel: SettingsViewModel(dataStore: dataStore))
        }
        .sheet(isPresented: $showRoutePlanner) {
            RoutePlannerView(routeService: RouteService(), dataStore: dataStore)
        }
        .task {
            await viewModel.loadData()
            await viewModel.checkLapsedState()
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        let session = displaySession
        let week = session?.week ?? viewModel.currentWeek
        let day = session?.dayInWeek ?? viewModel.nextSessionNumber
        let totalMinutes = (session?.totalDurationSeconds ?? 0) / 60
        return ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.15, blue: 0.45),
                    Color(red: 0.0, green: 0.55, blue: 0.55)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(alignment: .leading, spacing: 6) {
                Text("WEEK \(week) · DAY \(day)")
                    .font(.caption.smallCaps())
                    .foregroundStyle(.white.opacity(0.8))
                    .kerning(1.5)
                Text("/ \(totalMinutes) Min")
                    .font(.title.bold())
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(height: 120)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Week \(week), Day \(day), \(totalMinutes) minutes total")
    }

    // MARK: - Interval Strip

    private func intervalStrip(session: SessionDefinition, totalWidth: CGFloat) -> some View {
        let gapTotal = CGFloat(max(session.intervals.count - 1, 0)) * 2
        let availableWidth = totalWidth - gapTotal
        return HStack(spacing: 2) {
            ForEach(session.intervals) { interval in
                let fraction = CGFloat(interval.durationSeconds) / CGFloat(session.totalDurationSeconds)
                let tileWidth = max(availableWidth * fraction, 8)
                ZStack {
                    Rectangle()
                        .fill(intervalColor(interval.type))
                    Text(intervalTileLabel(interval))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                        .padding(2)
                }
                .frame(width: tileWidth, height: 56)
            }
        }
        .accessibilityLabel("Interval breakdown for this session")
    }

    private func intervalTileLabel(_ interval: Interval) -> String {
        let secs = interval.durationSeconds
        let timeStr: String
        if secs >= 60 && secs % 60 == 0 {
            timeStr = "\(secs / 60) Min"
        } else if secs < 60 {
            timeStr = "\(secs)s"
        } else {
            let m = secs / 60
            let s = secs % 60
            timeStr = "\(m):\(String(format: "%02d", s))"
        }
        switch interval.type {
        case .warmUp:  return "\(timeStr)\nWarm Up"
        case .coolDown: return "\(timeStr)\nCool Down"
        case .walk:    return "\(timeStr)\nWalk"
        case .run:     return "\(timeStr)\nRun"
        }
    }

    // MARK: - Week Advance Banner

    private var weekAdvanceBanner: some View {
        HStack(spacing: 12) {
            Text("🎉")
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("Week \(viewModel.currentWeek) Complete!")
                    .font(.subheadline.bold())
                Text("Ready for Week \(viewModel.currentWeek + 1)?")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task {
                    try? await dataStore.advanceWeek()
                    await viewModel.loadData()
                    previewSession = nil
                }
            } label: {
                Text("Advance")
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.green, in: Capsule())
                    .foregroundStyle(.white)
            }
        }
        .padding(12)
        .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
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
                Text(viewModel.isFirstRun ? "Start Your First Run" : "Start Run")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .font(.title3.bold())
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(.horizontal)
        .accessibilityLabel(viewModel.isFirstRun
            ? "Start your first run"
            : "Start run \(viewModel.nextSessionNumber) of week \(viewModel.currentWeek)")
    }

    // MARK: - Stats Strip

    private var statsStrip: some View {
        HStack(spacing: 0) {
            StatSummaryTile(
                icon: "figure.run",
                value: "\(viewModel.lifetimeStats.totalRuns)",
                label: "Runs"
            )
            Divider().frame(height: 36)
            StatSummaryTile(
                icon: "map",
                value: formattedDistance,
                label: "Distance"
            )
            Divider().frame(height: 36)
            StatSummaryTile(
                icon: "flame",
                value: "\(Int(viewModel.lifetimeStats.totalCalories))",
                label: "Calories"
            )
        }
        .padding(.vertical, 10)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Day Selector Strip

    private var daySelectorStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SessionPlanLibrary.allSessions) { session in
                        daySelectorChip(session: session)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .onAppear {
                if let nextSession = viewModel.nextSession {
                    proxy.scrollTo(nextSession.id, anchor: .center)
                }
            }
        }
    }

    private func daySelectorChip(session: SessionDefinition) -> some View {
        let isNext = session.week == viewModel.currentWeek
            && session.dayInWeek == viewModel.nextSessionNumber
        let isActive: Bool = {
            if let ps = previewSession {
                return ps.id == session.id
            }
            return isNext
        }()

        return Button {
            if isNext {
                previewSession = nil
            } else {
                previewSession = session
            }
        } label: {
            Text("W\(session.week)D\(session.dayInWeek)")
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isActive ? Color.accentColor : Color(.systemGray5), in: Capsule())
                .foregroundStyle(isActive ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .id(session.id)
        .accessibilityLabel("Week \(session.week) Day \(session.dayInWeek)\(isNext ? ", next session" : "")")
    }

    // MARK: - Helpers

    private var formattedDistance: String {
        let meters = viewModel.lifetimeStats.totalDistance
        if viewModel.usesMetric {
            return String(format: "%.1f km", meters / 1000.0)
        } else {
            return String(format: "%.1f mi", meters / 1609.344)
        }
    }

    private func intervalColor(_ type: IntervalType) -> Color {
        switch type {
        case .warmUp, .walk, .coolDown: return .green
        case .run: return .orange
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
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showRoutePlanner = true
                } label: {
                    Image(systemName: "map")
                }
                .accessibilityLabel("Route Planner")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(viewModel: SettingsViewModel(dataStore: dataStore))
        }
        .sheet(isPresented: $showRoutePlanner) {
            RoutePlannerView(routeService: RouteService(), dataStore: dataStore)
        }
        .task {
            await viewModel.loadData()
        }
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
