#if canImport(UIKit)
import SwiftUI

// MARK: - ActivityLevelView

/// Onboarding step 3: Select current activity level.
public struct ActivityLevelView: View {

    @Bindable var viewModel: OnboardingViewModel

    private let options: [(ActivityLevel, String, String)] = [
        (.couchPotato, "Couch Potato", "I rarely exercise — start from the very beginning."),
        (.somewhatActive, "Somewhat Active", "I walk or exercise occasionally."),
        (.fairlyActive, "Fairly Active", "I exercise regularly and feel comfortable running."),
    ]

    public var body: some View {
        VStack(spacing: 16) {
            Text("How active are you right now?")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .padding(.top)

            ForEach(options, id: \.0.rawValue) { level, title, subtitle in
                Button {
                    viewModel.activityLevel = level
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(title).font(.headline)
                            Text(subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if viewModel.activityLevel == level {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(viewModel.activityLevel == level ? Color.accentColor : Color.secondary.opacity(0.3))
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button("Continue") { viewModel.advance() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding()
        .navigationTitle("Activity Level")
    }
}
#endif
