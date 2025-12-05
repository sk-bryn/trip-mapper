import Foundation

/// Represents a complete delivery journey extracted from a single DataDog log entry.
///
/// A trip contains an ordered list of waypoints representing the driver's route.
/// Each trip maps to exactly one log entry in the logging service.
public struct Trip: Codable, Equatable {

    // MARK: - Constants

    /// Minimum number of waypoints required for a valid route visualization
    public static let minimumWaypointsRequired = 2

    // MARK: - Properties

    /// Unique trip identifier (UUID format)
    public let id: UUID

    /// DataDog log ID for reference
    public let logId: String

    /// URL link to the source log in DataDog
    public let logLink: String

    /// Ordered list of waypoints from segment_coords
    public let waypoints: [Waypoint]

    /// When the log was recorded
    public let timestamp: Date

    // MARK: - Initialization

    public init(
        id: UUID,
        logId: String,
        logLink: String,
        waypoints: [Waypoint],
        timestamp: Date
    ) {
        self.id = id
        self.logId = logId
        self.logLink = logLink
        self.waypoints = waypoints
        self.timestamp = timestamp
    }

    // MARK: - Computed Properties

    /// Returns true if the trip has enough waypoints for visualization (minimum 2)
    public var hasMinimumWaypoints: Bool {
        waypoints.count >= Self.minimumWaypointsRequired
    }

    /// Returns the first waypoint (start of the route)
    public var startWaypoint: Waypoint? {
        waypoints.first
    }

    /// Returns the last waypoint (end of the route)
    public var endWaypoint: Waypoint? {
        waypoints.last
    }

    /// Returns only waypoints with valid coordinates
    public var validWaypoints: [Waypoint] {
        waypoints.filter { $0.isValid }
    }

    /// Returns waypoints that are part of a delivery (have order IDs)
    public var deliveryWaypoints: [Waypoint] {
        waypoints.filter { $0.isDeliveryWaypoint }
    }

    /// Returns waypoints that represent return-to-restaurant segments
    public var returnWaypoints: [Waypoint] {
        waypoints.filter { $0.isReturnToRestaurant }
    }

    /// Total number of waypoints
    public var waypointCount: Int {
        waypoints.count
    }

    /// Number of valid waypoints
    public var validWaypointCount: Int {
        validWaypoints.count
    }
}

// MARK: - CustomStringConvertible

extension Trip: CustomStringConvertible {
    public var description: String {
        "Trip(\(id.uuidString.prefix(8))..., \(waypointCount) waypoints)"
    }
}
