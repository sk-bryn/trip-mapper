import Foundation

/// Service for loading configuration from JSON files
///
/// Configuration is loaded from the following locations (in priority order):
/// 1. Custom path specified via --config flag
/// 2. `./config.json` (current directory)
/// 3. `~/.tripvisualizer/config.json` (home directory)
/// 4. Default configuration
public struct ConfigurationLoader {

    // MARK: - Configuration Paths

    /// Standard configuration file name
    public static let configFileName = "config.json"

    /// Home directory configuration folder
    public static let homeConfigFolder = ".tripvisualizer"

    // MARK: - Loading

    /// Loads configuration from a specific file path
    /// - Parameter path: Path to the configuration file
    /// - Returns: Loaded configuration
    /// - Throws: `TripVisualizerError` if file cannot be read or parsed
    public static func load(from path: String) throws -> Configuration {
        let fileManager = FileManager.default

        // Expand tilde in path
        let expandedPath = (path as NSString).expandingTildeInPath

        guard fileManager.fileExists(atPath: expandedPath) else {
            throw TripVisualizerError.configFileNotFound(path: path)
        }

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: expandedPath))
            let decoder = JSONDecoder()
            return try decoder.decode(Configuration.self, from: data)
        } catch let error as TripVisualizerError {
            throw error
        } catch let error as DecodingError {
            throw TripVisualizerError.invalidConfigFile(path: path, reason: describeDecodingError(error))
        } catch {
            throw TripVisualizerError.invalidConfigFile(path: path, reason: error.localizedDescription)
        }
    }

    /// Loads configuration using the standard discovery order
    /// - Parameter customPath: Optional custom path (highest priority)
    /// - Returns: Loaded configuration or default
    public static func loadWithDiscovery(customPath: String? = nil) -> Configuration {
        // Priority 1: Custom path
        if let path = customPath {
            do {
                return try load(from: path)
            } catch {
                logWarning("Could not load config from \(path): \(error.localizedDescription)")
            }
        }

        // Priority 2: Current directory
        let currentDirConfig = configFileName
        if FileManager.default.fileExists(atPath: currentDirConfig) {
            do {
                return try load(from: currentDirConfig)
            } catch {
                logWarning("Could not load config from \(currentDirConfig): \(error.localizedDescription)")
            }
        }

        // Priority 3: Home directory
        let homeConfig = homeConfigPath()
        if FileManager.default.fileExists(atPath: homeConfig) {
            do {
                return try load(from: homeConfig)
            } catch {
                logWarning("Could not load config from \(homeConfig): \(error.localizedDescription)")
            }
        }

        // Priority 4: Default configuration
        logDebug("Using default configuration")
        return .defaultConfig
    }

    // MARK: - Paths

    /// Returns the path to the home directory configuration file
    public static func homeConfigPath() -> String {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let configFolder = (homeDir as NSString).appendingPathComponent(homeConfigFolder)
        return (configFolder as NSString).appendingPathComponent(configFileName)
    }

    /// Returns the path to the current directory configuration file
    public static func currentDirConfigPath() -> String {
        configFileName
    }

    // MARK: - Helpers

    private static func describeDecodingError(_ error: DecodingError) -> String {
        switch error {
        case .typeMismatch(let type, let context):
            return "Type mismatch for \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
        case .valueNotFound(let type, let context):
            return "Missing value for \(type) at \(context.codingPath.map { $0.stringValue }.joined(separator: "."))"
        case .keyNotFound(let key, _):
            return "Missing key: \(key.stringValue)"
        case .dataCorrupted(let context):
            return "Data corrupted: \(context.debugDescription)"
        @unknown default:
            return error.localizedDescription
        }
    }
}

// MARK: - Configuration Merging

extension Configuration {
    /// Creates a new configuration by merging CLI overrides with this configuration
    /// - Parameters:
    ///   - outputDirectory: Override output directory
    ///   - outputFormats: Override output formats
    ///   - verbose: Enable debug logging
    ///   - quiet: Suppress all but error logging
    /// - Returns: New configuration with overrides applied
    public func withOverrides(
        outputDirectory: String? = nil,
        outputFormats: [OutputFormat]? = nil,
        verbose: Bool = false,
        quiet: Bool = false
    ) -> Configuration {
        var config = self

        if let dir = outputDirectory {
            config.outputDirectory = dir
        }

        if let formats = outputFormats {
            config.outputFormats = formats
        }

        if verbose {
            config.logLevel = .debug
        } else if quiet {
            config.logLevel = .error
        }

        return config
    }
}
