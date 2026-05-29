import Foundation

// MARK: - IntervalType

public enum IntervalType: String, Codable, Sendable {
    case warmUp = "warmUp"
    case run = "run"
    case walk = "walk"
    case coolDown = "coolDown"
}

// MARK: - BiologicalSex

public enum BiologicalSex: String, Codable, Sendable {
    case male = "male"
    case female = "female"
}

// MARK: - EffortRating

public enum EffortRating: String, Codable, CaseIterable, Sendable {
    case tooEasy = "tooEasy"
    case justRight = "justRight"
    case tooHard = "tooHard"

    public var label: String {
        switch self {
        case .tooEasy: return "Too Easy"
        case .justRight: return "Just Right"
        case .tooHard: return "Too Hard"
        }
    }
}

// MARK: - DrawMode

public enum DrawMode: String, Codable, Sendable {
    case roadSnap = "roadSnap"
    case freeDraw = "freeDraw"
}

// MARK: - ActivityLevel

public enum ActivityLevel: String, Sendable {
    case couchPotato    // → Week 1
    case somewhatActive // → Week 2–3
    case fairlyActive   // → Week 4–5
}
