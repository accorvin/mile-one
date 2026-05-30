#if canImport(UIKit)
import SwiftUI

// MARK: - WelcomeView

/// Onboarding step 1: Welcome screen with health disclaimer.
public struct WelcomeView: View {

    var onContinue: () -> Void

    public var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "figure.run")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundStyle(Color.accentColor)

            Text("Welcome to Mile One")
                .font(.largeTitle.bold())

            Text("Your 9-week journey from couch to 5K starts here.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Spacer()

            // Health disclaimer — required on welcome screen
            Text("Consult a physician before starting any new exercise program, especially if you have any medical conditions.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Button("Let's get started") {
                onContinue()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.bottom)
        }
        .padding()
    }
}
#endif
