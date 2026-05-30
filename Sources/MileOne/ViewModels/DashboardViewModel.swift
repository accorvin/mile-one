import Foundation
import Observation

// MARK: - DashboardViewModel

/// ViewModel for the dashboard screen.
/// Fetches profile and run data from the DataStore and exposes computed state.
@MainActor
@Observable
public final class DashboardViewModel {

    // MARK: - Injected Dependencies

    private let dataStore: any DataStoreProviding

    // MARK: - Published State

    /// Current training week (1–9).
    public private(set) var currentWeek: Int = 1

    /// The next session number within the current week (1–3).
    public private(set) var nextSessionNumber: Int = 1

    /// Progress through the current week's sessions (0.0 – 1.0).
    /// 0 sessions = 0.0, 1 session = 0.333, 2 sessions = 0.667, 3 sessions = 1.0.
    public private(set) var completionRingProgress: Double = 0.0

    /// True when the user has completed all 3 sessions this week.
    public private(set) var canAdvanceWeek: Bool = false

    /// True when the user hasn't run in more than 7 days.
    public private(set) var isLapsed: Bool = false

    /// True when the user has completed the full 9-week program.
    public private(set) var hasGraduated: Bool = false

    /// True when the user has graduated and should see the free run option.
    public private(set) var showFreeRunOption: Bool = false

    /// The week the user started the program (for skipped-weeks context).
    public private(set) var startingWeek: Int = 1

    /// Whether user prefers metric units.
    public private(set) var usesMetric: Bool = false

    /// True when the user has never completed any run.
    public private(set) var isFirstRun: Bool = true

    /// Lifetime stats for the stats footer.
    public private(set) var lifetimeStats: LifetimeStats = .zero

    /// The session definition for the next run.
    public var nextSession: SessionDefinition? {
        SessionPlanLibrary.session(week: currentWeek, day: nextSessionNumber)
    }

    // MARK: - Init

    public init(dataStore: any DataStoreProviding) {
        self.dataStore = dataStore
    }

    // MARK: - Data Loading

    /// Fetches the user profile, stats, and computes dashboard state.
    public func loadData() async {
        guard let profile = try? await dataStore.fetchUserProfile() else { return }
        currentWeek = profile.currentWeek
        startingWeek = profile.startingWeek
        usesMetric = profile.usesMetric
        let completed = profile.completedSessionsThisWeek
        nextSessionNumber = min(completed + 1, 3)
        completionRingProgress = Double(completed) / 3.0
        canAdvanceWeek = completed >= 3
        hasGraduated = profile.hasGraduated
        showFreeRunOption = profile.hasGraduated

        // Load run history to determine first-run state and lifetime stats
        let allRuns = (try? await dataStore.fetchCompletedRuns(weekNumber: nil, limit: nil)) ?? []
        isFirstRun = allRuns.isEmpty
        lifetimeStats = LifetimeStats(
            totalDistance: allRuns.reduce(0) { $0 + $1.distanceMeters },
            totalDuration: allRuns.reduce(0) { $0 + $1.durationSeconds },
            totalCalories: allRuns.reduce(0) { $0 + $1.calories },
            totalRuns: allRuns.count
        )
    }

    /// Checks whether the user is lapsed (no run in > 7 days) and updates `isLapsed`.
    public func checkLapsedState() async {
        guard let lastRun = try? await dataStore.fetchLastRunDate() else {
            // No run date recorded — not lapsed (new user), or data unavailable
            isLapsed = false
            return
        }
        let daysSince = Calendar.current.dateComponents(
            [.day],
            from: lastRun,
            to: Date()
        ).day ?? 0
        isLapsed = daysSince > 7
    }

    // MARK: - Static Helpers

    /// Returns the suggested starting week based on the user's self-reported activity level.
    public static func suggestedStartWeek(for level: ActivityLevel) -> Int {
        switch level {
        case .couchPotato:    return 1
        case .somewhatActive: return 3
        case .fairlyActive:   return 5
        }
    }

    // MARK: - Computed Helpers

    /// Overall program completion percentage (0–100).
    /// Total sessions = 9 weeks × 3 sessions = 27.
    public var programCompletionPercentage: Double {
        let completedTotal = (currentWeek - 1) * 3 + Int(completionRingProgress * 3)
        return Double(completedTotal) / 27.0 * 100.0
    }
}
