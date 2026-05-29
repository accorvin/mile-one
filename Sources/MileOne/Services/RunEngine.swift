import Foundation
import CoreLocation
import Observation

// MARK: - RunEngine

/// Core run-session controller. Manages interval progression, GPS tracking,
/// distance accumulation, audio cues, and checkpoint persistence.
///
/// All state mutations happen on `@MainActor`. Timers use `DispatchSourceTimer`
/// on the main queue. GPS timestamps drive interval advancement — the display
/// timer only refreshes the UI and never advances intervals (except as a fallback
/// when GPS is dead for >3 seconds).
@MainActor
@Observable
public final class RunEngine {

    // MARK: - Public State

    /// Whether the run is actively in progress (not paused, not complete).
    public private(set) var isRunning = false
    /// Whether the run is currently paused.
    public private(set) var isPaused = false
    /// Whether all intervals have completed.
    public private(set) var isComplete = false
    /// Index of the current interval in the session definition.
    public private(set) var currentIntervalIndex = 0
    /// Total elapsed time (excludes pause time).
    public private(set) var totalElapsed: TimeInterval = 0
    /// Total distance traveled in meters.
    public private(set) var totalDistance: Double = 0
    /// All accepted GPS points collected during the run.
    public private(set) var gpsPoints: [CLLocation] = []

    /// Computed: the current interval, or nil if the index is out of bounds.
    public var currentInterval: Interval? {
        guard currentIntervalIndex < sessionDefinition.intervals.count else { return nil }
        return sessionDefinition.intervals[currentIntervalIndex]
    }

    /// Total duration of the session in seconds (from the session definition).
    public var totalDurationSeconds: Int {
        sessionDefinition.totalDurationSeconds
    }

    /// Callback fired when the run completes. Receives (totalElapsed, totalDistance, gpsPoints).
    public var onRunComplete: ((TimeInterval, Double, [CLLocation]) -> Void)?

    /// Number of active display timers (0 or 1). Exposed for test verification.
    public var activeTimerCount: Int {
        displayTimer != nil ? 1 : 0
    }

    // MARK: - Private

    private let sessionDefinition: SessionDefinition
    private let locationProvider: LocationProviding
    private let audioCoach: AudioCoaching
    private let timeProvider: TimeProviding

    /// Wall-clock time when the current running segment started (after start or resume).
    private var segmentStartTime: Date?
    /// Accumulated elapsed time from previous segments (before the current one).
    private var accumulatedElapsed: TimeInterval = 0
    /// Wall-clock time when the run was paused.
    private var pauseStartTime: Date?

    /// Elapsed time within the current interval.
    private var currentIntervalElapsed: TimeInterval = 0
    /// Accumulated interval elapsed from previous segments for the current interval.
    private var intervalAccumulatedElapsed: TimeInterval = 0

    /// Timestamp of the most recent GPS update.
    private var lastGPSTimestamp: Date?
    /// The run's start timestamp (from timeProvider), used for grace period calculation.
    private var runStartTime: Date?
    /// The last accepted GPS point, used for distance calculation.
    private var lastAcceptedLocation: CLLocation?

    /// Display refresh timer (0.5s interval).
    nonisolated private var displayTimer: DispatchSourceTimer?
    /// Checkpoint persistence timer (60s interval).
    nonisolated private var checkpointTimer: DispatchSourceTimer?

    // MARK: - Init

    /// Create a new RunEngine for the given session.
    ///
    /// - Parameters:
    ///   - sessionDefinition: The session plan to execute.
    ///   - locationProvider: GPS abstraction (inject mock for tests).
    ///   - audioCoach: Audio cue abstraction (inject mock for tests).
    ///   - timeProvider: Wall-clock abstraction (inject mock for tests).
    public init(
        sessionDefinition: SessionDefinition,
        locationProvider: LocationProviding,
        audioCoach: AudioCoaching,
        timeProvider: TimeProviding = SystemTimeProvider()
    ) {
        self.sessionDefinition = sessionDefinition
        self.locationProvider = locationProvider
        self.audioCoach = audioCoach
        self.timeProvider = timeProvider
    }

