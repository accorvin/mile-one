import SwiftUI

// MARK: - TimerView

/// Primary in-run view showing interval countdown, progress, and controls.
public struct TimerView: View {
    @Bindable var viewModel: RunViewModel
    var onPauseResume: () -> Void
    var onEndRun: () -> Void

    @State private var showEndConfirmation = false

    private let darkBackground = Color(red: 28/255, green: 28/255, blue: 30/255) // #1C1C1E

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
        ZStack {
            darkBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                // Session progress bar
                ProgressView(value: viewModel.sessionProgress)
                    .tint(viewModel.intervalColor)
                    .padding(.horizontal)

                // Interval label
                Text(viewModel.snapshot.currentIntervalLabel)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(viewModel.intervalColor)

                // Large countdown timer
                Text(viewModel.formattedIntervalRemaining)
                    .font(.system(size: 80, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())

                // Next interval chip
                if let next = viewModel.nextIntervalLabel {
                    Text("Next: \(next)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.1), in: Capsule())
                }

                // Distance and elapsed time row
                HStack(spacing: 40) {
                    VStack(spacing: 4) {
                        Text(viewModel.formattedDistance)
                            .font(.title3.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.white)
                        Text("Distance")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    VStack(spacing: 4) {
                        Text(viewModel.formattedTotalElapsed)
                            .font(.title3.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.white)
                        Text("Elapsed")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding(.top, 8)

                Spacer()

                // Control buttons
                HStack(spacing: 64) {
                    // Pause / Resume
                    Button(action: onPauseResume) {
                        Image(systemName: viewModel.snapshot.isPaused ? "play.fill" : "pause.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .frame(width: 72, height: 72)
                            .background(viewModel.intervalColor, in: Circle())
                    }

                    // End Run
                    Button {
                        showEndConfirmation = true
                    } label: {
                        Image(systemName: "stop.fill")
                            .font(.title)
                            .foregroundStyle(.white)
                            .frame(width: 72, height: 72)
                            .background(.red, in: Circle())
                    }
                }
                .padding(.bottom, 40)
            }
            .padding(.top, 20)
        }
        .alert("End Run?", isPresented: $showEndConfirmation) {
            Button("End Run", role: .destructive, action: onEndRun)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to end this run?")
        }
    }
}
