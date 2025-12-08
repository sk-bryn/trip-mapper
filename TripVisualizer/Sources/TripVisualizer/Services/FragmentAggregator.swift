import Foundation

/// Error types for fragment aggregation
public enum AggregationError: Error, Equatable {
    /// Input array is empty
    case emptyFragments

    /// Fragments have mismatched trip IDs
    case tripIdMismatch(expected: UUID, found: UUID)

    /// Fragment has fewer than 2 waypoints
    case invalidFragment(id: String, reason: String)

    /// All fragments failed validation
    case allFragmentsInvalid
}

extension AggregationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .emptyFragments:
            return "Cannot aggregate empty fragment array"
        case .tripIdMismatch(let expected, let found):
            return "Fragment trip ID mismatch: expected \(expected), found \(found)"
        case .invalidFragment(let id, let reason):
            return "Invalid fragment \(id): \(reason)"
        case .allFragmentsInvalid:
            return "All fragments failed validation"
        }
    }
}

/// Protocol for fragment aggregation services
public protocol FragmentAggregating {
    /// Aggregates log fragments into a unified route for visualization.
    /// - Parameters:
    ///   - fragments: Array of log fragments (must be non-empty)
    ///   - gapThreshold: Time interval to consider as a gap (default: 5 minutes)
    /// - Returns: UnifiedRoute combining all fragment waypoints
    /// - Throws: AggregationError if aggregation fails
    func aggregate(
        fragments: [LogFragment],
        gapThreshold: TimeInterval
    ) throws -> UnifiedRoute
}

/// Service for aggregating multiple log fragments into a unified route.
///
/// The FragmentAggregator combines waypoints from multiple log fragments into
/// a single visualization-ready route. It handles:
/// - Chronological ordering of fragments
/// - Waypoint deduplication across fragments
/// - Gap detection between fragments
/// - Segment construction for rendering
///
/// ## Usage
/// ```swift
/// let aggregator = FragmentAggregator()
/// let route = try aggregator.aggregate(fragments: fragments, gapThreshold: 300)
/// ```
public struct FragmentAggregator: FragmentAggregating {

    // MARK: - Constants

    /// Default gap threshold in seconds (5 minutes)
    public static let defaultGapThreshold: TimeInterval = 300

    /// Coordinate tolerance for deduplication (~1 meter)
    public static let deduplicationTolerance: Double = 0.00001

    // MARK: - Initialization

    public init() {}

    // MARK: - Public Methods

