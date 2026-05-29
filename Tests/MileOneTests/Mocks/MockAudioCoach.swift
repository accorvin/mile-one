@testable import MileOne

final class MockAudioCoach: AudioCoaching, @unchecked Sendable {
    private(set) var spokenTexts: [String] = []
    private(set) var configuredSession = false
    private(set) var stopped = false

    func configureAudioSession() throws { configuredSession = true }
    func speak(_ text: String) { spokenTexts.append(text) }
    func stop() { stopped = true }
    func deactivateSession() {}
    func cancelPending() {}
}
