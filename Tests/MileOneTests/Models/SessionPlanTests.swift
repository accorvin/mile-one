import Testing
@testable import MileOne

struct SessionPlanTests {

    @Test func allSessionsExist() {
        #expect(SessionPlanLibrary.allSessions.count == 27)
    }

    @Test func eachWeekHasThreeSessions() {
        for week in 1...9 {
            let sessions = SessionPlanLibrary.allSessions.filter { $0.week == week }
            #expect(sessions.count == 3, "Week \(week) should have 3 sessions, has \(sessions.count)")
        }
    }

    @Test func allSessionsHaveWarmUpAndCoolDown() {
        for session in SessionPlanLibrary.allSessions {
            let first = session.intervals.first
            let last  = session.intervals.last
            #expect(first?.type == .warmUp,    "\(session.id) missing warm-up")
            #expect(last?.type  == .coolDown,  "\(session.id) missing cool-down")
            #expect(first?.durationSeconds == 300, "\(session.id) warm-up should be 5 min")
            #expect(last?.durationSeconds  == 300, "\(session.id) cool-down should be 5 min")
        }
    }

    // MARK: NHS C25K source validation

    @Test func week1MatchesNHSSpec() {
        // NHS: 60s run / 90s walk × 8 = 20 min block
        guard let session = SessionPlanLibrary.session(week: 1, day: 1) else {
            Issue.record("W1D1 not found"); return
        }
        let block = session.intervals.dropFirst().dropLast()
        #expect(block.count == 16, "W1 block should be 8 run + 8 walk")

        let blockDuration = block.reduce(0) { $0 + $1.durationSeconds }
        #expect(blockDuration == 1200, "Week 1 interval block must be 20 min per NHS spec")

        for (i, interval) in block.enumerated() {
            if i % 2 == 0 {
                #expect(interval.type == .run,  "W1 block[\(i)] should be run")
                #expect(interval.durationSeconds == 60, "W1 run should be 60s")
            } else {
                #expect(interval.type == .walk, "W1 block[\(i)] should be walk")
                #expect(interval.durationSeconds == 90, "W1 walk should be 90s")
            }
        }

        // All 3 days of week 1 should be identical
        for day in 1...3 {
            guard let s = SessionPlanLibrary.session(week: 1, day: day) else {
                Issue.record("W1D\(day) not found"); continue
            }
            let sBlock = s.intervals.dropFirst().dropLast()
            #expect(sBlock.count == 16, "W1D\(day) should match NHS pattern")
        }
    }

    @Test func week4MatchesNHSSpec() {
        // NHS Week 4: 3min run / 90s walk / 5min run / 2.5min walk / 3min run / 90s walk / 5min run
        // Block: 180+90+300+150+180+90+300 = 1290s
        guard let session = SessionPlanLibrary.session(week: 4, day: 1) else {
            Issue.record("W4D1 not found"); return
        }
        let block = session.intervals.dropFirst().dropLast()
        let blockDuration = block.reduce(0) { $0 + $1.durationSeconds }
        #expect(blockDuration == 1290, "Week 4 block should be 1290s (21.5 min) per NHS spec")

        let expectedTypes:     [IntervalType] = [.run, .walk, .run, .walk, .run, .walk, .run]
        let expectedDurations: [Int]          = [180,  90,    300,  150,   180,  90,    300]
        #expect(block.count == expectedTypes.count, "W4 block should have \(expectedTypes.count) intervals")
        for (i, interval) in block.enumerated() {
            #expect(interval.type == expectedTypes[i],
                    "W4 interval \(i) type: expected \(expectedTypes[i]), got \(interval.type)")
            #expect(interval.durationSeconds == expectedDurations[i],
                    "W4 interval \(i) duration: expected \(expectedDurations[i])s, got \(interval.durationSeconds)s")
        }
    }

    @Test func week5HasDifferentDays() {
        guard let d1 = SessionPlanLibrary.session(week: 5, day: 1),
              let d3 = SessionPlanLibrary.session(week: 5, day: 3) else {
            Issue.record("W5 sessions not found"); return
        }

        // Day 3 is 20 min continuous — warmup + run + cooldown = 3 intervals
        #expect(d3.intervals.count == 3, "W5D3 should have 3 intervals (warmup + run + cooldown)")
        #expect(d3.intervals[1].durationSeconds == 1200, "W5D3 should be 20 min continuous per NHS")

        // Days 1 and 3 should differ
        #expect(
            d1.intervals.count != d3.intervals.count ||
            d1.totalDurationSeconds != d3.totalDurationSeconds,
            "W5D1 and W5D3 should have different structures"
        )
    }

    @Test func week9Is30MinContinuous() {
        for day in 1...3 {
            guard let session = SessionPlanLibrary.session(week: 9, day: day) else {
                Issue.record("W9D\(day) not found"); continue
            }
            #expect(session.intervals.count == 3, "W9D\(day) should have 3 intervals")
            #expect(session.intervals[1].type == .run, "W9D\(day) middle interval should be run")
            #expect(session.intervals[1].durationSeconds == 1800, "W9 should be 30 min continuous per NHS")
            #expect(session.totalDurationSeconds == 2400, "W9 total should be 40 min (5+30+5)")
        }
    }

    @Test func totalDurationSecondsMatchesIntervalSum() {
        for session in SessionPlanLibrary.allSessions {
            let sum = session.intervals.reduce(0) { $0 + $1.durationSeconds }
            #expect(
                session.totalDurationSeconds == sum,
                "\(session.id) totalDuration \(session.totalDurationSeconds) != interval sum \(sum)"
            )
        }
    }

    @Test func sessionLookupReturnsNilForInvalid() {
        #expect(SessionPlanLibrary.session(week: 0,  day: 1) == nil)
        #expect(SessionPlanLibrary.session(week: 10, day: 1) == nil)
        #expect(SessionPlanLibrary.session(week: 1,  day: 4) == nil)
        #expect(SessionPlanLibrary.session(week: 1,  day: 0) == nil)
    }

    @Test func sessionIdsAreUnique() {
        let ids = SessionPlanLibrary.allSessions.map(\.id)
        #expect(Set(ids).count == ids.count, "Duplicate session IDs found")
    }

    @Test func intervalIdsUniqueWithinSession() {
        for session in SessionPlanLibrary.allSessions {
            let ids = session.intervals.map(\.id)
            #expect(
                Set(ids).count == ids.count,
                "\(session.id) has duplicate interval IDs — warmUp/coolDown UUID reuse?"
            )
        }
    }
}
