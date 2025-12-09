import Foundation

/// Root entity for the JSON data export file.
///
/// TripDataExport contains all information needed to verify a trip visualization
/// against its source DataDog logs. The export is generated automatically for
/// every visualization and saved as `<tripId>-data.json`.
///
/// ## Usage
/// ```swift
/// let export = TripDataExport.from(
///     tripId: tripUUID,
///     logs: logFragments,
///     route: unifiedRoute,
///     metadata: tripMetadata
/// )
/// let data = try JSONEncoder().encode(export)
/// ```
public struct TripDataExport: Codable, Equatable, Sendable {

    // MARK: - Properties

    /// The trip identifier matching the visualization
    public let tripId: UUID

    /// ISO8601 timestamp when export was generated
    public let generatedAt: Date

    /// Aggregate statistics for the trip
    public let summary: ExportSummary

    /// Ordered list of all orderIds in delivery sequence (first occurrence)
    public let orderSequence: [String]

    /// Array of route segment details
    public let routeSegments: [RouteSegmentExport]

    // MARK: - Initialization

    public init(
        tripId: UUID,
        generatedAt: Date,
        summary: ExportSummary,
        orderSequence: [String],
        routeSegments: [RouteSegmentExport]
    ) {
        self.tripId = tripId
        self.generatedAt = generatedAt
        self.summary = summary
        self.orderSequence = orderSequence
        self.routeSegments = routeSegments
    }
}

// MARK: - Factory Methods

extension TripDataExport {
    /// Creates a TripDataExport from existing trip visualization data.
    ///
    /// - Parameters:
    ///   - tripId: The trip UUID
    ///   - logs: Array of LogFragment from DataDog (ordered by timestamp)
    ///   - route: The UnifiedRoute with aggregated waypoints
    ///   - metadata: TripMetadata with processing info
    /// - Returns: A populated TripDataExport ready for serialization
    public static func from(
        tripId: UUID,
        logs: [LogFragment],
        route: UnifiedRoute,
        metadata: TripMetadata
    ) -> TripDataExport {
        // Build route segment exports
        let routeSegments = logs.enumerated().map { index, fragment in
            RouteSegmentExport.from(index: index, fragment: fragment)
        }

        // Extract unique orderIds in first-occurrence order
        let orderSequence = extractOrderSequence(from: logs)

        // Calculate total waypoints from logs
        let totalWaypoints = logs.reduce(0) { $0 + $1.waypointCount }

        // Build summary
        let summary = ExportSummary(
            totalRouteSegments: logs.count,
            totalWaypoints: totalWaypoints,
            totalOrders: orderSequence.count,
            hasGaps: route.hasGaps,
            truncated: metadata.truncated,
            incompleteData: !route.isComplete
        )

        return TripDataExport(
            tripId: tripId,
            generatedAt: Date(),
            summary: summary,
            orderSequence: orderSequence,
            routeSegments: routeSegments
        )
    }

    /// Extracts unique orderIds from all logs in first-occurrence order.
    ///
    /// - Parameter logs: Array of LogFragment to extract orderIds from
    /// - Returns: Array of orderId strings in the order they first appear
    private static func extractOrderSequence(from logs: [LogFragment]) -> [String] {
        var seen = Set<String>()
        var sequence: [String] = []

        for log in logs {
            for waypoint in log.waypoints {
                guard let orderId = waypoint.orderId else { continue }
                let orderIdString = orderId.uuidString

                if !seen.contains(orderIdString) {
                    seen.insert(orderIdString)
                    sequence.append(orderIdString)
                }
            }
        }

        return sequence
    }
}

// MARK: - Validation

extension TripDataExport {
    /// Returns true if the export is valid
    public var isValid: Bool {
        !routeSegments.isEmpty &&
        summary.totalRouteSegments == routeSegments.count &&
        summary.totalOrders == orderSequence.count
    }
}

// MARK: - CustomStringConvertible

extension TripDataExport: CustomStringConvertible {
    public var description: String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]
        let timestampStr = dateFormatter.string(from: generatedAt)
        return "TripDataExport(trip: \(tripId.uuidString.prefix(8))..., \(summary.totalRouteSegments) segments, \(summary.totalWaypoints) waypoints, \(summary.totalOrders) orders, generated: \(timestampStr))"
    }
}