    deinit {
        // Cancel timers directly — deinit is nonisolated so we can't call
        // @MainActor methods. DispatchSourceTimer.cancel() is thread-safe.
        displayTimer?.cancel()
        checkpointTimer?.cancel()
    }

    // MARK: - Public Actions

    /// Start the run. Configures audio, starts GPS, begins timers, speaks the opening cue.
    public func start() throws {
        guard !isRunning, !isComplete else { return }

        try audioCoach.configureAudioSession()

        let now = timeProvider.now()
        runStartTime = now
        segmentStartTime = now
        isRunning = true

        // Wire up GPS callbacks.
        locationProvider.onLocationUpdate = { [weak self] location in
            Task { @MainActor in
                self?.handleLocationUpdate(location)
            }
        }
        locationProvider.startUpdatingLocation()

        startDisplayTimer()
        startCheckpointTimer()

        // Speak the opening cue based on the first interval type.
        if let first = currentInterval {
            audioCoach.speak(audioCue(for: first.type, isCompletion: false))
        }
    }

    /// Pause the run. Stops GPS and display timer, records pause start time.
    public func pause() {
        guard isRunning, !isPaused, !isComplete else { return }

        let now = timeProvider.now()

        // Accumulate elapsed time from the current segment.
        if let segStart = segmentStartTime {
            accumulatedElapsed += now.timeIntervalSince(segStart)
            if let intervalStart = segmentStartTime {
                intervalAccumulatedElapsed += now.timeIntervalSince(intervalStart)
            }
        }

        isPaused = true
        pauseStartTime = now
        segmentStartTime = nil

        cancelDisplayTimer()
        locationProvider.stopUpdatingLocation()
    }

    /// Resume a paused run. Restarts GPS and display timer.
    public func resume() {
        guard isRunning, isPaused, !isComplete else { return }

        let now = timeProvider.now()
        segmentStartTime = now
        isPaused = false
        pauseStartTime = nil

        locationProvider.startUpdatingLocation()
        startDisplayTimer()
    }

    /// Skip to the next interval. Guards against double-completion.
    public func skipInterval() {
        guard isRunning, !isComplete else { return }
        advanceToNextInterval()
    }

    /// End the run immediately. Stops all timers and GPS, marks complete.
    public func endRun() {
        guard isRunning else { return }
        stopEverything()
        isComplete = true
        audioCoach.speak("Congratulations! You've completed your run.")
        RunCheckpoint.clear()
        onRunComplete?(totalElapsed, totalDistance, gpsPoints)
    }

    // MARK: - Display Refresh

    /// Update elapsed/remaining display state. Does NOT advance intervals.
    /// Called by the display timer.
    public func refreshDisplay() {
        guard isRunning, !isPaused, !isComplete else { return }

        let now = timeProvider.now()
        updateElapsedTime(at: now)

        // If GPS has been dead for >3s, use wall-clock fallback that CAN advance intervals.
        if let lastGPS = lastGPSTimestamp, now.timeIntervalSince(lastGPS) > 3 {
            refreshDisplayWithTimestamp(now)
        }
    }

    /// Fallback refresh using a specific timestamp. This CAN advance intervals
    /// when GPS is unavailable (dead zone >3s).
    public func refreshDisplayWithTimestamp(_ timestamp: Date) {
        guard isRunning, !isPaused, !isComplete else { return }
        updateElapsedTime(at: timestamp)
        checkIntervalCompletion()
    }

    // MARK: - GPS Handling

    /// Process a new GPS location update.
    public func handleLocationUpdate(_ location: CLLocation) {
        guard isRunning, !isPaused, !isComplete else { return }

        let now = location.timestamp
        lastGPSTimestamp = now

        // GPS accuracy filtering: accept all during grace period, reject poor accuracy after.
        let timeSinceStart = runStartTime.map { now.timeIntervalSince($0) } ?? 0
        let inGracePeriod = timeSinceStart < Constants.gpsGracePeriodSeconds

        if !inGracePeriod && location.horizontalAccuracy > Constants.gpsAccuracyThreshold {
            return // Reject inaccurate point outside grace period.
        }

        // Accumulate distance.
        if let lastLocation = lastAcceptedLocation {
            totalDistance += location.distance(from: lastLocation)
        }
        lastAcceptedLocation = location
        gpsPoints.append(location)

        // Update elapsed time and check interval completion using GPS timestamp.
        updateElapsedTime(at: now)
        checkIntervalCompletion()
    }

