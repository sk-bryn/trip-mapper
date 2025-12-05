import Foundation

/// Service for parsing DataDog log entries and extracting waypoints
///
/// Handles extraction of segment_coords from log attributes
/// and conversion to Waypoint models with validation.
public final class LogParser {

    // MARK: - Constants

    /// Minimum number of waypoints required for a valid route
    public static let minimumWaypoints = 2

    // MARK: - Initialization

    public init() {}

    // MARK: - Public Methods

    /// Parses a DataDog log entry and extracts waypoints
    /// - Parameter logEntry: The log entry to parse
    /// - Returns: Array of waypoints extracted from segment_coords
    /// - Throws: `TripVisualizerError` if no route data or insufficient waypoints
    public func parseLogEntry(_ logEntry: DataDogLogEntry) throws -> [Waypoint] {
        guard let segmentCoords = logEntry.attributes.attributes["segment_coords"] as? [[String: Any]] else {
            logWarning("No segment_coords found in log entry \(logEntry.id)")
            throw TripVisualizerError.noRouteData
        }

        return try extractWaypoints(from: segmentCoords)
    }

    /// Extracts waypoints from segment_coords array
    /// - Parameter segmentCoords: Array of coordinate dictionaries
    /// - Returns: Array of validated waypoints
    /// - Throws: `TripVisualizerError` if empty or insufficient waypoints
    public func extractWaypoints(from segmentCoords: [[String: Any]]) throws -> [Waypoint] {
        guard !segmentCoords.isEmpty else {
            throw TripVisualizerError.noRouteData
        }

        var waypoints: [Waypoint] = []

        for (index, coord) in segmentCoords.enumerated() {
            if let waypoint = parseCoordinate(coord, index: index) {
                waypoints.append(waypoint)
            }
        }

        // Validate minimum waypoints
        guard waypoints.count >= Self.minimumWaypoints else {
            if waypoints.isEmpty {
                throw TripVisualizerError.noRouteData
            } else {
                throw TripVisualizerError.insufficientWaypoints(count: waypoints.count)
            }
        }

        logDebug("Extracted \(waypoints.count) waypoints from \(segmentCoords.count) coordinates")
        return waypoints
    }

    // MARK: - Private Methods

    /// Parses a single coordinate dictionary into a Waypoint
    /// - Parameters:
    ///   - coord: Coordinate dictionary with lat/lng keys
    ///   - index: Index for logging purposes
    /// - Returns: Waypoint if valid, nil otherwise
    private func parseCoordinate(_ coord: [String: Any], index: Int) -> Waypoint? {
        // Extract latitude
        guard let latitude = extractDouble(from: coord, key: "lat") else {
            logWarning("Invalid or missing latitude at index \(index)")
            return nil
        }

        // Extract longitude
        guard let longitude = extractDouble(from: coord, key: "lng") else {
            logWarning("Invalid or missing longitude at index \(index)")
            return nil
        }

        // Validate coordinate ranges
        guard Waypoint.isValidLatitude(latitude) else {
            logWarning("Latitude \(latitude) out of range at index \(index)")
            return nil
        }

        guard Waypoint.isValidLongitude(longitude) else {
            logWarning("Longitude \(longitude) out of range at index \(index)")
            return nil
        }

        // Extract optional order ID
        let orderId: UUID?
        if let orderIdString = coord["order_id"] as? String {
            orderId = UUID(uuidString: orderIdString)
        } else {
            orderId = nil
        }

        return Waypoint(latitude: latitude, longitude: longitude, orderId: orderId)
    }

    /// Extracts a Double value from a dictionary, handling both Double and String types
    /// - Parameters:
    ///   - dict: Dictionary to extract from
    ///   - key: Key to look up
    /// - Returns: Double value if found and valid, nil otherwise
    private func extractDouble(from dict: [String: Any], key: String) -> Double? {
        if let value = dict[key] as? Double {
            return value
        } else if let value = dict[key] as? Int {
            return Double(value)
        } else if let value = dict[key] as? String, let doubleValue = Double(value) {
            return doubleValue
        }
        return nil
    }
}
