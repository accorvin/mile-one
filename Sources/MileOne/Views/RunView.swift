import SwiftUI

// MARK: - RunView

/// Top-level run view: swipe between TimerView and RunMapView.
@available(iOS 17.0, *)
public struct RunView: View {
    @Bindable var viewModel: RunViewModel
    var onPauseResume: () -> Void
    var onEndRun: () -> Void

    public init(
        viewModel: RunViewModel,
        onPauseResume: @escaping () -> Void,
        onEndRun: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onPauseResume = onPauseResume
        self.onEndRun = onEndRun
    }

    public var body: some View {
        TabView {
            TimerView(
                viewModel: viewModel,
                onPauseResume: onPauseResume,
                onEndRun: onEndRun
            )

            RunMapView(viewModel: viewModel)
        }
#if os(iOS)
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
#endif
        .ignoresSafeArea()
    }
}
