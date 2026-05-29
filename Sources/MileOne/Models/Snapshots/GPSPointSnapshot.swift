import Foundation

// MARK: - GPSPointSnapshot

/// Value-type DTO returned from DataStore. Safe to pass across actor boundaries.
public struct GPSPointSnapshot: Sendable {
    public let latitude: Double
    public let longitude: Double
    public let altitude: Double
    public let timestamp: Date
    public let speed: Double
    public let horizontalAccuracy: Double

    public init(
        latitude: Double,
        longitude: Double,
        altitude: Double,
        timestamp: Date,
        speed: Double,
        horizontalAccuracy: Double
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.timestamp = timestamp
        self.speed = speed
        self.horizontalAccuracy = horizontalAccuracy
    }
}