    // MARK: - Interval Advancement

    /// Advance to the next interval. Fires audio cue and guards against double-completion.
    private func advanceToNextInterval() {
        guard !isComplete else { return }

        let nextIndex = currentIntervalIndex + 1

        if nextIndex >= sessionDefinition.intervals.count {
            // All intervals done.
            endRun()
            return
        }

        currentIntervalIndex = nextIndex
        intervalAccumulatedElapsed = 0

        // Reset the segment start for the new interval's elapsed tracking.
        segmentStartTime = timeProvider.now()
        accumulatedElapsed = totalElapsed

        let interval = sessionDefinition.intervals[nextIndex]
        audioCoach.speak(audioCue(for: interval.type, isCompletion: false))
    }

    // MARK: - Private Helpers

    /// Update totalElapsed and currentIntervalElapsed from the given timestamp.
    private func updateElapsedTime(at timestamp: Date) {
        if let segStart = segmentStartTime {
            totalElapsed = accumulatedElapsed + timestamp.timeIntervalSince(segStart)
        }

        // Calculate how much time has elapsed in the current interval.
        if let segStart = segmentStartTime {
            currentIntervalElapsed = intervalAccumulatedElapsed + timestamp.timeIntervalSince(segStart)
        }
    }

    /// Check if the current interval's duration has been exceeded and advance if so.
    private func checkIntervalCompletion() {
        guard let interval = currentInterval else { return }
        if currentIntervalElapsed >= Double(interval.durationSeconds) {
            advanceToNextInterval()
        }
    }

    /// Return the audio cue string for an interval type.
    private func audioCue(for type: IntervalType, isCompletion: Bool) -> String {
        switch type {
        case .warmUp:   return "Start your warm-up walk."
        case .run:      return "Time to run!"
        case .walk:     return "Take a walk break."
        case .coolDown: return "Great work! Begin your cool-down walk."
        }
    }

    /// Stop everything: timers, GPS, mark not running.
    private func stopEverything() {
        cancelDisplayTimer()
        cancelCheckpointTimer()
        locationProvider.stopUpdatingLocation()
        locationProvider.onLocationUpdate = nil
        audioCoach.stop()
        isRunning = false
        isPaused = false

        // Final elapsed calculation.
        if let segStart = segmentStartTime {
            totalElapsed = accumulatedElapsed + timeProvider.now().timeIntervalSince(segStart)
        }
    }

    // MARK: - Timers

    /// Start the display refresh timer (0.5s interval on main queue).
    private func startDisplayTimer() {
        cancelDisplayTimer()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 0.5, repeating: 0.5)
        timer.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.refreshDisplay()
            }
        }
        timer.resume()
        displayTimer = timer
    }

    /// Cancel the display timer.
    private func cancelDisplayTimer() {
        displayTimer?.cancel()
        displayTimer = nil
    }

    /// Start the checkpoint timer (60s interval on main queue).
    private func startCheckpointTimer() {
        cancelCheckpointTimer()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 60, repeating: 60)
        timer.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.saveCheckpoint()
            }
        }
        timer.resume()
        checkpointTimer = timer
    }

    /// Cancel the checkpoint timer.
    private func cancelCheckpointTimer() {
        checkpointTimer?.cancel()
        checkpointTimer = nil
    }

    /// Persist current state to UserDefaults.
    private func saveCheckpoint() {
        let checkpoint = RunCheckpoint(
            sessionId: sessionDefinition.id,
            currentIntervalIndex: currentIntervalIndex,
            totalElapsed: totalElapsed,
            totalDistance: totalDistance
        )
        checkpoint.save()
    }
}
