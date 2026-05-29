#if canImport(AVFoundation) && canImport(UIKit)
import AVFoundation

// MARK: - AudioCoachService

/// Production implementation of `AudioCoaching` using `AVSpeechSynthesizer`.
/// Audio session activates once at run start and deactivates once at run end.
public final class AudioCoachService: NSObject, AudioCoaching, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    private let synthesizer = AVSpeechSynthesizer()

    public override init() {
        super.init()
        synthesizer.delegate = self
    }

    public func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers])
        try session.setActive(true)
    }

    public func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }

    public func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    public func cancelPending() {
        synthesizer.stopSpeaking(at: .word)
    }

    public func deactivateSession() {
        synthesizer.stopSpeaking(at: .immediate)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - AVSpeechSynthesizerDelegate

    /// Intentionally a no-op: audio session stays active until run ends.
    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // No-op: session remains active
    }
}
#endif
