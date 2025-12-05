import Foundation

/// Utility for reading environment variables securely
///
/// API credentials are read from environment variables per constitution Security-First principle.
/// Never hardcode or pass credentials via command-line arguments.
public struct Environment {

    // MARK: - Environment Variable Names

    /// DataDog API key environment variable name
    public static let datadogAPIKeyName = "DD_API_KEY"

    /// DataDog Application key environment variable name
    public static let datadogAppKeyName = "DD_APP_KEY"

    /// Google Maps API key environment variable name
    public static let googleMapsAPIKeyName = "GOOGLE_MAPS_API_KEY"

    // MARK: - API Keys

    /// Returns the DataDog API key from environment
    /// - Throws: `TripVisualizerError.missingEnvironmentVariable` if not set
    public static func datadogAPIKey() throws -> String {
        try requireEnvironmentVariable(datadogAPIKeyName)
    }

    /// Returns the DataDog Application key from environment
    /// - Throws: `TripVisualizerError.missingEnvironmentVariable` if not set
    public static func datadogAppKey() throws -> String {
        try requireEnvironmentVariable(datadogAppKeyName)
    }

    /// Returns the Google Maps API key from environment
    /// - Throws: `TripVisualizerError.missingEnvironmentVariable` if not set
    public static func googleMapsAPIKey() throws -> String {
        try requireEnvironmentVariable(googleMapsAPIKeyName)
    }

    // MARK: - Generic Environment Access

    /// Gets an environment variable value
    /// - Parameter name: The environment variable name
    /// - Returns: The value if set, nil otherwise
    public static func get(_ name: String) -> String? {
        ProcessInfo.processInfo.environment[name]
    }

    /// Gets a required environment variable
    /// - Parameter name: The environment variable name
    /// - Returns: The value
    /// - Throws: `TripVisualizerError.missingEnvironmentVariable` if not set
    public static func requireEnvironmentVariable(_ name: String) throws -> String {
        guard let value = get(name), !value.isEmpty else {
            throw TripVisualizerError.missingEnvironmentVariable(name)
        }
        return value
    }

    // MARK: - Validation

    /// Validates that all required API keys are set
    /// - Throws: `TripVisualizerError.missingEnvironmentVariable` for the first missing key
    public static func validateRequiredKeys() throws {
        _ = try datadogAPIKey()
        _ = try datadogAppKey()
        _ = try googleMapsAPIKey()
    }

    /// Returns a list of missing required environment variables
    public static func missingRequiredKeys() -> [String] {
        var missing: [String] = []

        if get(datadogAPIKeyName) == nil {
            missing.append(datadogAPIKeyName)
        }
        if get(datadogAppKeyName) == nil {
            missing.append(datadogAppKeyName)
        }
        if get(googleMapsAPIKeyName) == nil {
            missing.append(googleMapsAPIKeyName)
        }

        return missing
    }

    // MARK: - Redaction

    /// Redacts a sensitive value for safe logging
    /// Shows first 4 characters and masks the rest
    public static func redact(_ value: String) -> String {
        guard value.count > 4 else {
            return String(repeating: "*", count: value.count)
        }
        let prefix = String(value.prefix(4))
        let maskedLength = max(0, value.count - 4)
        return prefix + String(repeating: "*", count: maskedLength)
    }
}
