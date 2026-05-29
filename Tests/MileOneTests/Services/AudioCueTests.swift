import Testing
@testable import MileOne

@Suite("AudioCue Tests")
struct AudioCueTests {

    @Test("All audio cues have non-empty text")
    func allAudioCuesAreDefined() {
        for cue in AudioCue.allCases {
            #expect(!cue.text.isEmpty, "AudioCue.\(cue.rawValue) has empty text")
        }
    }

    @Test("Warm-up cue text matches expected string")
    func warmUpCueText() {
        #expect(AudioCue.warmUpStart.text == "Start your warm-up walk.")
    }

    @Test("Run complete cue text matches expected string")
    func runCompleteCueText() {
        #expect(AudioCue.runComplete.text == "Congratulations! You've completed your run.")
    }
}
