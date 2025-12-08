import Foundation

/// Represents one route segment correlated to its source DataDog log entry.
///
/// RouteSegmentExport provides the essential information needed to verify
/// a rendered route segment against its source DataDog log. Each segment
/// maps 1:1 with a LogFragment.
///
/// ## Usage
/// ```swift
/// let segment = RouteSegmentExport.from(index: 0, fragment: logFragment)
/// print(segment.datadogUrl) // Opens log in DataDog console
/// ```
public struct RouteSegmentExport: Codable, Equatable, Sendable {

    // MARK: - Properties

    /// 0-based index in segment sequence
    public let segmentIndex: Int

    /// DataDog log entry ID for cross-reference
    public let datadogLogId: String

    /// Direct URL to view log in DataDog console
    public let datadogUrl: String

    /// Timestamp from DataDog log
    public let timestamp: Date

    /// Number of waypoints in this segment
    public let waypointCount: Int

    /// Order details for this segment (may be empty)
    public let orders: [OrderSummary]

    // MARK: - Initialization

    public init(
        segmentIndex: Int,
        datadogLogId: String,
        datadogUrl: String,
        timestamp: Date,
        waypointCount: Int,
        orders: [OrderSummary]
    ) {
        self.segmentIndex = segmentIndex
        self.datadogLogId = datadogLogId
        self.datadogUrl = datadogUrl
        self.timestamp = timestamp
        self.waypointCount = waypointCount
        self.orders = orders
    }
}

// MARK: - Factory Methods

extension RouteSegmentExport {
    /// Creates a RouteSegmentExport from a LogFragment.
    ///
    /// - Parameters:
    ///   - index: The segment's position in the sequence
    ///   - fragment: The source LogFragment
    /// - Returns: A populated RouteSegmentExport
    public static func from(index: Int, fragment: LogFragment) -> RouteSegmentExport {
        // Group waypoints by orderId and count them
        let orderSummaries = Self.groupWaypointsByOrder(fragment.waypoints)

        return RouteSegmentExport(
            segmentIndex: index,
            datadogLogId: fragment.id,
            datadogUrl: fragment.logLink,
            timestamp: fragment.timestamp,
            waypointCount: fragment.waypointCount,
            orders: orderSummaries
        )
    }

    /// Groups waypoints by orderId and creates OrderSummary for each.
    ///
    /// - Parameter waypoints: Array of waypoints to group
    /// - Returns: Array of OrderSummary, one per unique orderId
    private static func groupWaypointsByOrder(_ waypoints: [Waypoint]) -> [OrderSummary] {
        // Count waypoints per orderId, maintaining first-occurrence order
        var orderCounts: [String: Int] = [:]
        var orderSequence: [String] = []

        for waypoint in waypoints {
            guard let orderId = waypoint.orderId else { continue }

            let orderIdString = orderId.uuidString

            if orderCounts[orderIdString] == nil {
                orderSequence.append(orderIdString)
            }
            orderCounts[orderIdString, default: 0] += 1
        }

        // Build OrderSummary array in first-occurrence order
        return orderSequence.compactMap { orderId in
            guard let count = orderCounts[orderId] else { return nil }
            return OrderSummary(orderId: orderId, waypointCount: count)
        }
    }
}

// MARK: - Validation

extension RouteSegmentExport {
    /// Returns true if the segment export is valid
    public var isValid: Bool {
        segmentIndex >= 0 &&
        !datadogLogId.isEmpty &&
        !datadogUrl.isEmpty &&
        waypointCount >= 0
    }
}

// MARK: - CustomStringConvertible

extension RouteSegmentExport: CustomStringConvertible {
    public var description: String {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime]
        let timestampStr = dateFormatter.string(from: timestamp)
        return "RouteSegmentExport([\(segmentIndex)] \(datadogLogId.prefix(8))..., \(waypointCount) waypoints, \(orders.count) orders, \(timestampStr))"
    }
}
