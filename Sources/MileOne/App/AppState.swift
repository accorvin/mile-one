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

    public init(
        hasCompletedOnboarding: Bool = false,
        showLapsedRecovery: Bool = false
    ) {
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.showLapsedRecovery = showLapsedRecovery
    }
}
