#if canImport(UIKit)
import SwiftUI

// MARK: - OnboardingContainerView

/// Hosts the multi-step onboarding flow using a NavigationStack.
public struct OnboardingContainerView: View {

    @State private var viewModel: OnboardingViewModel
    var onComplete: () -> Void

    public init(dataStore: any DataStoreProviding, onComplete: @escaping () -> Void) {
        _viewModel = State(initialValue: OnboardingViewModel(dataStore: dataStore))
        self.onComplete = onComplete
    }

    public var body: some View {
        NavigationStack {
            currentStepView()
                .animation(.easeInOut, value: viewModel.currentStep)
        }
    }

    @ViewBuilder
    private func currentStepView() -> some View {
        switch viewModel.currentStep {
        case .welcome:
            WelcomeView { viewModel.advance() }
        case .biometrics:
            BiometricsView(viewModel: viewModel)
        case .activityLevel:
            ActivityLevelView(viewModel: viewModel)
        case .schedule:
            ScheduleView(viewModel: viewModel)
        case .permissions:
            PermissionsView(viewModel: viewModel, onComplete: onComplete)
        }
    }
}
#endif
