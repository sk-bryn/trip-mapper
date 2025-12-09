import Foundation

/// Main orchestrator service for trip visualization
///
/// Coordinates the full pipeline:
/// 1. Fetches ALL logs from DataDog for a trip (multi-log support)
/// 2. Parses waypoints from each log into route segments
/// 3. Aggregates route segments into a UnifiedRoute
/// 4. Generates map outputs in requested formats (with gap rendering)
public final class TripVisualizerService {

    // MARK: - Properties

    private let configuration: Configuration
    private let dataDogClient: DataDogClient
    private let logParser: LogParser
    private let mapGenerator: MapGenerator
    private let fragmentAggregator: FragmentAggregator
    private let dataExportGenerator: DataExportGenerator
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
        self.dataExportGenerator = DataExportGenerator()
        self.progress = ProgressIndicator()
    }

    /// Creates a TripVisualizerService with custom dependencies (for testing)
    internal init(
        configuration: Configuration,
        dataDogClient: DataDogClient,
        logParser: LogParser,
        mapGenerator: MapGenerator,
        fragmentAggregator: FragmentAggregator = FragmentAggregator(),
        dataExportGenerator: DataExportGenerator = DataExportGenerator(),
        progress: ProgressIndicator = ProgressIndicator()
    ) {
        self.configuration = configuration
        self.dataDogClient = dataDogClient
        self.logParser = logParser
        self.mapGenerator = mapGenerator
        self.fragmentAggregator = fragmentAggregator
        self.dataExportGenerator = dataExportGenerator
        self.progress = progress
    }

    // MARK: - Public Methods

    /// Visualizes a trip by fetching ALL logs and generating outputs.
    ///
    /// This method supports multi-log trips where app crashes may have
    /// created multiple log entries. All route segments are fetched, combined,
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
        do {
            let allLogs = try await dataDogClient.fetchAllLogs(tripId: tripId, limit: configuration.maxLogs)

            if allLogs.isEmpty {
                throw TripVisualizerError.tripNotFound(tripId)
            }

            logEntries = allLogs
            progress.complete("Fetched logs from DataDog")
        } catch {
            progress.fail("Failed to fetch logs: \(error.localizedDescription)")
            throw error
        }

        // Step 2: Parse each log entry into a route segment
        // Only logs with valid coordinate data are counted
        progress.start(.parsing)
        var logs: [LogFragment] = []

        for logEntry in logEntries {
            if let log = logParser.parseToLogFragment(
                logEntry,
                tripId: tripId,
                logLinkGenerator: { [dataDogClient] logId in
                    dataDogClient.generateLogLink(logId: logId)
                }
            ) {
                logs.append(log)

                // Update progress with current count
                progress.updateLogProgress(current: logs.count)

                // Show verbose details if enabled
                if configuration.isVerbose {
                    progress.showLogDetails(
                        logId: log.id,
                        waypointCount: log.waypoints.count,
                        timestamp: log.timestamp
                    )
                }
            }
            // Logs without coordinate data are silently ignored
        }

        // Check we have at least one valid log with coordinates
        guard !logs.isEmpty else {
            progress.fail("No logs with route data found")
            throw TripVisualizerError.noRouteData
        }

        // Check for truncation (hit the limit)
        let truncated = logs.count >= configuration.maxLogs
        if truncated {
            progress.showTruncationWarning(limit: configuration.maxLogs)
        }

        logInfo("Found \(logs.count) log(s) with route data")
        progress.complete("Parsed \(logs.count) log(s)")

        // Step 3: Prepare output directory (clean any previous run)
        try prepareOutputDirectory(for: tripId)

        // Step 4: Generate per-log outputs if enabled
        var perLogOutputCount = 0
        if configuration.perLogOutput && logs.count > 0 {
            progress.start(.generating, showSpinner: false)
            progress.update("Generating route segment outputs...")
            perLogOutputCount = try await generateRouteSegmentOutputs(tripId: tripId, logs: logs)
            progress.complete("Generated \(perLogOutputCount) route segment output(s)")
        }

        // Step 5: Aggregate logs into unified route
        progress.start(.aggregating)
        let unifiedRoute: UnifiedRoute
        do {
            unifiedRoute = try fragmentAggregator.aggregate(
                fragments: logs,
                gapThreshold: configuration.gapThresholdSeconds
            )
            logInfo("Aggregated \(unifiedRoute.totalWaypointCount) waypoints from \(unifiedRoute.fragmentCount) route segment(s)")

            if unifiedRoute.hasGaps {
                logInfo("Detected \(unifiedRoute.gapCount) gap(s) in route")
                progress.complete("Aggregated \(logs.count) log(s) (\(unifiedRoute.gapCount) gap(s) detected)")
            } else {
                progress.complete("Aggregated \(logs.count) log(s) into continuous route")
            }
        } catch {
            progress.fail("Failed to aggregate logs")
            throw error
        }

        // Step 6: Create metadata for reporting
        let metadata = TripMetadata.from(
            logs: logs,
            truncated: truncated
        )

        // Step 7: Generate outputs with segment support
        progress.start(.generating)
        let outputCount = try await generateOutputsWithSegments(
            tripId: tripId,
            logs: logs,
            route: unifiedRoute,
            metadata: metadata
        )

        // Show summary
        let duration = Date().timeIntervalSince(startTime)
        showMultiLogSummary(tripId: tripId, route: unifiedRoute, metadata: metadata, outputCount: outputCount, duration: duration)
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

    // MARK: - Output Directory Management

    /// Prepares the output directory for a trip, removing any existing output
    /// - Parameter tripId: Trip UUID
    /// - Throws: `TripVisualizerError` if directory cannot be created
    private func prepareOutputDirectory(for tripId: UUID) throws {
        let baseOutputDir = configuration.outputDirectory
        let tripOutputDir = (baseOutputDir as NSString).appendingPathComponent(tripId.uuidString)
        let fileManager = FileManager.default

        do {
            // Remove existing output directory if it exists (clean re-run)
            if fileManager.fileExists(atPath: tripOutputDir) {
                try fileManager.removeItem(atPath: tripOutputDir)
                logDebug("Removed existing output directory: \(tripOutputDir)")
            }
            try fileManager.createDirectory(atPath: tripOutputDir, withIntermediateDirectories: true)
            logDebug("Created output directory: \(tripOutputDir)")
        } catch {
            throw TripVisualizerError.cannotWriteOutput(
                path: tripOutputDir,
                reason: "Cannot prepare output directory: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Multi-Segment Output Generation

    /// Generates all requested output formats with segment support
    /// - Parameters:
    ///   - tripId: Trip UUID
    ///   - logs: Array of LogFragment for data export generation
    ///   - route: Unified route with segments
    ///   - metadata: Trip processing metadata
    /// - Returns: Number of successfully generated outputs
    @discardableResult
    private func generateOutputsWithSegments(
        tripId: UUID,
        logs: [LogFragment],
        route: UnifiedRoute,
        metadata: TripMetadata
    ) async throws -> Int {
        // Output directory is already prepared by prepareOutputDirectory()
        let baseOutputDir = configuration.outputDirectory
        let tripOutputDir = (baseOutputDir as NSString).appendingPathComponent(tripId.uuidString)

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

        // Generate data export (always, per FR-001)
        // Export failure is non-fatal - log warning but continue
        do {
            progress.update("Writing data export...")
            let exportPath = try dataExportGenerator.generateAndWrite(
                tripId: tripId,
                logs: logs,
                route: route,
                metadata: metadata,
                to: outputDir
            )
            logInfo("Data export written to \(exportPath)")
            print("Data Export: \(exportPath)")
            successCount += 1
        } catch {
            logWarning("Failed to generate data export: \(error.localizedDescription)")
            // Continue - map outputs already generated successfully
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

    // MARK: - Route Segment Output Generation

    /// Generates outputs for each individual log (route segment), named by timestamp
    /// - Parameters:
    ///   - tripId: Trip UUID
    ///   - logs: Array of route segments to generate outputs for
    /// - Returns: Total number of outputs generated across all logs
    @discardableResult
    private func generateRouteSegmentOutputs(tripId: UUID, logs: [LogFragment]) async throws -> Int {
        // Create output directory: output/<tripId>/route-segments/
        let baseOutputDir = configuration.outputDirectory
        let tripOutputDir = (baseOutputDir as NSString).appendingPathComponent(tripId.uuidString)
        let routeSegmentsDir = (tripOutputDir as NSString).appendingPathComponent("route-segments")
        let fileManager = FileManager.default

        do {
            if !fileManager.fileExists(atPath: routeSegmentsDir) {
                try fileManager.createDirectory(atPath: routeSegmentsDir, withIntermediateDirectories: true)
            }
        } catch {
            throw TripVisualizerError.cannotWriteOutput(
                path: routeSegmentsDir,
                reason: "Cannot create route-segments output directory: \(error.localizedDescription)"
            )
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd-HHmmss"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")

        var totalOutputs = 0

        for (index, log) in logs.enumerated() {
            let timestamp = dateFormatter.string(from: log.timestamp)
            let baseName = "\(timestamp)_log\(index + 1)"

            progress.update("Generating outputs for log \(index + 1) of \(logs.count)...")

            for format in configuration.outputFormats {
                do {
                    switch format {
                    case .html:
                        let path = (routeSegmentsDir as NSString).appendingPathComponent("\(baseName).html")
                        try mapGenerator.writeHTML(tripId: tripId, waypoints: log.waypoints, to: path)
                        logDebug("Per-log HTML written: \(path)")
                        totalOutputs += 1

                    case .image:
                        let path = (routeSegmentsDir as NSString).appendingPathComponent("\(baseName).png")
                        guard let url = mapGenerator.generateStaticMapsURL(waypoints: log.waypoints) else {
                            continue
                        }
                        let data = try await downloadStaticMap(from: url)
                        try data.write(to: URL(fileURLWithPath: path))
                        logDebug("Per-log PNG written: \(path)")
                        totalOutputs += 1

                    case .url:
                        // URLs are transient, write to a text file instead
                        var urlContent = "Log \(index + 1) - \(timestamp)\n"
                        urlContent += "Log ID: \(log.id)\n"
                        urlContent += "Waypoints: \(log.waypoints.count)\n\n"

                        if let staticURL = mapGenerator.generateStaticMapsURL(waypoints: log.waypoints) {
                            urlContent += "Static Maps URL:\n\(staticURL.absoluteString)\n\n"
                        }
                        if let webURL = mapGenerator.generateGoogleMapsWebURL(waypoints: log.waypoints) {
                            urlContent += "Google Maps URL:\n\(webURL.absoluteString)\n"
                        }

                        let path = (routeSegmentsDir as NSString).appendingPathComponent("\(baseName)_urls.txt")
                        try urlContent.write(toFile: path, atomically: true, encoding: .utf8)
                        logDebug("Per-log URLs written: \(path)")
                        totalOutputs += 1
                    }
                } catch {
                    logWarning("Failed to generate \(format) for log \(index + 1): \(error.localizedDescription)")
                }
            }
        }

        logInfo("Generated \(totalOutputs) route segment outputs in \(routeSegmentsDir)")
        return totalOutputs
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

    /// Shows summary for multi-log trip processing
    private func showMultiLogSummary(
        tripId: UUID,
        route: UnifiedRoute,
        metadata: TripMetadata,
        outputCount: Int,
        duration: TimeInterval
    ) {
        // Use the enhanced multi-log summary
        progress.showMultiLogSummary(
            tripId: tripId.uuidString,
            logCount: route.fragmentCount,
            totalWaypoints: route.totalWaypointCount,
            gapCount: route.gapCount,
            outputCount: outputCount,
            duration: duration
        )

        // Additional warnings
        if metadata.truncated {
            logWarning("Trip truncated to \(metadata.totalLogs) logs")
        }
    }
}
