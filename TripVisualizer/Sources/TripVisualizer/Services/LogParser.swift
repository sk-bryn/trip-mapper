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

    /// Parses a DataDog log entry into a LogFragment.
    ///
    /// This method extracts waypoints from the log entry and creates a LogFragment
    /// with all necessary metadata for multi-log trip aggregation.
    ///
    /// Logs without coordinate data are silently ignored and return nil.
    ///
    /// - Parameters:
    ///   - logEntry: The log entry to parse
    ///   - tripId: The trip UUID this fragment belongs to
    ///   - logLinkGenerator: Closure to generate DataDog log link
    /// - Returns: LogFragment if log contains valid coordinate data, nil otherwise
    public func parseToLogFragment(
        _ logEntry: DataDogLogEntry,
        tripId: UUID,
        logLinkGenerator: (String) -> String
    ) -> LogFragment? {
        guard let waypoints = extractWaypointsIfPresent(from: logEntry) else {
            // Log has no coordinate data - silently ignore
            return nil
        }

        // Parse timestamp from log entry
        let timestamp = parseTimestamp(logEntry.attributes.timestamp)

        return LogFragment(
            id: logEntry.id,
            tripId: tripId,
            timestamp: timestamp,
            waypoints: waypoints,
            logLink: logLinkGenerator(logEntry.id)
        )
    }

    /// Extracts waypoints from a log entry if coordinate data is present.
    /// - Parameter logEntry: The log entry to parse
    /// - Returns: Array of waypoints if valid coordinate data exists, nil otherwise
    private func extractWaypointsIfPresent(from logEntry: DataDogLogEntry) -> [Waypoint]? {
        guard let segmentCoords = findSegmentCoords(in: logEntry.attributes.attributes) else {
            return nil
        }

        var waypoints: [Waypoint] = []
        for (index, coord) in segmentCoords.enumerated() {
            if let waypoint = parseCoordinate(coord, index: index) {
                waypoints.append(waypoint)
            }
        }

        // Need minimum waypoints for a valid route
        guard waypoints.count >= Self.minimumWaypoints else {
            return nil
        }

        return waypoints
    }

    /// Legacy method - Parses a DataDog log entry into a LogFragment.
    /// - Throws: `TripVisualizerError` if no route data or insufficient waypoints
    @available(*, deprecated, message: "Use parseToLogFragment which returns nil for logs without coordinates")
    public func parseToFragment(
        _ logEntry: DataDogLogEntry,
        tripId: UUID,
        logLinkGenerator: (String) -> String
    ) throws -> LogFragment {
        guard let fragment = parseToLogFragment(logEntry, tripId: tripId, logLinkGenerator: logLinkGenerator) else {
            throw TripVisualizerError.noRouteData
        }
        return fragment
    }

    /// Parses ISO 8601 timestamp string to Date
    /// - Parameter timestampString: ISO 8601 formatted timestamp
    /// - Returns: Parsed Date, or current date if parsing fails
    private func parseTimestamp(_ timestampString: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: timestampString) {
            return date
        }

        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: timestampString) {
            return date
        }

        logWarning("Failed to parse timestamp: \(timestampString), using current date")
        return Date()
    }

    /// Parses a DataDog log entry and extracts waypoints
    /// - Parameter logEntry: The log entry to parse
    /// - Returns: Array of waypoints extracted from segment_coords
    /// - Throws: `TripVisualizerError` if no route data or insufficient waypoints
    public func parseLogEntry(_ logEntry: DataDogLogEntry) throws -> [Waypoint] {
        // Try multiple paths to find segment_coords
        if let segmentCoords = findSegmentCoords(in: logEntry.attributes.attributes) {
            return try extractWaypoints(from: segmentCoords)
        }

        // No coordinate data - not an error, just no route data in this log
        throw TripVisualizerError.noRouteData
    }

    /// Searches for segment_coords in various nested locations
    private func findSegmentCoords(in attributes: [String: Any]) -> [[String: Any]]? {
        // Direct path: attributes.segment_coords
        if let coords = attributes["segment_coords"] as? [[String: Any]], !coords.isEmpty {
            return coords
        }

        // Nested path: attributes.request.Msg.segment_coords
        if let request = attributes["request"] as? [String: Any],
           let msg = request["Msg"] as? [String: Any],
           let coords = msg["segment_coords"] as? [[String: Any]], !coords.isEmpty {
            return coords
        }

        // Alternative: request might be an array
        if let request = attributes["request"] as? [[String: Any]],
           let first = request.first,
           let msg = first["Msg"] as? [String: Any],
           let coords = msg["segment_coords"] as? [[String: Any]], !coords.isEmpty {
            return coords
        }

        return nil
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
    ///   - coord: Coordinate dictionary with lat/lng or coordinates.latitude/longitude keys
    ///   - index: Index for logging purposes
    /// - Returns: Waypoint if valid, nil otherwise
    private func parseCoordinate(_ coord: [String: Any], index: Int) -> Waypoint? {
        var latitude: Double?
        var longitude: Double?

        // Try direct keys: lat/lng
        latitude = extractDouble(from: coord, key: "lat")
        longitude = extractDouble(from: coord, key: "lng")

        // Try nested: coordinates.latitude/longitude
        if latitude == nil || longitude == nil {
            if let coordinates = coord["coordinates"] as? [String: Any] {
                latitude = extractDouble(from: coordinates, key: "latitude")
                longitude = extractDouble(from: coordinates, key: "longitude")
            }
        }

        // Validate we have both
        guard let lat = latitude else {
            logWarning("Invalid or missing latitude at index \(index)")
            return nil
        }

        guard let lng = longitude else {
            logWarning("Invalid or missing longitude at index \(index)")
            return nil
        }

        // Validate coordinate ranges
        guard Waypoint.isValidLatitude(lat) else {
            logWarning("Latitude \(lat) out of range at index \(index)")
            return nil
        }

        guard Waypoint.isValidLongitude(lng) else {
            logWarning("Longitude \(lng) out of range at index \(index)")
            return nil
        }

        // Extract optional order ID
        let orderId: UUID?
        if let orderIdString = coord["order_id"] as? String {
            orderId = UUID(uuidString: orderIdString)
        } else {
            orderId = nil
        }

        return Waypoint(latitude: lat, longitude: lng, orderId: orderId)
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
