import Foundation
import ArgumentParser

/// Main CLI entry point for Trip Visualizer
///
/// Provides commands for visualizing trip routes from DataDog logs
/// onto Google Maps.
struct TripVisualizerCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tripvisualizer",
        abstract: "Visualize trip routes from DataDog logs on Google Maps",
        discussion: """
            Trip Visualizer fetches trip route data from DataDog logs and generates
            map visualizations using Google Maps APIs. It supports multiple output
            formats and flexible configuration options.

            REQUIRED ENVIRONMENT VARIABLES:
              DD_API_KEY          DataDog API key for authentication
              DD_APP_KEY          DataDog Application key for authorization
              GOOGLE_MAPS_API_KEY Google Maps API key for map generation

            CONFIGURATION:
              Configuration is loaded from the following locations (in priority order):
              1. Path specified via --config flag
              2. ./config.json (current directory)
              3. ~/.tripvisualizer/config.json (home directory)
              4. Built-in defaults

              Configuration file format (JSON):
              {
                "outputDirectory": "output",
                "outputFormats": ["image", "html"],
                "datadogRegion": "us1",
                "datadogEnv": "prod",
                "datadogService": "delivery-driver-service",
                "mapWidth": 800,
                "mapHeight": 600,
                "routeColor": "0000FF",
                "routeWeight": 4,
                "logLevel": "info",
                "retryAttempts": 3,
                "timeoutSeconds": 30
              }

            OUTPUT FORMATS:
              image  Static PNG map image via Google Maps Static API
              html   Interactive HTML map with pan/zoom controls
              url    Print Google Maps URLs to stdout (no file created)
              all    Generate all formats

            LOGGING:
              Logs are written to both stderr and a trip-specific log file:
              logs/<trip-uuid>-<timestamp>.log

            EXIT CODES:
              0  Success
              1  Environment error (missing API keys)
              2  Network error (API failures, timeouts)
              3  Data error (invalid trip ID, no route data)
              4  Output error (cannot write files)

            EXAMPLES:
              # Basic usage with default settings
              tripvisualizer 123e4567-e89b-12d3-a456-426614174000

              # Generate specific formats
              tripvisualizer 123e4567-e89b-12d3-a456-426614174000 -f html -f image

              # Custom output directory
              tripvisualizer 123e4567-e89b-12d3-a456-426614174000 --output ./maps

              # Use custom config and verbose logging
              tripvisualizer 123e4567-e89b-12d3-a456-426614174000 -c myconfig.json -v

              # Generate all formats quietly
              tripvisualizer 123e4567-e89b-12d3-a456-426614174000 -f all -q
            """,
        version: "1.0.0"
    )

    // MARK: - Arguments

    @Argument(help: ArgumentHelp(
        "The trip UUID to visualize.",
        discussion: "Must be a valid UUID format (e.g., 123e4567-e89b-12d3-a456-426614174000).",
        valueName: "trip-uuid"
    ))
    var tripId: String

    // MARK: - Options

    @Option(name: [.short, .customLong("format")], help: ArgumentHelp(
        "Output format(s) to generate.",
        discussion: "Can be specified multiple times. Valid values: image, html, url, all.",
        valueName: "format"
    ))
    var formats: [String] = []

    @Option(name: [.short, .customLong("output")], help: ArgumentHelp(
        "Output directory for generated files.",
        discussion: "Files are saved as <output>/<trip-uuid>/<trip-uuid>.<ext>. Default: 'output'.",
        valueName: "directory"
    ))
    var outputDirectory: String?

    @Option(name: [.short, .customLong("config")], help: ArgumentHelp(
        "Path to JSON configuration file.",
        discussion: "Overrides default config discovery. See CONFIGURATION section for format.",
        valueName: "path"
    ))
    var configPath: String?

    @Flag(name: .shortAndLong, help: ArgumentHelp(
        "Enable verbose (debug) output.",
        discussion: "Shows detailed progress and diagnostic information."
    ))
    var verbose: Bool = false

    @Flag(name: .shortAndLong, help: ArgumentHelp(
        "Suppress all output except errors.",
        discussion: "Useful for scripting. Overrides --verbose if both specified."
    ))
    var quiet: Bool = false

    // MARK: - Execution

    mutating func run() async throws {
        // Parse and validate trip ID
        guard let tripUUID = UUID(uuidString: tripId) else {
            throw TripVisualizerError.invalidUUID(tripId)
        }

        // Load configuration
        let baseConfig = ConfigurationLoader.loadWithDiscovery(customPath: configPath)

        // Parse output formats
        let outputFormats = parseOutputFormats()

        // Apply CLI overrides
        let config = baseConfig.withOverrides(
            outputDirectory: outputDirectory,
            outputFormats: outputFormats.isEmpty ? nil : outputFormats,
            verbose: verbose,
            quiet: quiet
        )

        // Configure logger
        Logger.shared.logLevel = config.logLevel
        try Logger.shared.configure(
            tripId: tripUUID,
            logLevel: config.logLevel
        )

        logInfo("Starting visualization for trip: \(tripUUID.uuidString)")

        do {
            let visualizer = try TripVisualizerService(configuration: config)
            try await visualizer.visualize(tripId: tripUUID)
            logInfo("Visualization complete")
        } catch let vizError as TripVisualizerError {
            logError(vizError.localizedDescription)
            throw ExitCode(Int32(vizError.exitCode))
        } catch {
            logError(error.localizedDescription)
            throw ExitCode.failure
        }
    }

    // MARK: - Private Methods

    private func parseOutputFormats() -> [OutputFormat] {
        var result: [OutputFormat] = []

        for format in formats {
            switch format.lowercased() {
            case "image", "png":
                result.append(.image)
            case "html":
                result.append(.html)
            case "url":
                result.append(.url)
            case "all":
                return [.image, .html, .url]
            default:
                logWarning("Unknown format '\(format)', ignoring")
            }
        }

        return result
    }
}

// Entry point
TripVisualizerCLI.main()
