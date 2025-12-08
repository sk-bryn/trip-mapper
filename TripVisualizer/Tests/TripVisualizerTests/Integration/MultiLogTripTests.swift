import XCTest
@testable import TripVisualizer

/// Integration tests for multi-log trip visualization
///
/// Tests the complete pipeline for trips with multiple log fragments,
/// including gap detection, aggregation, and segmented output generation.
final class MultiLogTripTests: XCTestCase {

    // MARK: - Properties

    var tempDirectory: String!
    var tripId: UUID!

    // MARK: - Setup/Teardown

    override func setUp() {
        super.setUp()
        tempDirectory = (FileManager.default.temporaryDirectory.path as NSString)
            .appendingPathComponent("MultiLogTripTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: tempDirectory, withIntermediateDirectories: true)
        tripId = UUID()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempDirectory)
        super.tearDown()
    }

    // MARK: - End-to-End Multi-Fragment Pipeline Tests

    func testMultiFragmentPipelineWithGap() throws {
        // Given - Multiple log fragments with a time gap
        let now = Date()
        let fragments = createFragmentsWithGap(tripId: tripId, baseTime: now)
        let aggregator = FragmentAggregator()
        let generator = MapGenerator(apiKey: "test-api-key")

        // When - Aggregate fragments
        let route = try aggregator.aggregate(fragments: fragments, gapThreshold: 300)

        // Then - Route should detect the gap
        XCTAssertEqual(route.fragmentCount, 3)
        XCTAssertTrue(route.hasGaps)
        XCTAssertEqual(route.gapCount, 1)

        // Verify segments are created correctly
        // Each fragment gets its own continuous segment, plus 1 gap segment
        XCTAssertEqual(route.segments.count, 4) // 3 continuous + 1 gap

        // Generate HTML output
        let outputPath = (tempDirectory as NSString).appendingPathComponent("\(tripId.uuidString).html")
        try generator.writeHTML(tripId: tripId, segments: route.segments, to: outputPath)

        // Verify HTML contains gap styling
        let content = try String(contentsOfFile: outputPath, encoding: .utf8)
        XCTAssertTrue(content.contains("dashed")) // Gap rendered as dashed line
        XCTAssertTrue(content.contains("legend")) // Legend should appear for multi-segment
    }

    func testMultiFragmentPipelineWithoutGap() throws {
        // Given - Multiple fragments without significant time gap
        let now = Date()
        let fragments = createFragmentsWithoutGap(tripId: tripId, baseTime: now)
        let aggregator = FragmentAggregator()
        let generator = MapGenerator(apiKey: "test-api-key")

        // When
        let route = try aggregator.aggregate(fragments: fragments, gapThreshold: 300)

        // Then - Route should be continuous
        XCTAssertEqual(route.fragmentCount, 2)
        XCTAssertFalse(route.hasGaps)
        XCTAssertEqual(route.gapCount, 0)
        // Each fragment gets its own continuous segment (no gaps)
        XCTAssertEqual(route.segments.count, 2) // 2 continuous segments

        // Generate HTML output
        let outputPath = (tempDirectory as NSString).appendingPathComponent("\(tripId.uuidString).html")
        try generator.writeHTML(tripId: tripId, segments: route.segments, to: outputPath)

        // Verify HTML does not contain gap styling
        let content = try String(contentsOfFile: outputPath, encoding: .utf8)
        XCTAssertFalse(content.contains("class=\"legend\""))
    }

    func testLogParserToFragmentConversion() throws {
        // Given - Simulated DataDog log entry
        let parser = LogParser()
        let segmentCoords: [[String: Any]] = [
            ["lat": 37.7749, "lng": -122.4194],
            ["lat": 37.7755, "lng": -122.4185],
            ["lat": 37.7760, "lng": -122.4175]
        ]
        let attributes: [String: Any] = ["segment_coords": segmentCoords]
        let logEntry = DataDogLogEntry(
            id: "log-123",
            attributes: DataDogLogAttributes(
                timestamp: ISO8601DateFormatter().string(from: Date()),
                message: "received request for SaveActualRouteForTrip",
                attributes: attributes
            )
        )

        // When - Parse to fragment
        let fragment = try parser.parseToFragment(logEntry, tripId: tripId) { logId in
            "https://app.datadoghq.com/logs?query=@id:\(logId)"
        }

        // Then
        XCTAssertEqual(fragment.id, "log-123")
        XCTAssertEqual(fragment.tripId, tripId)
        XCTAssertEqual(fragment.waypoints.count, 3)
        XCTAssertTrue(fragment.logLink.contains("log-123"))
    }