    /// Aggregates log fragments into a unified route for visualization.
    ///
    /// The aggregation process:
    /// 1. Validates input fragments
    /// 2. Sorts fragments by timestamp
    /// 3. Deduplicates waypoints across fragment boundaries
    /// 4. Detects gaps between fragments
    /// 5. Constructs route segments
    ///
    /// - Parameters:
    ///   - fragments: Array of log fragments (must be non-empty)
    ///   - gapThreshold: Time interval to consider as a gap (seconds)
    /// - Returns: UnifiedRoute combining all fragment waypoints
    /// - Throws: AggregationError if aggregation fails
    public func aggregate(
        fragments: [LogFragment],
        gapThreshold: TimeInterval = defaultGapThreshold
    ) throws -> UnifiedRoute {
        // Validate non-empty input
        guard !fragments.isEmpty else {
            throw AggregationError.emptyFragments
        }

        // Single fragment optimization
        if fragments.count == 1 {
            let fragment = fragments[0]
            guard fragment.hasMinimumWaypoints else {
                throw AggregationError.invalidFragment(
                    id: fragment.id,
                    reason: "fewer than \(LogFragment.minimumWaypointsRequired) waypoints"
                )
            }
            return UnifiedRoute.fromSingleFragment(fragment)
        }

        // Validate all fragments have same tripId
        let tripId = fragments[0].tripId
        for fragment in fragments.dropFirst() {
            guard fragment.tripId == tripId else {
                throw AggregationError.tripIdMismatch(expected: tripId, found: fragment.tripId)
            }
        }

        // Filter valid fragments and sort by timestamp
        let validFragments = fragments.filter { fragment in
            if !fragment.hasMinimumWaypoints {
                logWarning("Skipping invalid fragment \(fragment.id): fewer than \(LogFragment.minimumWaypointsRequired) waypoints")
                return false
            }
            return true
        }.sorted()

        guard !validFragments.isEmpty else {
            throw AggregationError.allFragmentsInvalid
        }

        // Build segments with gap detection
        var segments: [RouteSegment] = []
        var allWaypoints: [Waypoint] = []
        var previousFragment: LogFragment?

        for fragment in validFragments {
            // Check for gap with previous fragment
            if let prev = previousFragment {
                let timeDiff = fragment.timestamp.timeIntervalSince(prev.timestamp)

                if timeDiff > gapThreshold {
                    // Insert gap segment between fragments
                    if let lastWaypoint = prev.waypoints.last,
                       let firstWaypoint = fragment.waypoints.first {
                        let gapSegment = RouteSegment(
                            waypoints: [lastWaypoint, firstWaypoint],
                            type: .gap,
                            sourceFragmentId: nil
                        )
                        segments.append(gapSegment)
                    }
                }
            }

            // Add waypoints with fragment ID
            let waypointsWithFragmentId = fragment.waypoints.map { waypoint in
                Waypoint(
                    latitude: waypoint.latitude,
                    longitude: waypoint.longitude,
                    orderId: waypoint.orderId,
                    fragmentId: fragment.id
                )
            }

            // Deduplicate against previous fragment's last waypoint
            let deduplicatedWaypoints: [Waypoint]
            if let lastWaypoint = allWaypoints.last {
                deduplicatedWaypoints = deduplicateWaypoints(
                    waypointsWithFragmentId,
                    against: lastWaypoint
                )
            } else {
                deduplicatedWaypoints = waypointsWithFragmentId
            }

            // Create continuous segment for this fragment
            if !deduplicatedWaypoints.isEmpty {
                let segment = RouteSegment(
                    waypoints: deduplicatedWaypoints,
                    type: .continuous,
                    sourceFragmentId: fragment.id
                )
                segments.append(segment)
                allWaypoints.append(contentsOf: deduplicatedWaypoints)
            }

            previousFragment = fragment
        }

        return UnifiedRoute(
            tripId: tripId,
            waypoints: allWaypoints,
            segments: segments,
            fragmentCount: validFragments.count,
            isComplete: validFragments.count == fragments.count
        )
    }

    // MARK: - Private Methods

    /// Deduplicates waypoints by removing leading duplicates that match the reference waypoint.
    ///
    /// Waypoints are considered duplicates if both latitude and longitude
    /// differ by less than the deduplication tolerance (~1 meter).
    ///
    /// - Parameters:
    ///   - waypoints: Waypoints to deduplicate
    ///   - reference: Reference waypoint to compare against
    /// - Returns: Waypoints with leading duplicates removed
    private func deduplicateWaypoints(
        _ waypoints: [Waypoint],
        against reference: Waypoint
    ) -> [Waypoint] {
        guard let first = waypoints.first else { return waypoints }

        if areWaypointsNearlyEqual(first, reference) {
            return Array(waypoints.dropFirst())
        }

        return waypoints
    }

    /// Checks if two waypoints are nearly equal within the deduplication tolerance.
    ///
    /// - Parameters:
    ///   - lhs: First waypoint
    ///   - rhs: Second waypoint
    /// - Returns: True if waypoints are within tolerance
    private func areWaypointsNearlyEqual(_ lhs: Waypoint, _ rhs: Waypoint) -> Bool {
        let latDiff = abs(lhs.latitude - rhs.latitude)
        let lonDiff = abs(lhs.longitude - rhs.longitude)
        return latDiff < Self.deduplicationTolerance && lonDiff < Self.deduplicationTolerance
    }
}
