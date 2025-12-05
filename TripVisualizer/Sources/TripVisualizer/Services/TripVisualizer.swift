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

    /// Validates the DataDog log response and selects the most recent log with route data
    /// - Parameters:
    ///   - response: DataDog API response
    ///   - tripId: Trip ID for error messages
    /// - Returns: The most recent log entry containing segment_coords
    /// - Throws: `TripVisualizerError` if no logs found or none have route data
    private func validateLogResponse(_ response: DataDogLogResponse, tripId: UUID) throws -> DataDogLogEntry {
        guard !response.data.isEmpty else {
            throw TripVisualizerError.tripNotFound(tripId)
        }

        if response.data.count > 1 {
            logInfo("Found \(response.data.count) logs for trip")
        }

        // Sort by timestamp descending
        let sorted = response.data.sorted { entry1, entry2 in
            entry1.attributes.timestamp > entry2.attributes.timestamp
        }

        // Find the first (most recent) log that has segment_coords
        // Data can be at: attributes.segment_coords OR attributes.request.Msg.segment_coords
        for entry in sorted {
            if let segmentCoords = findSegmentCoords(in: entry.attributes.attributes),
               !segmentCoords.isEmpty {
                logInfo("Using log with \(segmentCoords.count) coordinates")
                return entry
            }
        }

        // No logs with route data found
        logWarning("None of the \(response.data.count) logs contain segment_coords")
        throw TripVisualizerError.noRouteData
    }

    /// Searches for segment_coords in various nested locations within log attributes
    private func findSegmentCoords(in attributes: [String: Any]) -> [[String: Any]]? {
        // Direct path: attributes.segment_coords
        if let coords = attributes["segment_coords"] as? [[String: Any]] {
            return coords
        }

        // Nested path: attributes.request.Msg.segment_coords
        if let request = attributes["request"] as? [String: Any],
           let msg = request["Msg"] as? [String: Any],
           let coords = msg["segment_coords"] as? [[String: Any]] {
            return coords
        }

        // Alternative: request might be an array
        if let request = attributes["request"] as? [[String: Any]],
           let first = request.first,
           let msg = first["Msg"] as? [String: Any],
           let coords = msg["segment_coords"] as? [[String: Any]] {
            return coords
        }

        return nil
    }

    /// Generates all requested output formats
    /// - Parameter trip: Trip data to visualize
    private func generateOutputs(for trip: Trip) async throws {
        // Create output directory structure: output/<tripId>/
        let baseOutputDir = configuration.outputDirectory
        let tripOutputDir = (baseOutputDir as NSString).appendingPathComponent(trip.id.uuidString)
        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: tripOutputDir) {
            try fileManager.createDirectory(atPath: tripOutputDir, withIntermediateDirectories: true)
        }

        let baseName = trip.id.uuidString
        let outputDir = tripOutputDir

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
