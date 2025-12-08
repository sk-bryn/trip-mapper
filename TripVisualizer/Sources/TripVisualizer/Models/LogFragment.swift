import Foundation

/// A single log entry representing one fragment of a trip's route.
///
/// When the delivery app crashes or restarts, a new log fragment is created.
/// Multiple fragments together form the complete trip history. Each fragment
/// is retained as an independent entity for inspection and traceability.
///
/// ## Usage
/// ```swift
/// let fragment = LogFragment(
///     id: "abc123",
///     tripId: tripUUID,
///     timestamp: Date(),
///     waypoints: [waypoint1, waypoint2],
///     logLink: "https://app.datadoghq.com/logs?..."
/// )
/// ```
public struct LogFragment: Codable, Equatable, Identifiable, Sendable {

    // MARK: - Constants

    /// Minimum number of waypoints required for a valid fragment
    public static let minimumWaypointsRequired = 2

    // MARK: - Properties

    /// DataDog log entry ID (unique identifier)
    public let id: String

    /// Trip UUID this fragment belongs to
    public let tripId: UUID

    /// When this log was recorded in DataDog
    public let timestamp: Date

    /// Ordered waypoints from this fragment's segment_coords
    public let waypoints: [Waypoint]

    /// URL to view this log in DataDog UI
    public let logLink: String

    // MARK: - Initialization

    public init(
        id: String,
        tripId: UUID,
        timestamp: Date,
        waypoints: [Waypoint],
        logLink: String
    ) {
        self.id = id
        self.tripId = tripId
        self.timestamp = timestamp
        self.waypoints = waypoints
        self.logLink = logLink
    }

    // MARK: - Computed Properties

    /// Number of waypoints in this fragment
    public var waypointCount: Int {
        waypoints.count
    }

    /// First waypoint (start location of this fragment)
    public var startLocation: Waypoint? {
        waypoints.first
    }

    /// Last waypoint (end location of this fragment)
    public var endLocation: Waypoint? {
        waypoints.last
    }

    /// Returns true if the fragment has enough waypoints for visualization
    public var hasMinimumWaypoints: Bool {
        waypoints.count >= Self.minimumWaypointsRequired
    }

    /// Returns only waypoints with valid coordinates
    public var validWaypoints: [Waypoint] {
        waypoints.filter { $0.isValid }
    }

    /// Returns the number of valid waypoints
    public var validWaypointCount: Int {
        validWaypoints.count
    }
}

// MARK: - Validation

extension LogFragment {
    /// Validates the fragment meets minimum requirements.
    ///
    /// - Returns: True if the fragment is valid (non-empty id, valid tripId, minimum waypoints)
    public var isValid: Bool {
        !id.isEmpty && hasMinimumWaypoints
    }

    /// Returns validation errors for this fragment, if any.
    public var validationErrors: [String] {
        var errors: [String] = []

        if id.isEmpty {
            errors.append("Fragment ID is empty")
        }

        if waypoints.count < Self.minimumWaypointsRequired {
            errors.append("Fragment has fewer than \(Self.minimumWaypointsRequired) waypoints")
        }

        if logLink.isEmpty {
            errors.append("Log link is empty")
        }

        return errors
    }
}

// MARK: - CustomStringConvertible

extension LogFragment: CustomStringConvertible {
    public var description: String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]
        let timestampStr = dateFormatter.string(from: timestamp)
        return "LogFragment(\(id.prefix(8))..., trip: \(tripId.uuidString.prefix(8))..., \(waypointCount) waypoints, \(timestampStr))"
    }
}

// MARK: - Comparable

extension LogFragment: Comparable {
    /// Fragments are compared by timestamp for chronological ordering
    public static func < (lhs: LogFragment, rhs: LogFragment) -> Bool {
        lhs.timestamp < rhs.timestamp
    }
}
