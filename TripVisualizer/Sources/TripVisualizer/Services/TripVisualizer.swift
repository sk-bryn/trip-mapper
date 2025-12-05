import Foundation

/// Main orchestrator service for trip visualization
///
/// Coordinates the full pipeline:
/// 1. Fetches logs from DataDog
/// 2. Parses waypoints from log data
/// 3. Generates map outputs in requested formats
public final class TripVisualizerService {

    // MARK: - Properties

    private let configuration: Configuration
    private let dataDogClient: DataDogClient
    private let logParser: LogParser
    private let mapGenerator: MapGenerator

    // MARK: - Initialization

    /// Creates a new TripVisualizerService
    /// - Parameter configuration: Application configuration
    /// - Throws: `TripVisualizerError` if required environment variables are missing
    public init(configuration: Configuration) throws {
        self.configuration = configuration

        // Get required API keys from environment
        let ddAPIKey = try Environment.requireEnvironmentVariable("DD_API_KEY")
        let ddAppKey = try Environment.requireEnvironmentVariable("DD_APP_KEY")
        let googleAPIKey = try Environment.requireEnvironmentVariable("GOOGLE_MAPS_API_KEY")

        self.dataDogClient = DataDogClient(
            apiKey: ddAPIKey,
            appKey: ddAppKey,
            configuration: configuration
        )
        self.logParser = LogParser()
        self.mapGenerator = MapGenerator(apiKey: googleAPIKey)
    }

    /// Creates a TripVisualizerService with custom dependencies (for testing)
    internal init(
        configuration: Configuration,
        dataDogClient: DataDogClient,
        logParser: LogParser,
        mapGenerator: MapGenerator
    ) {
        self.configuration = configuration
        self.dataDogClient = dataDogClient
        self.logParser = logParser
        self.mapGenerator = mapGenerator
    }

    // MARK: - Public Methods

    /// Visualizes a trip by fetching logs and generating outputs
    /// - Parameter tripId: The trip UUID to visualize
    /// - Throws: `TripVisualizerError` on any failure
    public func visualize(tripId: UUID) async throws {
        logInfo("Fetching logs for trip \(tripId.uuidString)")

        // Step 1: Fetch logs from DataDog
        let response = try await dataDogClient.fetchLogs(tripId: tripId)

        // Step 2: Validate response
        let logEntry = try validateLogResponse(response, tripId: tripId)

        logInfo("Found log entry: \(logEntry.id)")

        // Step 3: Parse waypoints
        let waypoints = try logParser.parseLogEntry(logEntry)
        logInfo("Extracted \(waypoints.count) waypoints")

        // Step 4: Create trip model
        let trip = Trip(
            id: tripId,
            logId: logEntry.id,
            logLink: dataDogClient.generateLogLink(logId: logEntry.id),
            waypoints: waypoints,
            timestamp: parseTimestamp(logEntry.attributes.timestamp)
        )

        // Step 5: Generate outputs
        try await generateOutputs(for: trip)
    }

    // MARK: - Private Methods

    /// Validates the DataDog log response
    /// - Parameters:
    ///   - response: DataDog API response
    ///   - tripId: Trip ID for error messages
    /// - Returns: The single log entry
    /// - Throws: `TripVisualizerError` if 0 or >1 logs found
    private func validateLogResponse(_ response: DataDogLogResponse, tripId: UUID) throws -> DataDogLogEntry {
        switch response.data.count {
        case 0:
            throw TripVisualizerError.tripNotFound(tripId)
        case 1:
            return response.data[0]
        default:
            throw TripVisualizerError.multipleLogsFound(tripId, count: response.data.count)
        }
    }

    /// Generates all requested output formats
    /// - Parameter trip: Trip data to visualize
    private func generateOutputs(for trip: Trip) async throws {
        // Ensure output directory exists
        let outputDir = configuration.outputDirectory
        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: outputDir) {
            try fileManager.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
        }

        let baseName = trip.id.uuidString

        for format in configuration.outputFormats {
            switch format {
            case .html:
                let path = (outputDir as NSString).appendingPathComponent("\(baseName).html")
                try mapGenerator.writeHTML(tripId: trip.id, waypoints: trip.waypoints, to: path)
                print("HTML: \(path)")

            case .image:
                let path = (outputDir as NSString).appendingPathComponent("\(baseName).png")
                try await mapGenerator.downloadPNG(waypoints: trip.waypoints, to: path)
                print("PNG: \(path)")

            case .url:
                if let url = mapGenerator.generateStaticMapsURL(waypoints: trip.waypoints) {
                    print("Static Maps URL: \(url.absoluteString)")
                }
                if let webURL = mapGenerator.generateGoogleMapsWebURL(waypoints: trip.waypoints) {
                    print("Google Maps URL: \(webURL.absoluteString)")
                }
            }
        }
    }

    /// Parses ISO 8601 timestamp from DataDog
    /// - Parameter timestamp: ISO 8601 timestamp string
    /// - Returns: Parsed Date or current date if parsing fails
    private func parseTimestamp(_ timestamp: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: timestamp) {
            return date
        }

        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: timestamp) ?? Date()
    }
}
