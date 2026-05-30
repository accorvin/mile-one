import Foundation
import Observation

// MARK: - AppState

/// Global application state for routing between major screens.
@Observable
public final class AppState {

    /// Whether the user has completed onboarding.
    public var hasCompletedOnboarding: Bool

    /// Whether to show the lapsed-user recovery card/flow.
    public var showLapsedRecovery: Bool

    /// Whether the run screen is currently active.
    public var isShowingRun: Bool = false
    /// The session definition being run (set before navigating to RunView).
    public var activeSession: SessionDefinition? = nil

    public init(
        hasCompletedOnboarding: Bool = false,
        showLapsedRecovery: Bool = false,
        isShowingRun: Bool = false,
        activeSession: SessionDefinition? = nil
    ) {
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.showLapsedRecovery = showLapsedRecovery
        self.isShowingRun = isShowingRun
        self.activeSession = activeSession
    }
}
