import Foundation

/// Main orchestrator service for trip visualization
///
/// Coordinates the full pipeline:
/// 1. Fetches ALL logs from DataDog for a trip (multi-log support)
/// 2. Parses waypoints from each log into LogFragments
/// 3. Aggregates fragments into a UnifiedRoute
/// 4. Generates map outputs in requested formats (with gap rendering)
public final class TripVisualizerService {

    // MARK: - Properties

    private let configuration: Configuration
    private let dataDogClient: DataDogClient
    private let logParser: LogParser
    private let mapGenerator: MapGenerator
    private let fragmentAggregator: FragmentAggregator
    private let progress: ProgressIndicator

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
        self.mapGenerator = MapGenerator(
            apiKey: googleAPIKey,
            routeColor: configuration.routeColor,
            routeWeight: configuration.routeWeight
        )
        self.fragmentAggregator = FragmentAggregator()
        self.progress = ProgressIndicator()
    }

    /// Creates a TripVisualizerService with custom dependencies (for testing)
    internal init(
        configuration: Configuration,
        dataDogClient: DataDogClient,
        logParser: LogParser,
        mapGenerator: MapGenerator,
        fragmentAggregator: FragmentAggregator = FragmentAggregator(),
        progress: ProgressIndicator = ProgressIndicator()
    ) {
        self.configuration = configuration
        self.dataDogClient = dataDogClient
        self.logParser = logParser
        self.mapGenerator = mapGenerator
        self.fragmentAggregator = fragmentAggregator
        self.progress = progress
    }

    // MARK: - Public Methods

    /// Visualizes a trip by fetching ALL logs and generating outputs.
    ///
    /// This method supports multi-fragment trips where app crashes may have
    /// created multiple log entries. All log fragments are fetched, combined,
    /// and visualized with gap detection.
    ///
    /// - Parameter tripId: The trip UUID to visualize
    /// - Throws: `TripVisualizerError` on any failure
    public func visualize(tripId: UUID) async throws {
        let startTime = Date()

        // Step 1: Fetch ALL logs from DataDog
        progress.start(.fetching)
        logInfo("Fetching logs for trip \(tripId.uuidString)")

        let logEntries: [DataDogLogEntry]
        let truncated: Bool
        do {
            let allLogs = try await dataDogClient.fetchAllLogs(tripId: tripId, limit: configuration.maxFragments)

            if allLogs.isEmpty {
                throw TripVisualizerError.tripNotFound(tripId)
            }

            // Check for truncation (more logs exist than limit)
            truncated = allLogs.count >= configuration.maxFragments
            if truncated {
                progress.showTruncationWarning(limit: configuration.maxFragments)
            }

            logEntries = allLogs
            logInfo("Found \(logEntries.count) log fragment(s)")
            progress.complete("Fetched \(logEntries.count) log fragment(s)")
        } catch {
            progress.fail("Failed to fetch logs: \(error.localizedDescription)")
            throw error
        }

        // Step 2: Parse each log entry into a LogFragment
        progress.start(.parsing)
        var fragments: [LogFragment] = []
        var failedCount = 0
        let totalLogs = logEntries.count

        for (index, logEntry) in logEntries.enumerated() {
            // Update progress with current fragment number
            progress.updateFragmentProgress(current: index + 1, total: totalLogs)

            do {
                let fragment = try logParser.parseToFragment(
                    logEntry,
                    tripId: tripId,
                    logLinkGenerator: { [dataDogClient] logId in
                        dataDogClient.generateLogLink(logId: logId)
                    }
                )
                fragments.append(fragment)

                // Show verbose details if enabled
                if configuration.isVerbose {
                    progress.showFragmentDetails(
                        fragmentId: fragment.id,
                        waypointCount: fragment.waypoints.count,
                        timestamp: fragment.timestamp
                    )
                }
            } catch {
                failedCount += 1
                logWarning("Failed to parse fragment \(logEntry.id): \(error.localizedDescription)")
            }
        }

        // Check we have at least one valid fragment
        guard !fragments.isEmpty else {
            progress.fail("Failed to parse any route data")
            throw TripVisualizerError.noRouteData
        }

        // Log partial failure if some fragments failed
        if failedCount > 0 {
            progress.showPartialFailureWarning(failedCount: failedCount, successCount: fragments.count)
        }

        progress.complete("Parsed \(fragments.count) fragment(s)")

        // Step 3: Aggregate fragments into unified route
        progress.start(.aggregating)
        let unifiedRoute: UnifiedRoute
        do {
            unifiedRoute = try fragmentAggregator.aggregate(
                fragments: fragments,
                gapThreshold: configuration.gapThresholdSeconds
            )
            logInfo("Aggregated \(unifiedRoute.totalWaypointCount) waypoints from \(unifiedRoute.fragmentCount) fragment(s)")

            if unifiedRoute.hasGaps {
                logInfo("Detected \(unifiedRoute.gapCount) gap(s) in route")
                progress.complete("Aggregated \(fragments.count) fragments (\(unifiedRoute.gapCount) gap(s) detected)")
            } else {
                progress.complete("Aggregated \(fragments.count) fragments into continuous route")
            }
        } catch {
            progress.fail("Failed to aggregate fragments")
            throw error
        }

        // Step 4: Create metadata for reporting
        let metadata = TripMetadata.from(
            fragments: fragments,
            totalFound: logEntries.count,
            failedCount: failedCount,
            truncated: truncated
        )

        // Step 5: Generate outputs with segment support
        progress.start(.generating)
        let outputCount = try await generateOutputsWithSegments(
            tripId: tripId,
            route: unifiedRoute,
            metadata: metadata
        )

        // Show summary
        let duration = Date().timeIntervalSince(startTime)
        showMultiFragmentSummary(tripId: tripId, route: unifiedRoute, metadata: metadata, outputCount: outputCount, duration: duration)
    }

    /// Legacy visualize method for backward compatibility with single-log trips
    /// - Parameters:
    ///   - tripId: The trip UUID to visualize
    ///   - useLegacyFlow: If true, uses single-log fetch (for testing/backward compat)
    /// - Throws: `TripVisualizerError` on any failure
    public func visualizeLegacy(tripId: UUID) async throws {
        let startTime = Date()

        // Step 1: Fetch logs from DataDog
        progress.start(.fetching)
        logInfo("Fetching logs for trip \(tripId.uuidString)")

        let response: DataDogLogResponse
        do {
            response = try await dataDogClient.fetchLogs(tripId: tripId)
            progress.complete("Fetched logs from DataDog")
        } catch {
            progress.fail("Failed to fetch logs: \(error.localizedDescription)")
            throw error
        }

        // Step 2: Validate and select log entry
        progress.start(.parsing)
        let logEntry: DataDogLogEntry
        do {
            logEntry = try validateLogResponse(response, tripId: tripId)
            logInfo("Found log entry: \(logEntry.id)")
        } catch {
            progress.fail("No valid log data found")
            throw error
        }

        // Step 3: Parse waypoints
        let waypoints: [Waypoint]
        do {
            waypoints = try logParser.parseLogEntry(logEntry)
            logInfo("Extracted \(waypoints.count) waypoints")
            progress.complete("Parsed \(waypoints.count) waypoints")
        } catch {
            progress.fail("Failed to parse route data")
            throw error
        }

        // Step 4: Create trip model
        let trip = Trip(
            id: tripId,
            logId: logEntry.id,
            logLink: dataDogClient.generateLogLink(logId: logEntry.id),
            waypoints: waypoints,
            timestamp: parseTimestamp(logEntry.attributes.timestamp)
        )

        // Step 5: Generate outputs
        progress.start(.generating)
        let outputCount = try await generateOutputs(for: trip)

        // Show summary
        let duration = Date().timeIntervalSince(startTime)
        progress.showSummary(tripId: tripId.uuidString, outputCount: outputCount, duration: duration)
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

    /// Generates all requested output formats with graceful degradation
    /// - Parameter trip: Trip data to visualize
    /// - Returns: Number of successfully generated outputs
    /// - Note: If PNG generation fails, HTML will still be generated. Errors are collected and reported.
    @discardableResult
    private func generateOutputs(for trip: Trip) async throws -> Int {
        // Create output directory structure: output/<tripId>/
        let baseOutputDir = configuration.outputDirectory
        let tripOutputDir = (baseOutputDir as NSString).appendingPathComponent(trip.id.uuidString)
        let fileManager = FileManager.default

        do {
            if !fileManager.fileExists(atPath: tripOutputDir) {
                try fileManager.createDirectory(atPath: tripOutputDir, withIntermediateDirectories: true)
            }
        } catch {
            throw TripVisualizerError.cannotWriteOutput(
                path: tripOutputDir,
                reason: "Cannot create output directory: \(error.localizedDescription)"
            )
        }

        let baseName = trip.id.uuidString
        let outputDir = tripOutputDir

        var errors: [(format: OutputFormat, error: Error)] = []
        var successCount = 0

        for format in configuration.outputFormats {
            do {
                switch format {
                case .html:
                    progress.update("Generating HTML map...")
                    let path = (outputDir as NSString).appendingPathComponent("\(baseName).html")
                    try mapGenerator.writeHTML(tripId: trip.id, waypoints: trip.waypoints, to: path)
                    print("HTML: \(path)")
                    successCount += 1

                case .image:
                    progress.start(.downloading)
                    let path = (outputDir as NSString).appendingPathComponent("\(baseName).png")
                    try await mapGenerator.downloadPNG(
                        waypoints: trip.waypoints,
                        to: path,
                        retryCount: configuration.retryAttempts
                    )
                    progress.complete("Downloaded static map")
                    print("PNG: \(path)")
                    successCount += 1

                case .url:
                    progress.update("Generating URLs...")
                    if let url = mapGenerator.generateStaticMapsURL(waypoints: trip.waypoints) {
                        print("Static Maps URL: \(url.absoluteString)")
                    }
                    if let webURL = mapGenerator.generateGoogleMapsWebURL(waypoints: trip.waypoints) {
                        print("Google Maps URL: \(webURL.absoluteString)")
                    }
                    successCount += 1
                }
            } catch {
                errors.append((format, error))
                progress.warn("Failed to generate \(format) output")
                logWarning("Failed to generate \(format) output: \(error.localizedDescription)")
            }
        }

        // Report results
        if successCount == 0 && !errors.isEmpty {
            progress.fail("All outputs failed")
            // All outputs failed - throw the first error
            throw errors[0].error
        } else if !errors.isEmpty {
            // Some outputs failed - log warnings but don't fail
            for (format, error) in errors {
                logWarning("Warning: \(format) output failed: \(error.localizedDescription)")
            }
        } else {
            progress.complete("Generated \(successCount) output(s)")
        }

        return successCount
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

    // MARK: - Multi-Fragment Output Generation

    /// Generates all requested output formats with segment support
    /// - Parameters:
    ///   - tripId: Trip UUID
    ///   - route: Unified route with segments
    ///   - metadata: Trip processing metadata
    /// - Returns: Number of successfully generated outputs
    @discardableResult
    private func generateOutputsWithSegments(
        tripId: UUID,
        route: UnifiedRoute,
        metadata: TripMetadata
    ) async throws -> Int {
        // Create output directory structure: output/<tripId>/
        let baseOutputDir = configuration.outputDirectory
        let tripOutputDir = (baseOutputDir as NSString).appendingPathComponent(tripId.uuidString)
        let fileManager = FileManager.default

        do {
            if !fileManager.fileExists(atPath: tripOutputDir) {
                try fileManager.createDirectory(atPath: tripOutputDir, withIntermediateDirectories: true)
            }
        } catch {
            throw TripVisualizerError.cannotWriteOutput(
                path: tripOutputDir,
                reason: "Cannot create output directory: \(error.localizedDescription)"
            )
        }

        let baseName = tripId.uuidString
        let outputDir = tripOutputDir

        var errors: [(format: OutputFormat, error: Error)] = []
        var successCount = 0

        for format in configuration.outputFormats {
            do {
                switch format {
                case .html:
                    progress.update("Generating HTML map...")
                    let path = (outputDir as NSString).appendingPathComponent("\(baseName).html")
                    try mapGenerator.writeHTML(tripId: tripId, segments: route.segments, to: path)
                    print("HTML: \(path)")
                    successCount += 1

                case .image:
                    progress.start(.downloading)
                    let path = (outputDir as NSString).appendingPathComponent("\(baseName).png")
                    // Use segments for static maps (gray for gaps)
                    guard let url = mapGenerator.generateStaticMapsURL(segments: route.segments) else {
                        throw TripVisualizerError.noRouteData
                    }

                    let data = try await downloadStaticMap(from: url)
                    try data.write(to: URL(fileURLWithPath: path))
                    logInfo("PNG map written to \(path)")
                    progress.complete("Downloaded static map")
                    print("PNG: \(path)")
                    successCount += 1

                case .url:
                    progress.update("Generating URLs...")
                    if let url = mapGenerator.generateStaticMapsURL(segments: route.segments) {
                        print("Static Maps URL: \(url.absoluteString)")
                    }
                    if let webURL = mapGenerator.generateGoogleMapsWebURL(waypoints: route.waypoints) {
                        print("Google Maps URL: \(webURL.absoluteString)")
                    }
                    successCount += 1
                }
            } catch {
                errors.append((format, error))
                progress.warn("Failed to generate \(format) output")
                logWarning("Failed to generate \(format) output: \(error.localizedDescription)")
            }
        }

        // Report results
        if successCount == 0 && !errors.isEmpty {
            progress.fail("All outputs failed")
            throw errors[0].error
        } else if !errors.isEmpty {
            for (format, error) in errors {
                logWarning("Warning: \(format) output failed: \(error.localizedDescription)")
            }
        } else {
            progress.complete("Generated \(successCount) output(s)")
        }

        return successCount
    }

    /// Downloads static map image with retry support
    private func downloadStaticMap(from url: URL) async throws -> Data {
        try await RetryHandler.withRetry(retryCount: configuration.retryAttempts) {
            let (responseData, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TripVisualizerError.networkUnreachable("Invalid response from Google Maps API")
            }

            switch httpResponse.statusCode {
            case 200:
                return responseData
            case 403:
                throw TripVisualizerError.httpError(
                    statusCode: 403,
                    message: "Access denied. Ensure Static Maps API is enabled for your Google API key."
                )
            case 429:
                throw TripVisualizerError.rateLimitExceeded
            case 500...599:
                throw TripVisualizerError.httpError(
                    statusCode: httpResponse.statusCode,
                    message: "Google Maps server error"
                )
            default:
                throw TripVisualizerError.httpError(
                    statusCode: httpResponse.statusCode,
                    message: "Failed to download static map"
                )
            }
        }
    }

    /// Shows summary for multi-fragment trip processing
    private func showMultiFragmentSummary(
        tripId: UUID,
        route: UnifiedRoute,
        metadata: TripMetadata,
        outputCount: Int,
        duration: TimeInterval
    ) {
        // Use the enhanced multi-fragment summary
        progress.showMultiFragmentSummary(
            tripId: tripId.uuidString,
            fragmentCount: route.fragmentCount,
            totalWaypoints: route.totalWaypointCount,
            gapCount: route.gapCount,
            outputCount: outputCount,
            duration: duration
        )

        // Additional warnings
        if metadata.truncated {
            logWarning("Trip truncated to \(metadata.totalFragments) fragments")
        }

        if metadata.hasFailures {
            logWarning("\(metadata.failedFragments) fragment(s) failed to process")
        }
    }
}
