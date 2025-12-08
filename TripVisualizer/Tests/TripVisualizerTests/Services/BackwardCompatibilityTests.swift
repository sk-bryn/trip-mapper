import XCTest
@testable import TripVisualizer

/// Tests for backward compatibility with single-log trips
///
/// These tests ensure that single-log trips continue to work identically
/// to pre-multi-log-support behavior.
final class BackwardCompatibilityTests: XCTestCase {

    // MARK: - Test Helpers

    private func makeWaypoint(lat: Double = 37.7749, lon: Double = -122.4194) -> Waypoint {
        Waypoint(latitude: lat, longitude: lon, orderId: nil, fragmentId: nil)
    }

    private func makeWaypoints(count: Int, startLat: Double = 37.7749) -> [Waypoint] {
        (0..<count).map { index in
            makeWaypoint(lat: startLat + Double(index) * 0.001, lon: -122.4194)
        }
    }

    // MARK: - Single Fragment Aggregation Tests

    func testSingleFragmentProducesNoGaps() throws {
        let aggregator = FragmentAggregator()
        let tripId = UUID()

        let fragment = LogFragment(
            id: "log123",
            tripId: tripId,
            timestamp: Date(),
            waypoints: makeWaypoints(count: 10),
            logLink: "https://test.com"
        )

        let route = try aggregator.aggregate(fragments: [fragment], gapThreshold: 300)

        XCTAssertFalse(route.hasGaps)
        XCTAssertEqual(route.gapCount, 0)
        XCTAssertEqual(route.segments.count, 1)
        XCTAssertEqual(route.segments[0].type, .continuous)
    }

    func testSingleFragmentPreservesAllWaypoints() throws {
        let aggregator = FragmentAggregator()
        let tripId = UUID()
        let waypoints = makeWaypoints(count: 15)

        let fragment = LogFragment(
            id: "log123",
            tripId: tripId,
            timestamp: Date(),
            waypoints: waypoints,
            logLink: "https://test.com"
        )

        let route = try aggregator.aggregate(fragments: [fragment], gapThreshold: 300)

        XCTAssertEqual(route.totalWaypointCount, 15)
    }

    func testSingleFragmentIsMarkedComplete() throws {
        let aggregator = FragmentAggregator()
        let tripId = UUID()

        let fragment = LogFragment(
            id: "log123",
            tripId: tripId,
            timestamp: Date(),
            waypoints: makeWaypoints(count: 5),
            logLink: "https://test.com"
        )

        let route = try aggregator.aggregate(fragments: [fragment], gapThreshold: 300)

        XCTAssertTrue(route.isComplete)
    }

    // MARK: - Waypoint Backward Compatibility Tests

    func testWaypointWithoutFragmentId() {
        // Ensure waypoints work without fragmentId (backward compat)
        let waypoint = Waypoint(latitude: 37.7749, longitude: -122.4194, orderId: nil)

        XCTAssertNil(waypoint.fragmentId)
        XCTAssertTrue(waypoint.isValid)
    }

    func testWaypointDefaultFragmentIdIsNil() {
        // Default fragmentId should be nil for backward compatibility
        let waypoint = Waypoint(latitude: 37.7749, longitude: -122.4194)

        XCTAssertNil(waypoint.fragmentId)
    }

