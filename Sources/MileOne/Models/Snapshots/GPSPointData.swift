import Foundation

// MARK: - GPSPointData

/// Plain-value struct for passing GPS data INTO DataStore across actor boundaries.
/// This avoids cross-actor isolation violations that would occur with @Model objects.
public struct GPSPointData: Sendable {
    public let latitude: Double
    public let longitude: Double
    public let altitude: Double
    public let horizontalAccuracy: Double
    public let timestamp: Date
    public let speed: Double

    public init(
        latitude: Double,
        longitude: Double,
        altitude: Double,
        horizontalAccuracy: Double,
        timestamp: Date,
        speed: Double
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.horizontalAccuracy = horizontalAccuracy
        self.timestamp = timestamp
        self.speed = speed
    }
}
