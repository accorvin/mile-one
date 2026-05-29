import Foundation

// MARK: - SessionPlanLibrary

/// Contains all 27 Couch-to-5K sessions (9 weeks × 3 days) following the NHS C25K spec.
///
/// Each Interval has its own unique UUID — warmUp/coolDown instances are NEVER shared
/// across sessions, ensuring SwiftUI ForEach and list diffing work correctly.
public enum SessionPlanLibrary {

    // MARK: - Public API

    /// All 27 sessions, ordered week 1 day 1 → week 9 day 3.
    public static let allSessions: [SessionDefinition] = {
        var sessions: [SessionDefinition] = []
        sessions += week1()
        sessions += week2()
        sessions += week3()
        sessions += week4()
        sessions += week5()
        sessions += week6()
        sessions += week7()
        sessions += week8()
        sessions += week9()
        return sessions
    }()

    /// Look up a session by week (1–9) and day (1–3). Returns nil for out-of-range inputs.
    public static func session(week: Int, day: Int) -> SessionDefinition? {
        guard (1...9).contains(week), (1...3).contains(day) else { return nil }
        return allSessions.first { $0.week == week && $0.dayInWeek == day }
    }

    // MARK: - Private Interval Factories
    // Each call creates a NEW Interval with a fresh UUID — do not cache or share these.

    private static func warmUp() -> Interval { Interval(type: .warmUp, durationSeconds: 300) }
    private static func coolDown() -> Interval { Interval(type: .coolDown, durationSeconds: 300) }
    private static func run(_ seconds: Int) -> Interval { Interval(type: .run, durationSeconds: seconds) }
    private static func walk(_ seconds: Int) -> Interval { Interval(type: .walk, durationSeconds: seconds) }

    // MARK: - Week Builders

    // Week 1: 5min warmup + (60s run / 90s walk) × 8 + 5min cooldown
    private static func week1() -> [SessionDefinition] {
        (1...3).map { day in
            var intervals: [Interval] = [warmUp()]
            for _ in 1...8 {
                intervals.append(run(60))
                intervals.append(walk(90))
            }
            intervals.append(coolDown())
            return SessionDefinition(id: "W1D\(day)", week: 1, dayInWeek: day, intervals: intervals)
        }
    }

    // Week 2: 5min warmup + (90s run / 2min walk) × 6 + 5min cooldown
    private static func week2() -> [SessionDefinition] {
        (1...3).map { day in
            var intervals: [Interval] = [warmUp()]
            for _ in 1...6 {
                intervals.append(run(90))
                intervals.append(walk(120))
            }
            intervals.append(coolDown())
            return SessionDefinition(id: "W2D\(day)", week: 2, dayInWeek: day, intervals: intervals)
        }
    }

    // Week 3: 5min warmup + (90s run / 90s walk / 3min run / 3min walk) × 2 + 5min cooldown
    private static func week3() -> [SessionDefinition] {
        (1...3).map { day in
            var intervals: [Interval] = [warmUp()]
            for _ in 1...2 {
                intervals.append(run(90))
                intervals.append(walk(90))
                intervals.append(run(180))
                intervals.append(walk(180))
            }
            intervals.append(coolDown())
            return SessionDefinition(id: "W3D\(day)", week: 3, dayInWeek: day, intervals: intervals)
        }
    }

    // Week 4: 5min warmup + 3min run / 90s walk / 5min run / 2.5min walk / 3min run / 90s walk / 5min run + 5min cooldown
    // Block total: 180+90+300+150+180+90+300 = 1290s
    private static func week4() -> [SessionDefinition] {
        (1...3).map { day in
            let intervals: [Interval] = [
                warmUp(),
                run(180), walk(90), run(300), walk(150),
                run(180), walk(90), run(300),
                coolDown()
            ]
            return SessionDefinition(id: "W4D\(day)", week: 4, dayInWeek: day, intervals: intervals)
        }
    }

    // Week 5:
    //   Day 1: 5min warmup + (5min run / 3min walk) × 3 + 5min cooldown
    //   Day 2: 5min warmup + 8min run / 5min walk / 8min run + 5min cooldown
    //   Day 3: 5min warmup + 20min continuous run + 5min cooldown
    private static func week5() -> [SessionDefinition] {
        let d1 = SessionDefinition(
            id: "W5D1", week: 5, dayInWeek: 1,
            intervals: [
                warmUp(),
                run(300), walk(180),
                run(300), walk(180),
                run(300), walk(180),
                coolDown()
            ]
        )
        let d2 = SessionDefinition(
            id: "W5D2", week: 5, dayInWeek: 2,
            intervals: [
                warmUp(),
                run(480), walk(300), run(480),
                coolDown()
            ]
        )
        let d3 = SessionDefinition(
            id: "W5D3", week: 5, dayInWeek: 3,
            intervals: [warmUp(), run(1200), coolDown()]
        )
        return [d1, d2, d3]
    }

    // Week 6:
    //   Day 1: 5min warmup + 5min run / 3min walk / 8min run / 3min walk / 5min run + 5min cooldown
    //   Day 2: 5min warmup + 10min run / 3min walk / 10min run + 5min cooldown
    //   Day 3: 5min warmup + 22min continuous run + 5min cooldown
    private static func week6() -> [SessionDefinition] {
        let d1 = SessionDefinition(
            id: "W6D1", week: 6, dayInWeek: 1,
            intervals: [
                warmUp(),
                run(300), walk(180), run(480), walk(180), run(300),
                coolDown()
            ]
        )
        let d2 = SessionDefinition(
            id: "W6D2", week: 6, dayInWeek: 2,
            intervals: [
                warmUp(),
                run(600), walk(180), run(600),
                coolDown()
            ]
        )
        let d3 = SessionDefinition(
            id: "W6D3", week: 6, dayInWeek: 3,
            intervals: [warmUp(), run(1320), coolDown()]
        )
        return [d1, d2, d3]
    }

    // Week 7: 5min warmup + 25min continuous run + 5min cooldown
    private static func week7() -> [SessionDefinition] {
        (1...3).map { day in
            SessionDefinition(
                id: "W7D\(day)", week: 7, dayInWeek: day,
                intervals: [warmUp(), run(1500), coolDown()]
            )
        }
    }

    // Week 8: 5min warmup + 28min continuous run + 5min cooldown
    private static func week8() -> [SessionDefinition] {
        (1...3).map { day in
            SessionDefinition(
                id: "W8D\(day)", week: 8, dayInWeek: day,
                intervals: [warmUp(), run(1680), coolDown()]
            )
        }
    }

    // Week 9: 5min warmup + 30min continuous run + 5min cooldown
    private static func week9() -> [SessionDefinition] {
        (1...3).map { day in
            SessionDefinition(
                id: "W9D\(day)", week: 9, dayInWeek: day,
                intervals: [warmUp(), run(1800), coolDown()]
            )
        }
    }
}
