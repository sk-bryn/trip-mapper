import XCTest
@testable import TripVisualizer

/// Integration tests for end-to-end visualization workflow
/// Tests the complete pipeline from log parsing to output generation
final class VisualizationIntegrationTests: XCTestCase {

    // MARK: - Properties

    var tempDirectory: String!

    // MARK: - Setup/Teardown

    override func setUp() {
        super.setUp()
        tempDirectory = (FileManager.default.temporaryDirectory.path as NSString)
            .appendingPathComponent("TripVisualizerIntegrationTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempDirectory)
        super.tearDown()
    }

    // MARK: - Pipeline Integration Tests

    func testFullPipelineFromWaypointsToHTML() throws {
        // Given - Simulated waypoints extracted from logs
        let waypoints = createSampleRoute()
        let tripId = UUID()
        let generator = MapGenerator(apiKey: "test-api-key")
        let outputPath = (tempDirectory as NSString).appendingPathComponent("\(tripId.uuidString).html")

        // When - Generate HTML output
        try generator.writeHTML(tripId: tripId, waypoints: waypoints, to: outputPath)

        // Then - Verify output
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputPath))
        let content = try String(contentsOfFile: outputPath, encoding: .utf8)
        XCTAssertTrue(content.contains(tripId.uuidString))
        XCTAssertTrue(content.contains("google.maps"))

