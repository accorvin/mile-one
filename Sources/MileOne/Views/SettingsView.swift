#if canImport(UIKit)
import SwiftUI

// MARK: - SettingsView

/// Form-based settings screen.
/// iCloud sync status is read-only — the setting is fixed at first launch.
public struct SettingsView: View {

    @State private var viewModel: SettingsViewModel
    @State private var showResetAlert: Bool = false

    public init(viewModel: SettingsViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            Form {
                unitsSection
                scheduleSection
                notificationsSection
                biometricsSection
                iCloudSection
                aboutSection
            }
            .navigationTitle("Settings")
            .task {
                await viewModel.loadSettings()
            }
            .alert("Reset iCloud Preference", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset App Data", role: .destructive) {
                    // iCloud sync preference reset requires full app data reset.
                    // This is intentionally left as a user action outside the app.
                }
            } message: {
                Text("Changing iCloud sync requires resetting all app data. This cannot be undone. Please delete and reinstall the app to change this setting.")
            }
        }
    }

    // MARK: - Units

    private var unitsSection: some View {
        Section("Units") {
            Toggle("Use Metric (km)", isOn: $viewModel.usesMetric)
                .onChange(of: viewModel.usesMetric) {
                    Task { await viewModel.saveSettings() }
                }
        }
    }

    // MARK: - Schedule

    private var scheduleSection: some View {
        Section("Run Schedule") {
            NavigationLink("Run Days") {
                RunDaysPickerView(selectedDays: $viewModel.runDays) {
                    Task { await viewModel.saveSettings() }
                }
            }
            Text(runDaysSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var runDaysSummary: String {
        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let selected = viewModel.runDays
            .sorted()
            .compactMap { day -> String? in
                guard day >= 1, day <= 7 else { return nil }
                return names[day - 1]
            }
        return selected.isEmpty ? "No days selected" : selected.joined(separator: ", ")
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        Section("Notifications") {
            Toggle("Run Reminders", isOn: $viewModel.remindersEnabled)
                .onChange(of: viewModel.remindersEnabled) {
                    Task { await viewModel.saveSettings() }
                }

            if viewModel.remindersEnabled {
                DatePicker(
                    "Reminder Time",
                    selection: reminderTimeBinding,
                    displayedComponents: .hourAndMinute
                )
                .onChange(of: viewModel.reminderHour) {
                    Task { await viewModel.saveSettings() }
                }
                .onChange(of: viewModel.reminderMinute) {
                    Task { await viewModel.saveSettings() }
                }
            }
        }
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                var comps = DateComponents()
                comps.hour = viewModel.reminderHour
                comps.minute = viewModel.reminderMinute
                return Calendar.current.date(from: comps) ?? Date()
            },
            set: { date in
                let cal = Calendar.current
                viewModel.reminderHour = cal.component(.hour, from: date)
                viewModel.reminderMinute = cal.component(.minute, from: date)
            }
        )
    }

    // MARK: - Biometrics

    private var biometricsSection: some View {
        Section("Profile") {
            HStack {
                Text("Height")
                Spacer()
                Text(viewModel.usesMetric
                     ? String(format: "%.0f cm", viewModel.heightCm)
                     : String(format: "%.0f in", viewModel.heightCm / 2.54))
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Weight")
                Spacer()
                Text(viewModel.usesMetric
                     ? String(format: "%.1f kg", viewModel.weightKg)
                     : String(format: "%.1f lbs", viewModel.weightKg * 2.20462))
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Birth Year")
                Spacer()
                Text("\(viewModel.birthYear)")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Starting Week")
                Spacer()
                Text("Week \(viewModel.startingWeek)")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - iCloud

    private var iCloudSection: some View {
        Section("iCloud Sync") {
            HStack {
                Label(
                    viewModel.iCloudSyncEnabled ? "Sync: Enabled" : "Sync: Off (local only)",
                    systemImage: viewModel.iCloudSyncEnabled ? "icloud.fill" : "icloud.slash"
                )
                Spacer()
                Image(systemName: viewModel.iCloudSyncEnabled ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(viewModel.iCloudSyncEnabled ? Color.green : Color.secondary)
            }

            Button("Change iCloud Preference…") {
                showResetAlert = true
            }
            .foregroundStyle(Color.orange)

            Text("iCloud sync is configured at first launch. To change it, app data must be reset.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            NavigationLink("Health Disclaimer") {
                HealthDisclaimerView()
            }
            HStack {
                Text("Version")
                Spacer()
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
}

// MARK: - RunDaysPickerView

private struct RunDaysPickerView: View {
    @Binding var selectedDays: [Int]
    let onDone: () -> Void

    private let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    private let allDays = [1, 2, 3, 4, 5, 6, 7]

    var body: some View {
        List {
            ForEach(allDays, id: \.self) { day in
                let selected = selectedDays.contains(day)
                Button {
                    if selected {
                        selectedDays.removeAll { $0 == day }
                    } else {
                        selectedDays.append(day)
                        selectedDays.sort()
                    }
                    onDone()
                } label: {
                    HStack {
                        Text(dayNames[day - 1])
                        Spacer()
                        if selected {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
        }
        .navigationTitle("Run Days")
    }
}

// MARK: - HealthDisclaimerView

private struct HealthDisclaimerView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Health Disclaimer")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("""
                    Mile One is designed to help you build a running habit gradually and safely. \
                    However, it is not a medical device and does not provide medical advice.

                    Before starting any new exercise program, consult your physician, especially if you:
                    • Have a history of heart disease or high blood pressure
                    • Are pregnant or postpartum
                    • Have joint, bone, or muscle conditions
                    • Have not exercised recently

                    Stop and seek medical attention if you experience chest pain, dizziness, severe shortness of breath, or pain.

                    Listen to your body. Rest when needed. Mile One is a guide, not a prescription.
                    """)
                    .font(.body)
            }
            .padding()
        }
        .navigationTitle("Health Disclaimer")
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