    func testWaypointDecodingWithoutFragmentId() throws {
        // Waypoints encoded without fragmentId should decode correctly
        let json = """
        {
            "latitude": 37.7749,
            "longitude": -122.4194
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let waypoint = try decoder.decode(Waypoint.self, from: json)

        XCTAssertNil(waypoint.fragmentId)
        XCTAssertNil(waypoint.orderId)
    }

    // MARK: - MapGenerator Backward Compatibility Tests

    func testMapGeneratorWriteHTMLWithWaypointsArray() throws {
        let mapGenerator = MapGenerator(apiKey: "TEST_KEY")
        let tripId = UUID()
        let waypoints = makeWaypoints(count: 5)

        // Create temp directory for output
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("BackwardCompatTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let outputPath = tempDir.appendingPathComponent("test.html").path

        // Using legacy waypoints array API should still work
        XCTAssertNoThrow(try mapGenerator.writeHTML(tripId: tripId, waypoints: waypoints, to: outputPath))

        // Verify file was created
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputPath))

        // Verify HTML content
        let content = try String(contentsOfFile: outputPath, encoding: .utf8)
        XCTAssertTrue(content.contains("Trip Route:"))
        XCTAssertTrue(content.contains("google.maps"))
    }

    func testMapGeneratorGenerateStaticMapsURLWithWaypointsArray() {
        let mapGenerator = MapGenerator(apiKey: "TEST_KEY")
        let waypoints = makeWaypoints(count: 5)

        // Using legacy waypoints array API should return valid URL
        let url = mapGenerator.generateStaticMapsURL(waypoints: waypoints)

        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.contains("maps.googleapis.com"))
    }

    // MARK: - Configuration Backward Compatibility Tests

    func testConfigurationDefaultsPresent() {
        let config = Configuration.defaultConfig

        // Ensure new config options have sensible defaults
        XCTAssertEqual(config.maxFragments, 50)
        XCTAssertEqual(config.gapThresholdSeconds, 300)
    }

    func testConfigurationDecodingWithoutNewOptions() throws {
        // Config JSON without new options should use defaults
        let json = """
        {
            "outputDirectory": "output",
            "mapWidth": 800,
            "mapHeight": 600
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let config = try decoder.decode(Configuration.self, from: json)

        // New options should use defaults
        XCTAssertEqual(config.maxFragments, 50)
        XCTAssertEqual(config.gapThresholdSeconds, 300)
    }

    // MARK: - UnifiedRoute Backward Compatibility Tests

    func testUnifiedRouteFromWaypoints() {
        let tripId = UUID()
        let waypoints = makeWaypoints(count: 10)

        // Using factory method for backward compatibility
        let route = UnifiedRoute.fromWaypoints(waypoints, tripId: tripId)

        XCTAssertEqual(route.tripId, tripId)
        XCTAssertEqual(route.totalWaypointCount, 10)
        XCTAssertEqual(route.fragmentCount, 1)
        XCTAssertFalse(route.hasGaps)
        XCTAssertTrue(route.isComplete)
    }

    // MARK: - Trip Model Tests

    func testTripModelStillWorks() {
        let tripId = UUID()
        let waypoints = makeWaypoints(count: 5)

        // Existing Trip model should still work
        let trip = Trip(
            id: tripId,
            logId: "log123",
            logLink: "https://test.com",
            waypoints: waypoints,
            timestamp: Date()
        )

        XCTAssertEqual(trip.waypointCount, 5)
        XCTAssertTrue(trip.hasMinimumWaypoints)
        XCTAssertNotNil(trip.startWaypoint)
        XCTAssertNotNil(trip.endWaypoint)
    }

    // MARK: - HTML Output Tests

    func testGeneratedHTMLHasNoLegendForSingleFragment() throws {
        let mapGenerator = MapGenerator(apiKey: "TEST_KEY")
        let tripId = UUID()
        let waypoints = makeWaypoints(count: 5)

        let html = try mapGenerator.generateHTML(tripId: tripId, waypoints: waypoints)

        // Single-fragment routes should NOT have a legend
        XCTAssertFalse(html.contains("class=\"legend\""))
    }

    func testGeneratedHTMLHasLegendForMultipleSegmentsWithGap() throws {
        let mapGenerator = MapGenerator(apiKey: "TEST_KEY")
        let tripId = UUID()

        let segments = [
            RouteSegment(waypoints: makeWaypoints(count: 3), type: .continuous),
            RouteSegment(waypoints: makeWaypoints(count: 2, startLat: 37.78), type: .gap),
            RouteSegment(waypoints: makeWaypoints(count: 3, startLat: 37.79), type: .continuous)
        ]

        let html = try mapGenerator.generateHTML(tripId: tripId, segments: segments)

        // Multi-segment routes with gaps should have a legend
        XCTAssertTrue(html.contains("class=\"legend\""))
        XCTAssertTrue(html.contains("Gap (missing data)"))
    }
}
