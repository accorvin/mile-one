#if canImport(UIKit)
import SwiftUI

// MARK: - ScheduleView

/// Onboarding step 4: Pick run days and reminder time.
public struct ScheduleView: View {

    @Bindable var viewModel: OnboardingViewModel

    private let weekdays: [(Int, String)] = [
        (1, "Sun"), (2, "Mon"), (3, "Tue"),
        (4, "Wed"), (5, "Thu"), (6, "Fri"), (7, "Sat"),
    ]

    public var body: some View {
        Form {
            Section("Run Days (pick 3)") {
                LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 7)) {
                    ForEach(weekdays, id: \.0) { day, label in
                        Button {
                            if viewModel.runDays.contains(day) {
                                viewModel.runDays.remove(day)
                            } else {
                                viewModel.runDays.insert(day)
                            }
                        } label: {
                            Text(label)
                                .font(.caption.bold())
                                .padding(6)
                                .frame(maxWidth: .infinity)
                                .background(viewModel.runDays.contains(day) ? Color.accentColor : Color.secondary.opacity(0.15))
                                .foregroundStyle(viewModel.runDays.contains(day) ? .white : .primary)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section("Reminders") {
                Toggle("Enable run reminders", isOn: $viewModel.remindersEnabled)
                if viewModel.remindersEnabled {
                    DatePicker(
                        "Reminder time",
                        selection: Binding(
                            get: {
                                var c = DateComponents()
                                c.hour = viewModel.reminderHour
                                c.minute = viewModel.reminderMinute
                                return Calendar.current.date(from: c) ?? Date()
                            },
                            set: { date in
                                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                                viewModel.reminderHour = c.hour ?? 7
                                viewModel.reminderMinute = c.minute ?? 0
                            }
                        ),
                        displayedComponents: .hourAndMinute
                    )
                }
            }
        }
        .navigationTitle("Your Schedule")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Continue") { viewModel.advance() }
                    .disabled(viewModel.runDays.count < 1)
            }
        }
    }
}
#endif
