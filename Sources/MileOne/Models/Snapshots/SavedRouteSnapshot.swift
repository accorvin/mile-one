import Foundation

// MARK: - SavedRouteSnapshot

/// Value-type DTO returned from DataStore. Safe to pass across actor boundaries.
public struct SavedRouteSnapshot: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let createdAt: Date
    public let distanceMeters: Double
    public let drawMode: DrawMode

    public init(
        id: UUID,
        name: String,
        createdAt: Date,
        distanceMeters: Double,
        drawMode: DrawMode
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.distanceMeters = distanceMeters
        self.drawMode = drawMode
    }
}
