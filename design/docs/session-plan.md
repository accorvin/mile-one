← [Back to Index](README.md)

# Mile One — Session Plan (Static Data)

## 6. Session Plan (Static Data)

All 27 sessions defined as a static array. Not stored in the database.

> **Validation note:** The 27-session interval table below should be validated against the
> [NHS Couch to 5K programme](https://www.nhs.uk/live-well/exercise/running-and-aerobic-exercises/get-running-with-couch-to-5k/)
> before shipping. Any typo in durations becomes a production bug with no server-side fix.

```swift
struct SessionPlanLibrary {
    
    static let allSessions: [SessionDefinition] = {
        var sessions: [SessionDefinition] = []
        
        let warmUp = Interval(type: .warmUp, durationSeconds: 300)
        let coolDown = Interval(type: .coolDown, durationSeconds: 300)
        
        // MARK: - Week 1 (all 3 days identical)
        // 60s run / 90s walk × 8
        for day in 1...3 {
            var intervals = [warmUp]
            for _ in 1...8 {
                intervals.append(Interval(type: .run, durationSeconds: 60))
                intervals.append(Interval(type: .walk, durationSeconds: 90))
            }
            intervals.append(coolDown)
            sessions.append(SessionDefinition(id: "W1D\(day)", week: 1, dayInWeek: day, intervals: intervals))
        }
        
        // MARK: - Week 2 (all 3 days identical)
        // 90s run / 2 min walk × 6
        for day in 1...3 {
            var intervals = [warmUp]
            for _ in 1...6 {
                intervals.append(Interval(type: .run, durationSeconds: 90))
                intervals.append(Interval(type: .walk, durationSeconds: 120))
            }
            intervals.append(coolDown)
            sessions.append(SessionDefinition(id: "W2D\(day)", week: 2, dayInWeek: day, intervals: intervals))
        }
        
        // MARK: - Week 3 (all 3 days identical)
        // 90s run / 90s walk / 3 min run / 3 min walk × 2
        for day in 1...3 {
            var intervals = [warmUp]
            for _ in 1...2 {
                intervals.append(Interval(type: .run, durationSeconds: 90))
                intervals.append(Interval(type: .walk, durationSeconds: 90))
                intervals.append(Interval(type: .run, durationSeconds: 180))
                intervals.append(Interval(type: .walk, durationSeconds: 180))
            }
            intervals.append(coolDown)
            sessions.append(SessionDefinition(id: "W3D\(day)", week: 3, dayInWeek: day, intervals: intervals))
        }
        
        // MARK: - Week 4 (all 3 days identical)
        // 3 min run / 90s walk / 5 min run / 2.5 min walk / 3 min run / 90s walk / 5 min run
        // NOTE: Interval block = 180+90+300+150+180+90+300 = 1290s = 21.5 min.
        // requirements.md lists this as "23 min" — that total is incorrect.
        // The individual intervals match the NHS C25K standard; the code is correct.
        // If the UI displays an expected duration, use 21.5 min (or round to 22 min), not 23.
        for day in 1...3 {
            let intervals = [
                warmUp,
                Interval(type: .run, durationSeconds: 180),
                Interval(type: .walk, durationSeconds: 90),
                Interval(type: .run, durationSeconds: 300),
                Interval(type: .walk, durationSeconds: 150),
                Interval(type: .run, durationSeconds: 180),
                Interval(type: .walk, durationSeconds: 90),
                Interval(type: .run, durationSeconds: 300),
                coolDown
            ]
            sessions.append(SessionDefinition(id: "W4D\(day)", week: 4, dayInWeek: day, intervals: intervals))
        }
        
        // MARK: - Week 5
        // Day 1: 5 min run / 3 min walk × 3
        do {
            var intervals = [warmUp]
            for _ in 1...3 {
                intervals.append(Interval(type: .run, durationSeconds: 300))
                intervals.append(Interval(type: .walk, durationSeconds: 180))
            }
            intervals.append(coolDown)
            sessions.append(SessionDefinition(id: "W5D1", week: 5, dayInWeek: 1, intervals: intervals))
        }
        // Day 2: 8 min run / 5 min walk / 8 min run
        do {
            let intervals = [
                warmUp,
                Interval(type: .run, durationSeconds: 480),
                Interval(type: .walk, durationSeconds: 300),
                Interval(type: .run, durationSeconds: 480),
                coolDown
            ]
            sessions.append(SessionDefinition(id: "W5D2", week: 5, dayInWeek: 2, intervals: intervals))
        }
        // Day 3: 20 min continuous run
        do {
            let intervals = [
                warmUp,
                Interval(type: .run, durationSeconds: 1200),
                coolDown
            ]
            sessions.append(SessionDefinition(id: "W5D3", week: 5, dayInWeek: 3, intervals: intervals))
        }
        
        // MARK: - Week 6
        // Day 1: 5 min run / 3 min walk / 8 min run / 3 min walk / 5 min run
        do {
            let intervals = [
                warmUp,
                Interval(type: .run, durationSeconds: 300),
                Interval(type: .walk, durationSeconds: 180),
                Interval(type: .run, durationSeconds: 480),
                Interval(type: .walk, durationSeconds: 180),
                Interval(type: .run, durationSeconds: 300),
                coolDown
            ]
            sessions.append(SessionDefinition(id: "W6D1", week: 6, dayInWeek: 1, intervals: intervals))
        }
        // Day 2: 10 min run / 3 min walk / 10 min run
        do {
            let intervals = [
                warmUp,
                Interval(type: .run, durationSeconds: 600),
                Interval(type: .walk, durationSeconds: 180),
                Interval(type: .run, durationSeconds: 600),
                coolDown
            ]
            sessions.append(SessionDefinition(id: "W6D2", week: 6, dayInWeek: 2, intervals: intervals))
        }
        // Day 3: 22 min continuous run
        do {
            let intervals = [
                warmUp,
                Interval(type: .run, durationSeconds: 1320),
                coolDown
            ]
            sessions.append(SessionDefinition(id: "W6D3", week: 6, dayInWeek: 3, intervals: intervals))
        }
        
        // MARK: - Week 7 (all 3 days identical)
        // 25 min continuous run
        for day in 1...3 {
            let intervals = [
                warmUp,
                Interval(type: .run, durationSeconds: 1500),
                coolDown
            ]
            sessions.append(SessionDefinition(id: "W7D\(day)", week: 7, dayInWeek: day, intervals: intervals))
        }
        
        // MARK: - Week 8 (all 3 days identical)
        // 28 min continuous run
        for day in 1...3 {
            let intervals = [
                warmUp,
                Interval(type: .run, durationSeconds: 1680),
                coolDown
            ]
            sessions.append(SessionDefinition(id: "W8D\(day)", week: 8, dayInWeek: day, intervals: intervals))
        }
        
        // MARK: - Week 9 (all 3 days identical)
        // 30 min continuous run
        for day in 1...3 {
            let intervals = [
                warmUp,
                Interval(type: .run, durationSeconds: 1800),
                coolDown
            ]
            sessions.append(SessionDefinition(id: "W9D\(day)", week: 9, dayInWeek: day, intervals: intervals))
        }
        
        return sessions
    }()
    
    /// Get the session definition for a specific week and day.
    static func session(week: Int, day: Int) -> SessionDefinition? {
        allSessions.first { $0.week == week && $0.dayInWeek == day }
    }
}
```

---

