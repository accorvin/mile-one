import Foundation

// MARK: - AudioCoaching
// Stub protocol for Phase 1. Full implementation comes in Phase 3 (Audio Coach + In-Run UI).

/// Abstracts AVSpeechSynthesizer for testability.
public protocol AudioCoaching: AnyObject, Sendable {
    /// Configure the audio session for playback alongside other audio.
    func configureAudioSession() throws
    /// Speak a coaching cue aloud.
    func speak(_ text: String)
    /// Stop all current speech immediately.
    func stop()
    /// Deactivate the audio session when the run ends.
    func deactivateSession()
}
