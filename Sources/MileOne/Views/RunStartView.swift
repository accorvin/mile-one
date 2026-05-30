#if canImport(UIKit)
import SwiftUI
import CoreLocation

/// Owns RunEngine + RunViewModel and connects them for the active run screen.
/// After the run completes, transitions to PostRunView before dismissing.
@available(iOS 17.0, *)
@MainActor
struct RunStartView: View {
    let session: SessionDefinition
    @Bindable var appState: AppState
    let dataStore: any DataStoreProviding

    @State private var engine: RunEngine?
    @State private var viewModel = RunViewModel()
    @State private var showPostRun = false
    @State private var postRunResult: PostRunData? = nil

    var body: some View {
        Group {
            if showPostRun, let data = postRunResult {
                if #available(iOS 17.0, *) {
                    PostRunView(
                        result: data.saveResult,
                        distanceMeters: data.distanceMeters,
                        durationSeconds: data.durationSeconds,
                        calories: data.calories,
                        averagePaceSecondsPerKm: data.averagePaceSecondsPerKm,
                        averageHeartRate: nil,
                        routeCoordinates: data.routeCoordinates,
                        onEffortSelected: { rating in
                            Task {
                                try? await dataStore.updateEffortRating(
                                    runId: data.saveResult.runId,
                                    rating: rating
                                )
                            }
                        },
                        onDashboard: {
                            appState.isShowingRun = false
                        }
                    )
                }
            } else if let engine = engine {
                RunView(
                    viewModel: viewModel,
                    onPauseResume: {
                        if engine.isPaused { engine.resume() } else { engine.pause() }
                    },
                    onEndRun: {
                        engine.endRun()
                        appState.isShowingRun = false
                    }
                )
            } else {
                ProgressView("Starting…")
            }
        }
        .task {
            let locationProvider = LocationService()
            let audioCoach = AudioCoachService()
            let newEngine = RunEngine(
                sessionDefinition: session,
                locationProvider: locationProvider,
                audioCoach: audioCoach
            )
            newEngine.onSnapshot = { snapshot in
                viewModel.update(with: snapshot)
            }
            newEngine.onRunComplete = { [weak newEngine] elapsed, distance, locations in
                // Build post-run data from raw run output
                let intervals = newEngine.map { _ in session.intervals } ?? session.intervals
                let calories = CalorieCalculator.calculate(
                    weightKg: 70, // fallback; PostRunOrchestrator uses real weight
                    intervals: intervals,
                    actualDurationSeconds: elapsed
                )
                let pace: Double? = distance > 0 ? elapsed / (distance / 1000.0) : nil
                let coords = locations.map { $0.coordinate }

                // Use a placeholder SaveRunResult since PostRunOrchestrator runs async
                // The effort rating runId will be patched when the real save completes
                let placeholderResult = SaveRunResult(
                    runId: UUID(),
                    swiftDataSaved: false,
                    healthKitSaved: false,
                    healthKitError: nil
                )

                postRunResult = PostRunData(
                    saveResult: placeholderResult,
                    distanceMeters: distance,
                    durationSeconds: elapsed,
                    calories: calories,
                    averagePaceSecondsPerKm: pace,
                    routeCoordinates: coords
                )
                showPostRun = true
            }
            engine = newEngine
            try? newEngine.start()
        }
    }
}

// MARK: - PostRunData

/// Lightweight value type to carry run results into PostRunView.
struct PostRunData {
    let saveResult: SaveRunResult
    let distanceMeters: Double
    let durationSeconds: Double
    let calories: Double
    let averagePaceSecondsPerKm: Double?
    let routeCoordinates: [CLLocationCoordinate2D]
}

#endif
