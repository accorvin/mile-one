#if canImport(UIKit)
import SwiftUI

// MARK: - HistoryView

/// Displays past runs in either a calendar grid or a grouped list.
/// GPS data is loaded lazily — only when the user taps into RunDetailView.
public struct HistoryView: View {

    @State private var viewModel: HistoryViewModel
    @State private var showCalendar: Bool = false

    public init(viewModel: HistoryViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Stats header
                statsHeader

                // Toggle
                Picker("View Mode", selection: $showCalendar) {
                    Text("List").tag(false)
                    Text("Calendar").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                // Content
                if showCalendar {
                    calendarView
                } else {
                    listView
                }
            }
            .navigationTitle("History")
            .task {
                await viewModel.loadRuns()
            }
        }
    }

    // MARK: - Stats Header

    private var statsHeader: some View {
        HStack(spacing: 24) {
            statCell(title: "Runs", value: "\(viewModel.lifetimeStats.totalRuns)")
            statCell(title: "Distance", value: formattedDistance(viewModel.lifetimeStats.totalDistance))
            statCell(title: "Time", value: formattedDuration(viewModel.lifetimeStats.totalDuration))
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }

    private func statCell(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - List View

    private var listView: some View {
        Group {
            if viewModel.groupedRuns.isEmpty {
                ContentUnavailableView(
                    "No Runs Yet",
                    systemImage: "figure.run",
                    description: Text("Complete your first run to see it here.")
                )
            } else {
                List {
                    ForEach(sortedMonthKeys, id: \.self) { monthKey in
                        Section(header: Text(monthLabel(for: monthKey))) {
                            ForEach(viewModel.groupedRuns[monthKey] ?? [], id: \.id) { run in
                                NavigationLink {
                                    RunDetailView(run: run, viewModel: viewModel)
                                } label: {
                                    RunRowView(run: run)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    // MARK: - Calendar View

    private var calendarView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(sortedMonthKeys, id: \.self) { monthKey in
                    MonthCalendarView(
                        monthKey: monthKey,
                        runs: viewModel.groupedRuns[monthKey] ?? [],
                        viewModel: viewModel
                    )
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }

    // MARK: - Helpers

    private var sortedMonthKeys: [Date] {
        viewModel.groupedRuns.keys.sorted(by: >)
    }

    private func monthLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func formattedDistance(_ meters: Double) -> String {
        let km = meters / 1000
        return String(format: "%.1f km", km)
    }

    private func formattedDuration(_ seconds: Double) -> String {
        let totalMinutes = Int(seconds) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - RunRowView

private struct RunRowView: View {
    let run: CompletedRunSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(run.isFreeRun ? "Free Run" : "Week \(run.weekNumber), Session \(run.sessionNumber)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(run.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 16) {
                Label(formattedDistance(run.distanceMeters), systemImage: "figure.run")
                Label(formattedDuration(run.durationSeconds), systemImage: "clock")
                if let calories = optionalCalories(run.calories) {
                    Label(calories, systemImage: "flame")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func formattedDistance(_ meters: Double) -> String {
        String(format: "%.2f km", meters / 1000)
    }

    private func formattedDuration(_ seconds: Double) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }

    private func optionalCalories(_ cals: Double) -> String? {
        guard cals > 0 else { return nil }
        return "\(Int(cals)) kcal"
    }
}

// MARK: - MonthCalendarView

private struct MonthCalendarView: View {
    let monthKey: Date
    let runs: [CompletedRunSnapshot]
    let viewModel: HistoryViewModel

    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let dayLabels = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(monthLabel)
                .font(.headline)

            // Day of week headers
            HStack {
                ForEach(dayLabels, id: \.self) { label in
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(0..<leadingBlanks, id: \.self) { _ in
                    Color.clear
                        .frame(height: 36)
                }
                ForEach(1...daysInMonth, id: \.self) { day in
                    let hasRun = runDays.contains(day)
                    VStack(spacing: 2) {
                        Text("\(day)")
                            .font(.caption)
                            .foregroundStyle(hasRun ? .primary : .secondary)
                        Circle()
                            .fill(hasRun ? Color.accentColor : Color.clear)
                            .frame(width: 6, height: 6)
                    }
                    .frame(height: 36)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var monthLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: monthKey)
    }

    private var runDays: Set<Int> {
        let cal = Calendar.current
        var days = Set<Int>()
        for run in runs {
            days.insert(cal.component(.day, from: run.date))
        }
        return days
    }

    private var leadingBlanks: Int {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: monthKey)
        return weekday - 1  // 1-indexed, Sunday=1 → 0 blanks
    }

    private var daysInMonth: Int {
        let cal = Calendar.current
        guard let range = cal.range(of: .day, in: .month, for: monthKey) else { return 30 }
        return range.count
    }
}
#endif
