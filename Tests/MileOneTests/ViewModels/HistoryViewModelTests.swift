import Testing
import Foundation
@testable import MileOne

@MainActor
struct HistoryViewModelTests {

    @Test func runsGroupedByMonth() async throws {
        let mockStore = MockDataStore()
        await mockStore.setMockRuns([
            makeRun(week: 1, session: 1, date: makeDate(2026, 5, 1)),
            makeRun(week: 1, session: 2, date: makeDate(2026, 5, 15)),
            makeRun(week: 2, session: 1, date: makeDate(2026, 6, 1)),
        ])

        let vm = HistoryViewModel(dataStore: mockStore)
        await vm.loadRuns()

        #expect(vm.groupedRuns.count == 2, "Should group into May and June")

        let mayKey = vm.groupedRuns.keys.first { key in
            Calendar.current.component(.month, from: key) == 5
        }
        #expect(vm.groupedRuns[mayKey!]?.count == 2)
    }

    @Test func lifetimeStatsAccumulate() async throws {
        let mockStore = MockDataStore()
        await mockStore.setMockRuns([
            makeRun(distance: 2500, duration: 1800, calories: 200),
            makeRun(distance: 3000, duration: 2100, calories: 250),
            makeRun(distance: 2800, duration: 1950, calories: 220),
        ])

        let vm = HistoryViewModel(dataStore: mockStore)
        await vm.loadRuns()

        #expect(vm.lifetimeStats.totalDistance == 8300)
        #expect(vm.lifetimeStats.totalDuration == 5850)
        #expect(vm.lifetimeStats.totalCalories == 670)
        #expect(vm.lifetimeStats.totalRuns == 3)
    }

    @Test func emptyHistoryShowsZeroStats() async throws {
        let mockStore = MockDataStore()
        await mockStore.setMockRuns([])

        let vm = HistoryViewModel(dataStore: mockStore)
        await vm.loadRuns()

        #expect(vm.lifetimeStats.totalRuns == 0)
        #expect(vm.lifetimeStats.totalDistance == 0)
        #expect(vm.groupedRuns.isEmpty)
    }

    @Test func gpsPointsFetchedOnDetailLoad() async throws {
        // GPS points should NOT be loaded when showing the list —
        // only when the user taps into RunDetailView
        let mockStore = MockDataStore()
        let run = makeRun(week: 1, session: 1)
        await mockStore.setMockRuns([run])
        await mockStore.setMockGPSPoints([
            GPSPointSnapshot(latitude: 35.78, longitude: -78.64, altitude: 100,
                             timestamp: Date(), speed: 2.5, horizontalAccuracy: 5)
        ])

        let vm = HistoryViewModel(dataStore: mockStore)
        await vm.loadRuns()

        // List load should not fetch GPS points
        let gpsFetched = await mockStore.gpsPointsFetched
        #expect(gpsFetched == false, "GPS points must not be fetched for list view")

        // Detail load should fetch GPS points
        await vm.loadGPSPoints(forRunId: run.id)
        let gpsFetchedAfter = await mockStore.gpsPointsFetched
        #expect(gpsFetchedAfter == true)
    }

    // MARK: - Helpers

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// Creates a CompletedRunSnapshot for testing.
    private func makeRun(
        week: Int = 1,
        session: Int = 1,
        date: Date = Date(),
        distance: Double = 0,
        duration: Double = 0,
        calories: Double = 0
    ) -> CompletedRunSnapshot {
        CompletedRunSnapshot(
            id: UUID(),
            weekNumber: week,
            sessionNumber: session,
            date: date,
            distanceMeters: distance,
            durationSeconds: duration,
            calories: calories,
            averagePaceSecondsPerKm: nil,
            averageHeartRate: nil,
            effortRating: nil,
            isFreeRun: false
        )
    }
}
