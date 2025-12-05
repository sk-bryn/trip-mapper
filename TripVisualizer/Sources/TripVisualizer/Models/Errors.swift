import Foundation

/// Errors that can occur during trip visualization
///
/// Exit codes follow the contract defined in cli-interface.md:
/// - 0: Success
/// - 1: Invalid input (bad UUID, missing args)
/// - 2: Network error (API unreachable, timeout)
/// - 3: Data error (trip not found, no route data, < 2 waypoints)
/// - 4: Output error (cannot write files)
/// - 5: Configuration error (missing env vars, bad config file)
public enum TripVisualizerError: Error, Equatable {

    // MARK: - Exit Code 1: Invalid Input

    /// Trip ID is not a valid UUID format
    case invalidUUID(String)

    /// Missing required argument
    case missingArgument(String)

    // MARK: - Exit Code 2: Network Error

    /// Network request timed out
    case networkTimeout

    /// API is unreachable
    case networkUnreachable(String)

    /// HTTP error response
    case httpError(statusCode: Int, message: String)

    /// Rate limit exceeded
    case rateLimitExceeded

    // MARK: - Exit Code 3: Data Error

    /// No logs found for the trip ID
    case tripNotFound(UUID)

    /// Multiple logs found (data integrity issue)
    case multipleLogsFound(UUID, count: Int)

    /// Not enough waypoints to visualize route
    case insufficientWaypoints(count: Int)

    /// No route data in the log
    case noRouteData

    /// Invalid coordinate data
    case invalidCoordinates(String)

    // MARK: - Exit Code 4: Output Error

    /// Cannot write to output directory
    case cannotWriteOutput(path: String, reason: String)

    /// Cannot create output file
    case fileCreationFailed(path: String)

    // MARK: - Exit Code 5: Configuration Error

    /// Missing environment variable
    case missingEnvironmentVariable(String)

    /// Invalid configuration file
    case invalidConfigFile(path: String, reason: String)

    /// Configuration file not found
    case configFileNotFound(path: String)
}

// MARK: - Exit Codes

extension TripVisualizerError {
    /// Returns the exit code for this error per cli-interface.md
    public var exitCode: Int32 {
        switch self {
        case .invalidUUID, .missingArgument:
            return 1
        case .networkTimeout, .networkUnreachable, .httpError, .rateLimitExceeded:
            return 2
        case .tripNotFound, .multipleLogsFound, .insufficientWaypoints, .noRouteData, .invalidCoordinates:
            return 3
        case .cannotWriteOutput, .fileCreationFailed:
            return 4
        case .missingEnvironmentVariable, .invalidConfigFile, .configFileNotFound:
            return 5
        }
    }
}

// MARK: - LocalizedError

extension TripVisualizerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidUUID(let value):
            return "Invalid UUID format: '\(value)'. Expected format: 550e8400-e29b-41d4-a716-446655440000"

        case .missingArgument(let name):
            return "Missing required argument: \(name)"

        case .networkTimeout:
            return "Network request timed out. Please check your connection and try again."

        case .networkUnreachable(let host):
            return "Cannot reach \(host). Please check your network connection."

        case .httpError(let statusCode, let message):
            return "HTTP error \(statusCode): \(message)"

        case .rateLimitExceeded:
            return "API rate limit exceeded. Please wait before trying again."

        case .tripNotFound(let tripId):
            return "Trip not found: \(tripId.uuidString). No logs exist for this trip ID."

        case .multipleLogsFound(let tripId, let count):
            return "Data integrity error: Found \(count) logs for trip \(tripId.uuidString). Expected exactly 1."

        case .insufficientWaypoints(let count):
            return "Cannot visualize route: Found only \(count) waypoint(s). A route requires at least 2 waypoints."

        case .noRouteData:
            return "No route data found in the log. The segment_coords field is missing or empty."

        case .invalidCoordinates(let details):
            return "Invalid coordinate data: \(details)"

        case .cannotWriteOutput(let path, let reason):
            return "Cannot write to '\(path)': \(reason)"

        case .fileCreationFailed(let path):
            return "Failed to create file: \(path)"

        case .missingEnvironmentVariable(let name):
            return "Missing required environment variable: \(name)"

        case .invalidConfigFile(let path, let reason):
            return "Invalid configuration file '\(path)': \(reason)"

        case .configFileNotFound(let path):
            return "Configuration file not found: \(path)"
        }
    }
}

// MARK: - CustomStringConvertible

extension TripVisualizerError: CustomStringConvertible {
    public var description: String {
        errorDescription ?? "Unknown error"
    }
}