    func testMultiFragmentStaticMapURL() throws {
        // Given - Route with gap
        let now = Date()
        let fragments = createFragmentsWithGap(tripId: tripId, baseTime: now)
        let aggregator = FragmentAggregator()
        let generator = MapGenerator(apiKey: "test-api-key")

        // When
        let route = try aggregator.aggregate(fragments: fragments, gapThreshold: 300)
        let url = generator.generateStaticMapsURL(segments: route.segments)

        // Then - URL should be valid
        XCTAssertNotNil(url)
        let urlString = url!.absoluteString
        XCTAssertTrue(urlString.contains("staticmap"))
        // Should have multiple path segments (continuous and gap with different colors)
        XCTAssertTrue(urlString.contains("path="))
    }

    // MARK: - Edge Cases

    func testSingleFragmentBackwardCompatibility() throws {
        // Given - Single fragment (pre-multi-log behavior)
        let fragment = LogFragment(
            id: "log-single",
            tripId: tripId,
            timestamp: Date(),
            waypoints: createWaypoints(count: 5, startLat: 37.77),
            logLink: "https://test.com"
        )
        let aggregator = FragmentAggregator()

        // When
        let route = try aggregator.aggregate(fragments: [fragment], gapThreshold: 300)

        // Then - Should behave like legacy single-log trip
        XCTAssertEqual(route.fragmentCount, 1)
        XCTAssertFalse(route.hasGaps)
        XCTAssertTrue(route.isComplete)
        XCTAssertEqual(route.segments.count, 1)
        XCTAssertEqual(route.segments[0].type, .continuous)
    }

    func testUnifiedRouteFactoryFromWaypoints() throws {
        // Given - Legacy waypoints array
        let waypoints = createWaypoints(count: 10, startLat: 37.77)

        // When - Use factory method
        let route = UnifiedRoute.fromWaypoints(waypoints, tripId: tripId)

        // Then - Should create proper unified route
        XCTAssertEqual(route.tripId, tripId)
        XCTAssertEqual(route.totalWaypointCount, 10)
        XCTAssertEqual(route.fragmentCount, 1)
        XCTAssertFalse(route.hasGaps)
    }

    func testDeduplicationAcrossFragments() throws {
        // Given - Fragments with overlapping waypoints
        let now = Date()
        let fragment1 = LogFragment(
            id: "log-1",
            tripId: tripId,
            timestamp: now,
            waypoints: [
                Waypoint(latitude: 37.7749, longitude: -122.4194),
                Waypoint(latitude: 37.7750, longitude: -122.4193),
                Waypoint(latitude: 37.7751, longitude: -122.4192) // Will overlap with fragment2
            ],
            logLink: "https://test.com/1"
        )
        let fragment2 = LogFragment(
            id: "log-2",
            tripId: tripId,
            timestamp: now.addingTimeInterval(60), // 1 minute later (no gap)
            waypoints: [
                Waypoint(latitude: 37.7751, longitude: -122.4192), // Same as last in fragment1
                Waypoint(latitude: 37.7752, longitude: -122.4191),
                Waypoint(latitude: 37.7753, longitude: -122.4190)
            ],
            logLink: "https://test.com/2"
        )

        let aggregator = FragmentAggregator()

        // When
        let route = try aggregator.aggregate(fragments: [fragment1, fragment2], gapThreshold: 300)

        // Then - Duplicate waypoint should be removed
        XCTAssertEqual(route.totalWaypointCount, 5) // 3 + 3 - 1 duplicate = 5
    }

    func testTripMetadataGeneration() {
        // Given - Fragments with mixed success
        let now = Date()
        let fragments = [
            LogFragment(
                id: "log-1",
                tripId: tripId,
                timestamp: now,
                waypoints: createWaypoints(count: 3, startLat: 37.77),
                logLink: "https://test.com/1"
            ),
            LogFragment(
                id: "log-2",
                tripId: tripId,
                timestamp: now.addingTimeInterval(600),
                waypoints: createWaypoints(count: 4, startLat: 37.78),
                logLink: "https://test.com/2"
            )
        ]

        // When
        let metadata = TripMetadata.from(
            logs: fragments,
            truncated: false
        )

        // Then
        XCTAssertEqual(metadata.totalLogs, 2)
        XCTAssertFalse(metadata.truncated)
    }

    func testTripMetadataTruncation() {
        // Given
        let metadata = TripMetadata.from(
            logs: [],
            truncated: true
        )

        // Then
        XCTAssertTrue(metadata.truncated)
    }

    // MARK: - Configuration Tests

