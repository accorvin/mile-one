#if canImport(UIKit)
import SwiftUI

// MARK: - PermissionsView

/// Onboarding step 5: Request HealthKit, location (When In Use), and notification permissions.
public struct PermissionsView: View {

    @Bindable var viewModel: OnboardingViewModel
    var onComplete: () -> Void
    @State private var isWorking = false

    public var body: some View {
        VStack(spacing: 24) {
            Text("A few permissions")
                .font(.title2.bold())

            Text("Mile One uses these to personalise your runs, track health data, and remind you to run.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 16) {
                PermissionRow(icon: "heart.fill", color: .red,
                              title: "Health & Fitness",
                              subtitle: "Read heart rate and save workouts.")
                PermissionRow(icon: "location.fill", color: .blue,
                              title: "Location (When In Use)",
                              subtitle: "Track your GPS route during runs.")
                PermissionRow(icon: "bell.fill", color: .orange,
                              title: "Notifications",
                              subtitle: "Remind you on your scheduled run days.")
            }
            .padding()

            Spacer()

            Button {
                isWorking = true
                Task {
                    try? await viewModel.completeOnboarding()
                    isWorking = false
                    onComplete()
                }
            } label: {
                if isWorking {
                    ProgressView()
                } else {
                    Text("Allow & Finish")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isWorking)
        }
        .padding()
        .navigationTitle("Permissions")
    }
}

// MARK: - PermissionRow

private struct PermissionRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 28)
            VStack(alignment: .leading) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
#endif
