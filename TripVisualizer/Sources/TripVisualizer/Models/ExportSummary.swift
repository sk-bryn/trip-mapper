import Foundation

/// Aggregate statistics providing a quick overview of the trip export.
///
/// ExportSummary contains counts and flags that summarize the entire trip,
/// allowing quick verification without parsing individual route segments.
///
/// ## Usage
/// ```swift
/// let summary = ExportSummary(
///     totalRouteSegments: 5,
///     totalWaypoints: 270,
///     totalOrders: 3,
///     hasGaps: true,
///     truncated: false,
///     incompleteData: false
/// )
/// ```
public struct ExportSummary: Codable, Equatable, Sendable {

    // MARK: - Properties

    /// Number of route segments (DataDog logs)
    public let totalRouteSegments: Int

    /// Sum of waypoints across all segments
    public let totalWaypoints: Int

    /// Count of unique orderIds
    public let totalOrders: Int

    /// True if gaps were detected between segments
    public let hasGaps: Bool

    /// True if logs exceeded max limit (50)
    public let truncated: Bool

    /// True if any log fragments failed to download
    public let incompleteData: Bool

    // MARK: - Initialization

    public init(
        totalRouteSegments: Int,
        totalWaypoints: Int,
        totalOrders: Int,
        hasGaps: Bool,
        truncated: Bool,
        incompleteData: Bool
    ) {
        self.totalRouteSegments = totalRouteSegments
        self.totalWaypoints = totalWaypoints
        self.totalOrders = totalOrders
        self.hasGaps = hasGaps
        self.truncated = truncated
        self.incompleteData = incompleteData
    }
}

// MARK: - Validation

extension ExportSummary {
    /// Returns true if all counts are non-negative
    public var isValid: Bool {
        totalRouteSegments >= 0 && totalWaypoints >= 0 && totalOrders >= 0
    }
}

// MARK: - CustomStringConvertible

extension ExportSummary: CustomStringConvertible {
    public var description: String {
        var parts: [String] = []
        parts.append("\(totalRouteSegments) segments")
        parts.append("\(totalWaypoints) waypoints")
        parts.append("\(totalOrders) orders")

        if hasGaps {
            parts.append("has gaps")
        }
        if truncated {
            parts.append("truncated")
        }
        if incompleteData {
            parts.append("incomplete")
        }

        return "ExportSummary(\(parts.joined(separator: ", ")))"
    }
}
