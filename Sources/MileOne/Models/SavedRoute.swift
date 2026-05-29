import Foundation
import SwiftData
import Compression

// MARK: - SavedRoute

@Model
public final class SavedRoute {
    public var id: UUID
    public var name: String
    public var createdAt: Date
    public var distanceMeters: Double

    // CloudKit requires primitive storage — stored as raw String.
    // Use the computed `drawModeEnum` for type-safe access.
    public var drawMode: String

    // Zlib-compressed JSON data stored as CloudKit asset (external storage)
    @Attribute(.externalStorage)
    public var waypointsData: Data

    @Attribute(.externalStorage)
    public var polylineData: Data?

    public init(name: String, drawMode: String, waypoints: Data) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.distanceMeters = 0
        self.drawMode = drawMode
        self.waypointsData = waypoints
        self.polylineData = nil
    }

    /// Convenience initialiser that accepts the DrawMode enum.
    public convenience init(name: String, drawMode: DrawMode, waypoints: Data) {
        self.init(name: name, drawMode: drawMode.rawValue, waypoints: waypoints)
    }

    /// Type-safe accessor for the stored raw string.
    public var drawModeEnum: DrawMode? {
        DrawMode(rawValue: drawMode)
    }

    // MARK: - Zlib Compression Helpers

    /// Compress JSON data with zlib before storing.
    public static func compress(_ data: Data) -> Data {
        (try? (data as NSData).compressed(using: .zlib) as Data) ?? data
    }

    /// Decompress zlib data when reading.
    public static func decompress(_ data: Data) -> Data {
        (try? (data as NSData).decompressed(using: .zlib) as Data) ?? data
    }
}