    func testCustomGapThreshold() throws {
        // Given - Fragments with 3-minute gap
        let now = Date()
        let fragment1 = LogFragment(
            id: "log-1",
            tripId: tripId,
            timestamp: now,
            waypoints: createWaypoints(count: 3, startLat: 37.77),
            logLink: "https://test.com/1"
        )
        let fragment2 = LogFragment(
            id: "log-2",
            tripId: tripId,
            timestamp: now.addingTimeInterval(180), // 3 minutes later
            waypoints: createWaypoints(count: 3, startLat: 37.78),
            logLink: "https://test.com/2"
        )

        let aggregator = FragmentAggregator()

        // When - Use 2-minute threshold (should detect gap)
        let routeWithGap = try aggregator.aggregate(
            fragments: [fragment1, fragment2],
            gapThreshold: 120 // 2 minutes
        )

        // When - Use 5-minute threshold (should NOT detect gap)
        let routeWithoutGap = try aggregator.aggregate(
            fragments: [fragment1, fragment2],
            gapThreshold: 300 // 5 minutes
        )

        // Then
        XCTAssertTrue(routeWithGap.hasGaps)
        XCTAssertFalse(routeWithoutGap.hasGaps)
    }

    func testConfigurationGapThresholdDefault() {
        let config = Configuration.defaultConfig
        XCTAssertEqual(config.gapThresholdSeconds, 300) // 5 minutes
    }

    func testConfigurationMaxLogsDefault() {
        let config = Configuration.defaultConfig
        XCTAssertEqual(config.maxLogs, 50)
    }

    func testConfigurationPerLogOutputDefault() {
        let config = Configuration.defaultConfig
        XCTAssertFalse(config.perLogOutput)
    }

    func testConfigurationPerLogOutputDecoding() throws {
        // Config JSON with perLogOutput enabled
        let json = """
        {
            "outputDirectory": "output",
            "perLogOutput": true
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let config = try decoder.decode(Configuration.self, from: json)

        XCTAssertTrue(config.perLogOutput)
    }

    // MARK: - Performance

    func testManyFragmentsAggregation() throws {
        // Given - 20 fragments (stress test)
        let now = Date()
        var fragments: [LogFragment] = []
        for i in 0..<20 {
            fragments.append(LogFragment(
                id: "log-\(i)",
                tripId: tripId,
                timestamp: now.addingTimeInterval(Double(i) * 60), // 1 minute apart
                waypoints: createWaypoints(count: 5, startLat: 37.77 + Double(i) * 0.01),
                logLink: "https://test.com/\(i)"
            ))
        }

        let aggregator = FragmentAggregator()

        // When/Then - Should complete without error
        measure {
            _ = try? aggregator.aggregate(fragments: fragments, gapThreshold: 300)
        }
    }

    // MARK: - Helpers

    private func createFragmentsWithGap(tripId: UUID, baseTime: Date) -> [LogFragment] {
        return [
            LogFragment(
                id: "log-1",
                tripId: tripId,
                timestamp: baseTime,
                waypoints: createWaypoints(count: 5, startLat: 37.77),
                logLink: "https://test.com/1"
            ),
            LogFragment(
                id: "log-2",
                tripId: tripId,
                timestamp: baseTime.addingTimeInterval(60), // 1 minute later (no gap)
                waypoints: createWaypoints(count: 5, startLat: 37.78),
                logLink: "https://test.com/2"
            ),
            LogFragment(
                id: "log-3",
                tripId: tripId,
                timestamp: baseTime.addingTimeInterval(600), // 10 minutes later (GAP!)
                waypoints: createWaypoints(count: 5, startLat: 37.80),
                logLink: "https://test.com/3"
            )
        ]
    }

    private func createFragmentsWithoutGap(tripId: UUID, baseTime: Date) -> [LogFragment] {
        return [
            LogFragment(
                id: "log-1",
                tripId: tripId,
                timestamp: baseTime,
                waypoints: createWaypoints(count: 5, startLat: 37.77),
                logLink: "https://test.com/1"
            ),
            LogFragment(
                id: "log-2",
                tripId: tripId,
                timestamp: baseTime.addingTimeInterval(120), // 2 minutes later (no gap)
                waypoints: createWaypoints(count: 5, startLat: 37.78),
                logLink: "https://test.com/2"
            )
        ]
    }

    private func createWaypoints(count: Int, startLat: Double) -> [Waypoint] {
        return (0..<count).map { index in
            Waypoint(
                latitude: startLat + Double(index) * 0.001,
                longitude: -122.4194 + Double(index) * 0.001
            )
        }
    }
}
