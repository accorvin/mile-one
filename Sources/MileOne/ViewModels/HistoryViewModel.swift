import Foundation
import Observation

// MARK: - HistoryViewModel

/// ViewModel for the history screen.
/// Groups runs by month and computes lifetime stats.
/// GPS points are loaded lazily — only when the user taps into RunDetailView.
@MainActor
@Observable
public final class HistoryViewModel {

    // MARK: - Injected Dependencies

    private let dataStore: any DataStoreProviding

    // MARK: - Published State

    /// All completed runs grouped by their first-of-month Date.
    /// Keys are Calendar dates normalized to the first day of the month (day=1, hour=0, etc.).
    public private(set) var groupedRuns: [Date: [CompletedRunSnapshot]] = [:]

    /// Lifetime aggregate statistics across all runs.
    public private(set) var lifetimeStats: LifetimeStats = .zero

    /// GPS points for the currently-selected run (loaded on-demand).
    public private(set) var currentGPSPoints: [GPSPointSnapshot] = []

    /// Indicates a loading operation is in progress.
    public private(set) var isLoading: Bool = false

    /// Non-nil when an error has occurred.
    public private(set) var errorMessage: String?

    // MARK: - Init

    public init(dataStore: any DataStoreProviding) {
        self.dataStore = dataStore
    }

    // MARK: - Actions

    /// Loads all completed runs, groups them by month, and computes lifetime stats.
    /// Does NOT load GPS points — those are fetched lazily via `loadGPSPoints(forRunId:)`.
    public func loadRuns() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let runs = try await dataStore.fetchCompletedRuns(weekNumber: nil, limit: nil)
            groupedRuns = groupByMonth(runs)
            lifetimeStats = computeLifetimeStats(runs)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Fetches GPS points for a specific run. Called when user opens RunDetailView.
    public func loadGPSPoints(forRunId id: UUID) async {
        do {
            currentGPSPoints = try await dataStore.fetchGPSPoints(forRunId: id)
        } catch {
            currentGPSPoints = []
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Private Helpers

    private func groupByMonth(_ runs: [CompletedRunSnapshot]) -> [Date: [CompletedRunSnapshot]] {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        var result: [Date: [CompletedRunSnapshot]] = [:]
        for run in runs {
            let components = calendar.dateComponents([.year, .month], from: run.date)
            guard let monthStart = calendar.date(from: components) else { continue }
            result[monthStart, default: []].append(run)
        }
        return result
    }

    private func computeLifetimeStats(_ runs: [CompletedRunSnapshot]) -> LifetimeStats {
        guard !runs.isEmpty else { return .zero }
        return LifetimeStats(
            totalDistance: runs.reduce(0) { $0 + $1.distanceMeters },
            totalDuration: runs.reduce(0) { $0 + $1.durationSeconds },
            totalCalories: runs.reduce(0) { $0 + $1.calories },
            totalRuns: runs.count
        )
    }
}
