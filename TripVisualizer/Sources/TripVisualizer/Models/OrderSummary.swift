import Foundation

/// Aggregated information about one order within a route segment.
///
/// OrderSummary provides a count of waypoints associated with a specific
/// orderId within a single route segment. This allows verification of
/// delivery progress without exposing individual waypoint coordinates.
///
/// ## Usage
/// ```swift
/// let summary = OrderSummary(orderId: "ORD-001", waypointCount: 25)
/// ```
public struct OrderSummary: Codable, Equatable, Sendable {

    // MARK: - Properties

    /// The order identifier from waypoint data
    public let orderId: String

    /// Number of waypoints with this orderId in the segment
    public let waypointCount: Int

    // MARK: - Initialization

    public init(orderId: String, waypointCount: Int) {
        self.orderId = orderId
        self.waypointCount = waypointCount
    }
}

// MARK: - Validation

extension OrderSummary {
    /// Returns true if the summary is valid (non-empty orderId, positive count)
    public var isValid: Bool {
        !orderId.isEmpty && waypointCount > 0
    }
}

// MARK: - CustomStringConvertible

extension OrderSummary: CustomStringConvertible {
    public var description: String {
        "OrderSummary(\(orderId), \(waypointCount) waypoints)"
    }
}
