import Testing
import SwiftUI
@testable import MileOne

@MainActor
@Suite("RunViewModel Tests")
struct RunViewModelTests {

    // MARK: - Helpers

    private func makeSnapshot(
        type: IntervalType = .run,
        label: String = "Run",
        remaining: TimeInterval = 60,
        elapsed: TimeInterval = 120,
        distance: Double = 500,
        index: Int = 2,
        total: Int = 8,
        isRunning: Bool = true,
        isPaused: Bool = false,
        isComplete: Bool = false,
        nextType: IntervalType? = .walk
    ) -> RunSnapshot {
        RunSnapshot(
            currentIntervalType: type,
            currentIntervalLabel: label,
            intervalRemaining: remaining,
            totalElapsed: elapsed,
            totalDistance: distance,
            currentIntervalIndex: index,
            totalIntervals: total,
            isRunning: isRunning,
            isPaused: isPaused,
            isComplete: isComplete,
            nextIntervalType: nextType
        )
    }

    // MARK: - Tests

    @Test("ViewModel receives snapshot and exposes all fields")
    func viewModelReceivesSnapshots() {
        let vm = RunViewModel()
        let snap = makeSnapshot()
        vm.update(with: snap)

        #expect(vm.snapshot.currentIntervalType == .run)
        #expect(vm.snapshot.currentIntervalLabel == "Run")
        #expect(vm.snapshot.intervalRemaining == 60)
        #expect(vm.snapshot.totalElapsed == 120)
        #expect(vm.snapshot.totalDistance == 500)
        #expect(vm.snapshot.currentIntervalIndex == 2)
        #expect(vm.snapshot.totalIntervals == 8)
        #expect(vm.snapshot.isRunning == true)
        #expect(vm.snapshot.isPaused == false)
        #expect(vm.snapshot.isComplete == false)
        #expect(vm.snapshot.nextIntervalType == .walk)
    }

    @Test("Time formatting: 90s remaining → 1:30, 725s elapsed → 12:05")
    func viewModelFormatsTimeCorrectly() {
        let vm = RunViewModel()
        vm.update(with: makeSnapshot(remaining: 90, elapsed: 725))

        #expect(vm.formattedIntervalRemaining == "1:30")
        #expect(vm.formattedTotalElapsed == "12:05")
    }

    @Test("Session progress: index 4 of 8 = 0.5")
    func viewModelComputesProgress() {
        let vm = RunViewModel()
        vm.update(with: makeSnapshot(index: 4, total: 8))

        #expect(vm.sessionProgress == 0.5)
    }

    @Test("Empty snapshot has sane defaults")
    func emptySnapshotDefaults() {
        let snap = RunSnapshot.empty

        #expect(snap.currentIntervalType == .warmUp)
        #expect(snap.currentIntervalLabel == "—")
        #expect(snap.intervalRemaining == 0)
        #expect(snap.totalElapsed == 0)
        #expect(snap.totalDistance == 0)
        #expect(snap.currentIntervalIndex == 0)
        #expect(snap.totalIntervals == 0)
        #expect(snap.isRunning == false)
        #expect(snap.isPaused == false)
        #expect(snap.isComplete == false)
        #expect(snap.nextIntervalType == nil)
    }

    @Test("Distance formatted in miles: 1609.344m = 1.00 mi")
    func distanceFormattedInMiles() {
        let vm = RunViewModel()
        vm.update(with: makeSnapshot(distance: 1_609.344))

        #expect(vm.formattedDistance == "1.00 mi")
    }

    @Test("Zero totalIntervals doesn't crash progress (division safe)")
    func zeroDivisionSafe() {
        let vm = RunViewModel()
        vm.update(with: makeSnapshot(index: 0, total: 0))

        #expect(vm.sessionProgress == 0)
    }
}