        // Verify all waypoints are represented
        for waypoint in waypoints {
            XCTAssertTrue(content.contains(String(format: "%.4f", waypoint.latitude)) ||
                         content.contains(String(waypoint.latitude)))
        }
    }

    func testFullPipelineFromWaypointsToStaticURL() throws {
        // Given
        let waypoints = createSampleRoute()
        let generator = MapGenerator(apiKey: "test-api-key")

        // When
        let url = generator.generateStaticMapsURL(waypoints: waypoints)

        // Then
        XCTAssertNotNil(url)

        // Verify URL is valid and contains encoded path
        let urlString = url!.absoluteString
        XCTAssertTrue(urlString.hasPrefix("https://"))
        XCTAssertTrue(urlString.contains("staticmap"))
        XCTAssertTrue(urlString.contains("path="))
    }

    func testLogParserToMapGeneratorIntegration() throws {
        // Given - Simulated DataDog log data
        let parser = LogParser()
        let segmentCoords: [[String: Any]] = [
            ["lat": 37.7749, "lng": -122.4194],
            ["lat": 37.7755, "lng": -122.4185],
            ["lat": 37.7760, "lng": -122.4175],
            ["lat": 37.7765, "lng": -122.4165]
        ]

        // When - Parse waypoints
        let waypoints = try parser.extractWaypoints(from: segmentCoords)

        // Then - Generate map
        let generator = MapGenerator(apiKey: "test-api-key")
        let tripId = UUID()
        let html = try generator.generateHTML(tripId: tripId, waypoints: waypoints)

        XCTAssertFalse(html.isEmpty)
        XCTAssertTrue(html.contains("Polyline"))
    }

    func testPolylineEncodingInStaticMapsURL() throws {
        // Given
        let waypoints = [
            Waypoint(latitude: 38.5, longitude: -120.2),
            Waypoint(latitude: 40.7, longitude: -120.95),
            Waypoint(latitude: 43.252, longitude: -126.453)
        ]
        let generator = MapGenerator(apiKey: "test-api-key")

        // When
        let url = generator.generateStaticMapsURL(waypoints: waypoints)

        // Then - URL should contain encoded polyline
        XCTAssertNotNil(url)
        let urlString = url!.absoluteString
        // The encoded path should be URL-encoded version of the polyline
        XCTAssertTrue(urlString.contains("enc:"))
    }

    // MARK: - Output Format Integration Tests

    func testMultipleOutputFormats() throws {
        // Given
        let waypoints = createSampleRoute()
        let tripId = UUID()
        let generator = MapGenerator(apiKey: "test-api-key")

        // When - Generate all formats
        let htmlPath = (tempDirectory as NSString).appendingPathComponent("\(tripId.uuidString).html")
        try generator.writeHTML(tripId: tripId, waypoints: waypoints, to: htmlPath)

        let staticURL = generator.generateStaticMapsURL(waypoints: waypoints)
        let webURL = generator.generateGoogleMapsWebURL(waypoints: waypoints)

        // Then - All outputs should be valid
        XCTAssertTrue(FileManager.default.fileExists(atPath: htmlPath))
        XCTAssertNotNil(staticURL)
        XCTAssertNotNil(webURL)
    }

    // MARK: - Configuration Integration Tests

    func testConfigurationAffectsDataDogQuery() {
        // Given
        var config = Configuration.default
        config.datadogEnv = "test"
        config.datadogService = "custom-service"
        let tripId = UUID()

        // When
        let query = config.buildDatadogQuery(tripId: tripId)

        // Then
        XCTAssertTrue(query.contains("env:test"))
        XCTAssertTrue(query.contains("service:custom-service"))
        XCTAssertTrue(query.contains(tripId.uuidString.lowercased()))
    }

    func testConfigurationLoaderIntegration() throws {
        // Given - Create a config file
        let configPath = (tempDirectory as NSString).appendingPathComponent("config.json")
        let configJSON = """
        {
            "datadogEnv": "staging",
            "datadogService": "test-service",
            "outputFormats": ["html", "url"],
            "outputDirectory": "./output"
        }
        """
        try configJSON.write(toFile: configPath, atomically: true, encoding: .utf8)

        // When
        let config = try ConfigurationLoader.load(from: configPath)

        // Then
        XCTAssertEqual(config.datadogEnv, "staging")
        XCTAssertEqual(config.datadogService, "test-service")
        XCTAssertEqual(config.outputFormats, [.html, .url])
    }

    // MARK: - Error Propagation Tests

    func testInsufficientWaypointsErrorPropagation() {
        // Given
        let parser = LogParser()
        let segmentCoords: [[String: Any]] = [
            ["lat": 37.7749, "lng": -122.4194]
        ]

        // When/Then
        XCTAssertThrowsError(try parser.extractWaypoints(from: segmentCoords)) { error in
            guard let vizError = error as? TripVisualizerError else {
                XCTFail("Expected TripVisualizerError")
                return
            }
            XCTAssertEqual(vizError.exitCode, 3) // Data error
        }
    }

    func testNoRouteDataErrorPropagation() {
        // Given
        let parser = LogParser()
        let segmentCoords: [[String: Any]] = []

        // When/Then
        XCTAssertThrowsError(try parser.extractWaypoints(from: segmentCoords)) { error in
            guard let vizError = error as? TripVisualizerError else {
                XCTFail("Expected TripVisualizerError")
                return
            }
            XCTAssertEqual(vizError.exitCode, 3) // Data error
        }
    }

    // MARK: - Performance Tests

    func testLargeRoutePerformance() throws {
        // Given - Large route with 500 waypoints (per SC-001)
        var waypoints: [Waypoint] = []
        for i in 0..<500 {
            waypoints.append(Waypoint(
                latitude: 37.0 + Double(i) * 0.001,
                longitude: -122.0 + Double(i) * 0.001
            ))
        }
        let generator = MapGenerator(apiKey: "test-api-key")
        let tripId = UUID()

        // When/Then - Should complete within reasonable time
        measure {
            _ = try? generator.generateHTML(tripId: tripId, waypoints: waypoints)
        }
    }

    // MARK: - Helpers

    private func createSampleRoute() -> [Waypoint] {
        return [
            Waypoint(latitude: 37.7749, longitude: -122.4194), // San Francisco
            Waypoint(latitude: 37.7755, longitude: -122.4185),
            Waypoint(latitude: 37.7760, longitude: -122.4175),
            Waypoint(latitude: 37.7765, longitude: -122.4165),
            Waypoint(latitude: 37.7770, longitude: -122.4155),
            Waypoint(latitude: 37.7775, longitude: -122.4145),
            Waypoint(latitude: 37.7780, longitude: -122.4135),
            Waypoint(latitude: 37.7785, longitude: -122.4125),
            Waypoint(latitude: 37.7790, longitude: -122.4115),
            Waypoint(latitude: 37.7795, longitude: -122.4105)
        ]
    }
}
