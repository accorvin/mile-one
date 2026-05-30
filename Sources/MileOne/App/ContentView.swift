#if canImport(UIKit)
import SwiftUI

// MARK: - ContentView

/// Root view — routes between onboarding and the dashboard based on AppState.
public struct ContentView: View {

    @State private var appState = AppState()
    private let dataStore: any DataStoreProviding

    public init(dataStore: any DataStoreProviding) {
        self.dataStore = dataStore
    }

    public var body: some View {
        Group {
            if appState.hasCompletedOnboarding {
                DashboardView(dataStore: dataStore)
            } else {
                OnboardingContainerView(dataStore: dataStore) {
                    appState.hasCompletedOnboarding = true
                }
            }
        }
        .task {
            // On launch, check if onboarding was already completed.
            if let profile = try? await dataStore.fetchUserProfile() {
                appState.hasCompletedOnboarding = profile.hasCompletedOnboarding
            }
        }
    }
}
#endif
