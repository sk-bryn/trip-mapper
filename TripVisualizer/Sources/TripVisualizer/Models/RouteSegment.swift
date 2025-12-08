import Foundation

/// Segment type for rendering differentiation.
///
/// Used to determine how a route segment should be visually displayed on maps.
public enum SegmentType: String, Codable, Sendable {
    /// Continuous route data from a log fragment (solid line)
    case continuous

    /// Gap between fragments where data is missing (dashed line)
    case gap
}

/// A contiguous portion of a route, either continuous data or a gap.
///
/// Route segments are used for rendering purposes, allowing the map generator
/// to display continuous route data differently from gaps in the data.
///
/// - Continuous segments: Rendered as solid lines, contain actual waypoint data
/// - Gap segments: Rendered as dashed lines, represent missing data between fragments
public struct RouteSegment: Codable, Equatable, Sendable {

    // MARK: - Properties

    /// Waypoints in this segment
    public let waypoints: [Waypoint]

    /// Type of segment for rendering
    public let type: SegmentType

    /// Source fragment ID (nil for gap segments)
    public let sourceFragmentId: String?

    // MARK: - Initialization

    public init(
        waypoints: [Waypoint],
        type: SegmentType,
        sourceFragmentId: String? = nil
    ) {
        self.waypoints = waypoints
        self.type = type
        self.sourceFragmentId = sourceFragmentId
    }

    // MARK: - Computed Properties

    /// Number of waypoints in this segment
    public var waypointCount: Int {
        waypoints.count
    }

    /// First waypoint in the segment
    public var startWaypoint: Waypoint? {
        waypoints.first
    }

    /// Last waypoint in the segment
    public var endWaypoint: Waypoint? {
        waypoints.last
    }

    /// Returns true if this is a continuous segment with actual route data
    public var isContinuous: Bool {
        type == .continuous
    }

    /// Returns true if this is a gap segment representing missing data
    public var isGap: Bool {
        type == .gap
    }
}

// MARK: - CustomStringConvertible

extension RouteSegment: CustomStringConvertible {
    public var description: String {
        let fragmentInfo = sourceFragmentId.map { " from \($0.prefix(8))..." } ?? ""
        return "RouteSegment(\(type.rawValue), \(waypointCount) waypoints\(fragmentInfo))"
    }
}
