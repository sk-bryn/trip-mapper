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
        var config = Configuration.defaultConfig
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

    // MARK: - Enrichment Integration Tests (T045)

    func testFullPipelineWithEnrichmentData() throws {
        // Given - Route with enrichment data
        let tripId = UUID()
        let orderId1 = UUID()
        let orderId2 = UUID()

        let waypoints = [
            Waypoint(latitude: 33.98325, longitude: -81.096, orderId: nil),  // Start (restaurant)
            Waypoint(latitude: 33.9000, longitude: -81.100, orderId: orderId1),
            Waypoint(latitude: 33.8500, longitude: -81.150, orderId: orderId1),
            Waypoint(latitude: 33.7490, longitude: -84.3880, orderId: orderId2)  // End (delivery)
        ]

        let segments = [RouteSegment(waypoints: waypoints, type: .continuous, sourceFragmentId: nil)]
        let generator = MapGenerator(apiKey: "test-api-key")
        let configuration = Configuration.defaultConfig
        let outputPath = (tempDirectory as NSString).appendingPathComponent("\(tripId.uuidString).html")

        // Create enrichment data
        let restaurant = RestaurantLocation(
            locationNumber: "00070",
            name: "West Columbia",
            address1: "2299 Augusta Rd",
            address2: nil,
            city: "West Columbia",
            state: "SC",
            zip: "29169",
            latitude: 33.98325,
            longitude: -81.096,
            operatorName: nil,
            timeZone: nil
        )

        let delivery = DeliveryDestination(
            orderId: orderId2,
            address: "123 Main St, Atlanta, GA 30301",
            addressDisplayLine1: "123 Main St",
            addressDisplayLine2: "Atlanta, GA 30301",
            latitude: 33.7490,
            longitude: -84.3880,
            dropoffInstructions: "Leave at door"
        )

        let enrichmentResult = EnrichmentResult(
            restaurantLocation: restaurant,
            deliveryDestinations: [delivery],
            status: EnrichmentStatus.allDataFound,
            warnings: []
        )

        // When - Generate HTML output with enrichment
        try generator.writeHTML(
            tripId: tripId,
            segments: segments,
            enrichmentResult: enrichmentResult,
            configuration: configuration,
            to: outputPath
        )

        // Then - Verify output contains enrichment markers
        let content = try String(contentsOfFile: outputPath, encoding: .utf8)
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputPath))
        XCTAssertTrue(content.contains("West Columbia"))  // Restaurant name
        XCTAssertTrue(content.contains("123 Main St"))    // Delivery address
    }

    func testEnrichmentDataExport() throws {
        // Given - Trip data with enrichment
        let tripId = UUID()
        let orderId = UUID()

        let waypoints = [
            Waypoint(latitude: 33.98325, longitude: -81.096, orderId: orderId),
            Waypoint(latitude: 33.7490, longitude: -84.3880, orderId: orderId)
        ]

        let log = LogFragment(
            id: "log123",
            tripId: tripId,
            timestamp: Date(),
            waypoints: waypoints,
            logLink: "https://app.datadoghq.com/logs?event=log123"
        )

        let route = UnifiedRoute(
            tripId: tripId,
            waypoints: waypoints,
            segments: [RouteSegment(waypoints: waypoints, type: .continuous, sourceFragmentId: nil)],
            fragmentCount: 1,
            isComplete: true
        )

        let metadata = TripMetadata(
            totalLogs: 1,
            truncated: false,
            firstTimestamp: Date(),
            lastTimestamp: Date()
        )

        let delivery = DeliveryDestination(
            orderId: orderId,
            address: "456 Oak Ave, Boston, MA 02101",
            addressDisplayLine1: "456 Oak Ave",
            addressDisplayLine2: "Boston, MA 02101",
            latitude: 42.3601,
            longitude: -71.0589,
            dropoffInstructions: nil
        )

        let enrichmentResult = EnrichmentResult(
            restaurantLocation: nil,
            deliveryDestinations: [delivery],
            status: EnrichmentStatus(orderDataFound: true, locationDataFound: false),
            warnings: ["Restaurant location unavailable"]
        )

        let generator = DataExportGenerator()
        let outputPath = (tempDirectory as NSString).appendingPathComponent("map-data.json")

        // When - Generate export with enrichment
        try generator.generateAndWrite(
            tripId: tripId,
            logs: [log],
            route: route,
            metadata: metadata,
            enrichmentResult: enrichmentResult,
            to: tempDirectory
        )

        // Then - Verify export contains enrichment data
        let data = try Data(contentsOf: URL(fileURLWithPath: outputPath))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(TripDataExport.self, from: data)

        XCTAssertNotNil(export.enrichmentResult)
        XCTAssertEqual(export.enrichmentResult?.deliveryDestinations.count, 1)
        XCTAssertEqual(export.enrichmentResult?.deliveryDestinations.first?.orderId, orderId)
        XCTAssertTrue(export.enrichmentResult?.status.orderDataFound ?? false)
        XCTAssertFalse(export.enrichmentResult?.status.locationDataFound ?? true)
        XCTAssertEqual(export.enrichmentResult?.warnings.count, 1)
    }

    func testStaticMapsURLWithEnrichment() {
        // Given - Route segments with enrichment
        let waypoints = createSampleRoute()
        let segments = [RouteSegment(waypoints: waypoints, type: .continuous, sourceFragmentId: nil)]
        let generator = MapGenerator(apiKey: "test-api-key")
        let configuration = Configuration.defaultConfig

        let restaurant = RestaurantLocation(
            locationNumber: "00070",
            name: "Test Restaurant",
            address1: "123 Test St",
            address2: nil,
            city: "Test City",
            state: "TS",
            zip: "12345",
            latitude: 37.7749,
            longitude: -122.4194,
            operatorName: nil,
            timeZone: nil
        )

        let enrichmentResult = EnrichmentResult(
            restaurantLocation: restaurant,
            deliveryDestinations: [],
            status: EnrichmentStatus(orderDataFound: false, locationDataFound: true),
            warnings: []
        )

        // When
        let url = generator.generateStaticMapsURL(
            segments: segments,
            enrichmentResult: enrichmentResult,
            configuration: configuration
        )

        // Then
        XCTAssertNotNil(url)
        let urlString = url?.absoluteString ?? ""
        XCTAssertTrue(urlString.contains("markers="))  // Should have markers
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
