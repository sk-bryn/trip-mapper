import Foundation

/// Combined route from all log fragments, ready for map visualization.
///
/// UnifiedRoute is a view model that combines data from multiple LogFragments
/// into a single visualization-ready structure. It does not replace the underlying
/// fragment data - fragments are retained separately for inspection.
///
/// Waypoints are chronologically ordered and deduplicated across all fragments.
/// Segments are provided for rendering with different styles (continuous vs gap).
///
/// ## Usage
/// ```swift
/// let route = try aggregator.aggregate(fragments: fragments, gapThreshold: 300)
/// try mapGenerator.writeHTML(tripId: route.tripId, segments: route.segments, to: path)
/// ```
public struct UnifiedRoute: Codable, Equatable, Sendable {

    // MARK: - Properties

    /// Trip UUID
    public let tripId: UUID

    /// All waypoints in chronological order (deduplicated)
    public let waypoints: [Waypoint]

    /// Route segments for rendering (continuous vs gap)
    public let segments: [RouteSegment]

    /// Number of source fragments
    public let fragmentCount: Int

    /// Whether all fragments were successfully processed
    public let isComplete: Bool

    // MARK: - Initialization

    public init(
        tripId: UUID,
        waypoints: [Waypoint],
        segments: [RouteSegment],
        fragmentCount: Int,
        isComplete: Bool
    ) {
        self.tripId = tripId
        self.waypoints = waypoints
        self.segments = segments
        self.fragmentCount = fragmentCount
        self.isComplete = isComplete
    }

    // MARK: - Computed Properties

    /// Total waypoints across all segments
    public var totalWaypointCount: Int {
        waypoints.count
    }

    /// Returns true if any segment is a gap
    public var hasGaps: Bool {
        segments.contains { $0.isGap }
    }

    /// Returns only continuous segments (with actual route data)
    public var continuousSegments: [RouteSegment] {
        segments.filter { $0.isContinuous }
    }

    /// Returns only gap segments (missing data)
    public var gapSegments: [RouteSegment] {
        segments.filter { $0.isGap }
    }

    /// Number of continuous segments
    public var continuousSegmentCount: Int {
        continuousSegments.count
    }

    /// Number of gap segments
    public var gapCount: Int {
        gapSegments.count
    }

    /// First waypoint in the unified route
    public var startWaypoint: Waypoint? {
        waypoints.first
    }

    /// Last waypoint in the unified route
    public var endWaypoint: Waypoint? {
        waypoints.last
    }

    /// Returns true if the route has the minimum waypoints for visualization
    public var hasMinimumWaypoints: Bool {
        waypoints.count >= 2
    }
}

// MARK: - CustomStringConvertible

extension UnifiedRoute: CustomStringConvertible {
    public var description: String {
        var parts: [String] = []
        parts.append("trip: \(tripId.uuidString.prefix(8))...")
        parts.append("\(totalWaypointCount) waypoints")
        parts.append("\(fragmentCount) fragments")
        parts.append("\(segments.count) segments")

        if hasGaps {
            parts.append("\(gapCount) gaps")
        }

        if !isComplete {
            parts.append("incomplete")
        }

        return "UnifiedRoute(\(parts.joined(separator: ", ")))"
    }
}

// MARK: - Factory Methods

extension UnifiedRoute {
    /// Creates a unified route from a single fragment (no gaps)
    public static func fromSingleFragment(_ fragment: LogFragment) -> UnifiedRoute {
        // Assign fragmentId to all waypoints
        let waypointsWithFragmentId = fragment.waypoints.map { waypoint in
            Waypoint(
                latitude: waypoint.latitude,
                longitude: waypoint.longitude,
                orderId: waypoint.orderId,
                fragmentId: fragment.id
            )
        }

        let segment = RouteSegment(
            waypoints: waypointsWithFragmentId,
            type: .continuous,
            sourceFragmentId: fragment.id
        )

        return UnifiedRoute(
            tripId: fragment.tripId,
            waypoints: waypointsWithFragmentId,
            segments: [segment],
            fragmentCount: 1,
            isComplete: true
        )
    }

    /// Creates a unified route from existing waypoints (backward compatibility)
    public static func fromWaypoints(_ waypoints: [Waypoint], tripId: UUID) -> UnifiedRoute {
        let segment = RouteSegment(
            waypoints: waypoints,
            type: .continuous,
            sourceFragmentId: nil
        )

        return UnifiedRoute(
            tripId: tripId,
            waypoints: waypoints,
            segments: [segment],
            fragmentCount: 1,
            isComplete: true
        )
    }
}
