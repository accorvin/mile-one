import Foundation
import SwiftData

// MARK: - GPSPoint

@Model
public final class GPSPoint {
    public var latitude: Double
    public var longitude: Double
    public var altitude: Double
    public var horizontalAccuracy: Double
    public var timestamp: Date
    public var speedMetersPerSecond: Double

    // Inverse relationship back to the owning run
    public var run: CompletedRun?

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
        self.speedMetersPerSecond = speed
    }
}
