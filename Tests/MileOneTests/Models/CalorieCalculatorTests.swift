import Foundation
import Testing
@testable import MileOne

struct CalorieCalculatorTests {

    @Test func pureWalkingSession() {
        // warmUp (300s) + walk (600s) + coolDown (300s) = 1200s, all walking MET
        let intervals = [
            Interval(type: .warmUp,   durationSeconds: 300),
            Interval(type: .walk,     durationSeconds: 600),
            Interval(type: .coolDown, durationSeconds: 300),
        ]
        // 70kg × 3.5 MET × (1200/3600) h = 81.67 cal
        let cal = CalorieCalculator.calculate(
            weightKg: 70, intervals: intervals, actualDurationSeconds: 1200
        )
        #expect(abs(cal - 81.67) < 1.0, "Expected ~81.67 kcal, got \(cal)")
    }

    @Test func pureRunningSession() {
        let intervals = [
            Interval(type: .run, durationSeconds: 1800),
        ]
        // 70kg × 8.0 MET × 0.5 h = 280 cal
        let cal = CalorieCalculator.calculate(
            weightKg: 70, intervals: intervals, actualDurationSeconds: 1800
        )
        #expect(abs(cal - 280.0) < 1.0, "Expected ~280 kcal, got \(cal)")
    }

    @Test func mixedIntervalSession() {
        // warmUp 300s, run 60s, walk 90s, coolDown 300s = 750s total planned
        // run fraction = 60/750, walk fraction = 690/750
        let intervals = [
            Interval(type: .warmUp,   durationSeconds: 300),
            Interval(type: .run,      durationSeconds:  60),
            Interval(type: .walk,     durationSeconds:  90),
            Interval(type: .coolDown, durationSeconds: 300),
        ]
        let cal = CalorieCalculator.calculate(
            weightKg: 70, intervals: intervals, actualDurationSeconds: 750
        )
        // Should be somewhere between pure walking and pure running for this duration
        let pureWalk = 70.0 * 3.5 * (750.0 / 3600.0)
        let pureRun  = 70.0 * 8.0 * (750.0 / 3600.0)
        #expect(cal > pureWalk, "Mixed session should burn more than pure walking")
        #expect(cal < pureRun,  "Mixed session should burn less than pure running")
        #expect(cal > 50 && cal < 65, "Expected 50–65 kcal for this mixed session, got \(cal)")
    }

    @Test func zeroWeightReturnsZero() {
        let intervals = [Interval(type: .run, durationSeconds: 1800)]
        let cal = CalorieCalculator.calculate(
            weightKg: 0, intervals: intervals, actualDurationSeconds: 1800
        )
        #expect(cal == 0, "Zero weight should return 0 calories")
    }

    @Test func negativeWeightReturnsZero() {
        let intervals = [Interval(type: .run, durationSeconds: 1800)]
        let cal = CalorieCalculator.calculate(
            weightKg: -70, intervals: intervals, actualDurationSeconds: 1800
        )
        #expect(cal == 0, "Negative weight should return 0 calories")
    }

    @Test func emptyIntervalsReturnsZero() {
        let cal = CalorieCalculator.calculate(
            weightKg: 70, intervals: [], actualDurationSeconds: 1800
        )
        #expect(cal == 0, "Empty intervals should return 0 calories")
    }

    @Test func zeroDurationReturnsZero() {
        let intervals = [Interval(type: .run, durationSeconds: 1800)]
        let cal = CalorieCalculator.calculate(
            weightKg: 70, intervals: intervals, actualDurationSeconds: 0
        )
        #expect(cal == 0, "Zero duration should return 0 calories")
    }

    @Test func pausedRunUsesActualDurationNotPlanned() {
        // Planned session: warmup 300s + run 1200s + cooldown 300s = 1800s
        // User paused extensively, actual active time = 1200s
        let intervals = [
            Interval(type: .warmUp,   durationSeconds: 300),
            Interval(type: .run,      durationSeconds: 1200),
            Interval(type: .coolDown, durationSeconds: 300),
        ]
        let calPlanned = CalorieCalculator.calculate(
            weightKg: 70, intervals: intervals, actualDurationSeconds: 1800
        )
        let calActual = CalorieCalculator.calculate(
            weightKg: 70, intervals: intervals, actualDurationSeconds: 1200
        )
        // Shorter actual duration → fewer calories
        #expect(calActual < calPlanned, "Paused run should burn fewer calories than full planned duration")
        #expect(calActual > 0, "Paused run should still burn some calories")

        // Should scale exactly proportionally (same MET weighting, different time)
        let ratio = calActual / calPlanned
        #expect(abs(ratio - (1200.0 / 1800.0)) < 0.001,
                "Calorie ratio should match duration ratio for same interval structure")
    }

    @Test func extremeWeightProducesReasonableCalories() {
        let intervals = [Interval(type: .run, durationSeconds: 1800)]

        let calLight = CalorieCalculator.calculate(
            weightKg: 40, intervals: intervals, actualDurationSeconds: 1800
        )
        let calHeavy = CalorieCalculator.calculate(
            weightKg: 150, intervals: intervals, actualDurationSeconds: 1800
        )

        #expect(calLight > 0, "Light person should burn calories")
        #expect(calHeavy > calLight, "Heavier person should burn more calories")

        // Should scale linearly with weight (same MET × time, different kg)
        let expectedRatio = 150.0 / 40.0
        let actualRatio   = calHeavy / calLight
        #expect(abs(actualRatio - expectedRatio) < 0.001,
                "Calorie scaling should be linear with weight: expected ratio \(expectedRatio), got \(actualRatio)")
    }
}
