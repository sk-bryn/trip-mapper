import Foundation
import ArgumentParser

/// Main CLI entry point for Trip Visualizer
///
/// Provides commands for visualizing trip routes from DataDog logs
/// onto Google Maps.
struct TripVisualizerCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tripvisualizer",
        abstract: "Visualize trip routes from DataDog logs on Google Maps",
        discussion: """
            Trip Visualizer fetches trip route data from DataDog logs and generates
            map visualizations using Google Maps APIs.

            Required environment variables:
              DD_API_KEY          - DataDog API key
              DD_APP_KEY          - DataDog Application key
              GOOGLE_MAPS_API_KEY - Google Maps API key

            Configuration can be provided via:
              1. --config flag with path to JSON config file
              2. ./config.json in current directory
              3. ~/.tripvisualizer/config.json

            Examples:
              tripvisualizer 123e4567-e89b-12d3-a456-426614174000
              tripvisualizer 123e4567-e89b-12d3-a456-426614174000 -f html -f image
              tripvisualizer 123e4567-e89b-12d3-a456-426614174000 --output ./maps
            """,
        version: "0.1.0"
    )

    // MARK: - Arguments

    @Argument(help: "The trip UUID to visualize")
    var tripId: String

    // MARK: - Options

    @Option(name: [.short, .customLong("format")], help: "Output format(s): image, html, url, all")
    var formats: [String] = []

    @Option(name: [.short, .customLong("output")], help: "Output directory for generated files")
    var outputDirectory: String?

    @Option(name: [.short, .customLong("config")], help: "Path to configuration file")
    var configPath: String?

    @Flag(name: .shortAndLong, help: "Enable verbose (debug) output")
    var verbose: Bool = false

    @Flag(name: .shortAndLong, help: "Suppress all output except errors")
    var quiet: Bool = false

    // MARK: - Execution

    mutating func run() throws {
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

        // Run async code synchronously
        let semaphore = DispatchSemaphore(value: 0)
        var asyncError: Error?

        Task {
            do {
                let visualizer = try TripVisualizerService(configuration: config)
                try await visualizer.visualize(tripId: tripUUID)
                logInfo("Visualization complete")
            } catch {
                asyncError = error
            }
            semaphore.signal()
        }

        semaphore.wait()

        if let error = asyncError {
            if let vizError = error as? TripVisualizerError {
                logError(vizError.localizedDescription)
                throw ExitCode(Int32(vizError.exitCode))
            } else {
                logError(error.localizedDescription)
                throw ExitCode.failure
            }
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
