import Testing
import Foundation
import CoreLocation
@testable import MileOne

// MARK: - RunEngineGPSTests
//
// Constants from production code:
//   gpsAccuracyThreshold = 50m  (reject points with horizontalAccuracy > 50 after grace period)
//   gpsGracePeriodSeconds = 60s (accept all points within first 60s)

@MainActor
@Suite("RunEngine GPS Tests")
struct RunEngineGPSTests {

    // MARK: - Helpers

    private func makeEngine(time: MockTimeProvider, location: MockLocationProvider) throws -> RunEngine {
        let session = SessionDefinition(
            id: "W1D1",
            week: 1,
            dayInWeek: 1,
            intervals: [
                Interval(type: .warmUp,   durationSeconds: 3600),
                Interval(type: .run,      durationSeconds: 3600),
                Interval(type: .coolDown, durationSeconds: 3600),
            ]
        )
        let suiteName = "com.mileone.test.gps.\(UUID())"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let engine = RunEngine(
            sessionDefinition: session,
            locationProvider: location,
            audioCoach: MockAudioCoach(),
            timeProvider: time,
            checkpointStore: defaults
        )
        try engine.start()
        return engine
    }

    // MARK: - Tests

    @Test("High-accuracy point after grace period is accepted and accumulates distance")
    func highAccuracyPointAfterGracePeriodIsAccepted() throws {
        let time = MockTimeProvider()
        let location = MockLocationProvider()
        let base = Date(timeIntervalSince1970: 1_000_000)
        time.currentTime = base

        let engine = try makeEngine(time: time, location: location)

        // Give a first accepted location to anchor distance calc
        location.simulateLocation(lat: 35.7796, lng: -78.6382,
                                  timestamp: base.addingTimeInterval(61),
                                  accuracy: 10)

        let distanceBefore = engine.totalDistance

        // Advance past grace period (61 seconds), send high-accuracy point
        location.simulateLocation(lat: 35.7806, lng: -78.6382,
                                  timestamp: base.addingTimeInterval(62),
                                  accuracy: 10)  // well within 50m threshold

        #expect(engine.totalDistance > distanceBefore,
                "High-accuracy point after grace period must accumulate distance")
    }

    @Test("Low-accuracy point after grace period is rejected")
    func lowAccuracyPointAfterGracePeriodIsRejected() throws {
        let time = MockTimeProvider()
        let location = MockLocationProvider()
        let base = Date(timeIntervalSince1970: 2_000_000)
        time.currentTime = base

        let engine = try makeEngine(time: time, location: location)

        // First point after grace period — high accuracy, anchors lastAcceptedLocation
        location.simulateLocation(lat: 35.7796, lng: -78.6382,
                                  timestamp: base.addingTimeInterval(61),
                                  accuracy: 10)
        let distanceAfterFirstGoodPoint = engine.totalDistance

        // Second point after grace period — poor accuracy (> 50m threshold)
        location.simulateLocation(lat: 35.7806, lng: -78.6382,
                                  timestamp: base.addingTimeInterval(62),
                                  accuracy: 100)  // exceeds 50m threshold

        #expect(engine.totalDistance == distanceAfterFirstGoodPoint,
                "Low-accuracy point after grace period must be rejected (distance unchanged)")
    }

    @Test("Low-accuracy point during grace period is accepted")
    func lowAccuracyPointDuringGracePeriodIsAccepted() throws {
        let time = MockTimeProvider()
        let location = MockLocationProvider()
        let base = Date(timeIntervalSince1970: 3_000_000)
        time.currentTime = base

        let engine = try makeEngine(time: time, location: location)

        // First point: anchor location during grace period
        location.simulateLocation(lat: 35.7796, lng: -78.6382,
                                  timestamp: base.addingTimeInterval(1),
                                  accuracy: 200)  // very poor accuracy

        let distanceAfterFirst = engine.totalDistance

        // Second point during grace period: also poor accuracy, but should be accepted
        location.simulateLocation(lat: 35.7806, lng: -78.6382,
                                  timestamp: base.addingTimeInterval(30),  // still within 60s
                                  accuracy: 200)

        // Distance should have grown (point was accepted despite poor accuracy)
        #expect(engine.totalDistance > distanceAfterFirst,
                "Low-accuracy point during grace period (< 60s) must be accepted")
    }

    @Test("Two sequential good points calculate distance correctly between them")
    func twoSequentialGoodPointsCalculateDistanceCorrectly() throws {
        let time = MockTimeProvider()
        let location = MockLocationProvider()
        let base = Date(timeIntervalSince1970: 4_000_000)
        time.currentTime = base

        let engine = try makeEngine(time: time, location: location)

        // Point A: after grace period, high accuracy
        let coordA = CLLocationCoordinate2D(latitude: 35.7796, longitude: -78.6382)
        location.simulateLocation(lat: coordA.latitude, lng: coordA.longitude,
                                  timestamp: base.addingTimeInterval(61),
                                  accuracy: 10)

        // Point B: slightly north of A (same longitude)
        let coordB = CLLocationCoordinate2D(latitude: 35.7806, longitude: -78.6382)
        location.simulateLocation(lat: coordB.latitude, lng: coordB.longitude,
                                  timestamp: base.addingTimeInterval(62),
                                  accuracy: 10)

        // Calculate expected distance between the two CLLocations
        let locA = CLLocation(latitude: coordA.latitude, longitude: coordA.longitude)
        let locB = CLLocation(latitude: coordB.latitude, longitude: coordB.longitude)
        let expectedDistance = locB.distance(from: locA)

        #expect(abs(engine.totalDistance - expectedDistance) < 1.0)
    }
}
