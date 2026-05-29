import Foundation

// MARK: - AudioCue

/// Predefined coaching cues spoken during a run session.
public enum AudioCue: String, CaseIterable, Sendable {
    case warmUpStart
    case runStart
    case walkStart
    case coolDownStart
    case halfway
    case lastInterval
    case runComplete

    public var text: String {
        switch self {
        case .warmUpStart:   return "Start your warm-up walk."
        case .runStart:      return "Time to run!"
        case .walkStart:     return "Take a walk break."
        case .coolDownStart: return "Great work! Begin your cool-down walk."
        case .halfway:       return "You're halfway through! Keep it up!"
        case .lastInterval:  return "Last interval — finish strong!"
        case .runComplete:   return "Congratulations! You've completed your run."
        }
    }
}
