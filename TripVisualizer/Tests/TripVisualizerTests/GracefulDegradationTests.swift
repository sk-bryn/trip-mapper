import XCTest
@testable import TripVisualizer

/// Tests for graceful degradation when enrichment fails (T047)
///
/// Verifies that visualization completes successfully even when enrichment
/// data is unavailable, with appropriate warnings logged.
final class GracefulDegradationTests: XCTestCase {

    // MARK: - Properties

    private var tempDirectory: String!

    // MARK: - Setup/Teardown

    override func setUp() {
        super.setUp()
        tempDirectory = (FileManager.default.temporaryDirectory.path as NSString)
            .appendingPathComponent("GracefulDegradationTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(atPath: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempDirectory)
        super.tearDown()
    }

    // MARK: - Graceful Degradation Tests

    func testVisualizationCompletesWithEmptyEnrichment() throws {
        // Given - Route with empty enrichment
        let tripId = UUID()
        let waypoints = createSampleRoute()
        let segments = [RouteSegment(waypoints: waypoints, type: .continuous, sourceFragmentId: nil)]
        let generator = MapGenerator(apiKey: "test-api-key")
        let configuration = Configuration.defaultConfig
        let outputPath = (tempDirectory as NSString).appendingPathComponent("\(tripId.uuidString).html")

        // Empty enrichment (simulates failed lookups)
        let enrichmentResult = EnrichmentResult.empty

        // When - Generate HTML (should complete without errors)
        XCTAssertNoThrow(try generator.writeHTML(
            tripId: tripId,
            segments: segments,
            enrichmentResult: enrichmentResult,
            configuration: configuration,
            to: outputPath
        ))

        // Then - Output file exists and is valid
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputPath))
        let content = try String(contentsOfFile: outputPath, encoding: .utf8)
        XCTAssertTrue(content.contains("google.maps"))
        XCTAssertTrue(content.contains(tripId.uuidString))
    }

    func testVisualizationCompletesWithPartialEnrichment() throws {
        // Given - Route with partial enrichment (only restaurant, no deliveries)
        let tripId = UUID()
        let waypoints = createSampleRoute()
        let segments = [RouteSegment(waypoints: waypoints, type: .continuous, sourceFragmentId: nil)]
        let generator = MapGenerator(apiKey: "test-api-key")
        let configuration = Configuration.defaultConfig
        let outputPath = (tempDirectory as NSString).appendingPathComponent("\(tripId.uuidString).html")

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
            warnings: ["Order data unavailable for order ABC123"]
        )

        // When - Generate HTML (should complete without errors)
        XCTAssertNoThrow(try generator.writeHTML(
            tripId: tripId,
            segments: segments,
            enrichmentResult: enrichmentResult,
            configuration: configuration,
            to: outputPath
        ))

        // Then - Output file exists with restaurant marker
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputPath))
        let content = try String(contentsOfFile: outputPath, encoding: .utf8)
        XCTAssertTrue(content.contains("Test Restaurant"))
    }

    func testVisualizationCompletesWithEnrichmentWarnings() throws {
        // Given - Route with enrichment that has warnings
        let tripId = UUID()
        let waypoints = createSampleRoute()
        let segments = [RouteSegment(waypoints: waypoints, type: .continuous, sourceFragmentId: nil)]
        let generator = MapGenerator(apiKey: "test-api-key")
        let configuration = Configuration.defaultConfig
        let outputPath = (tempDirectory as NSString).appendingPathComponent("\(tripId.uuidString).html")

        let enrichmentResult = EnrichmentResult.failed(with: [
            "Delivery address unavailable for order ABC123",
            "Restaurant location unavailable for location 00070"
        ])

        // When - Generate HTML (should complete without errors despite warnings)
        XCTAssertNoThrow(try generator.writeHTML(
            tripId: tripId,
            segments: segments,
            enrichmentResult: enrichmentResult,
            configuration: configuration,
            to: outputPath
        ))

        // Then - Output file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputPath))
    }

    func testStaticMapsURLGeneratesWithEmptyEnrichment() {
        // Given
        let waypoints = createSampleRoute()
        let segments = [RouteSegment(waypoints: waypoints, type: .continuous, sourceFragmentId: nil)]
        let generator = MapGenerator(apiKey: "test-api-key")
        let configuration = Configuration.defaultConfig
        let enrichmentResult = EnrichmentResult.empty

        // When
        let url = generator.generateStaticMapsURL(
            segments: segments,
            enrichmentResult: enrichmentResult,
            configuration: configuration
        )

        // Then - URL is generated (route polyline still works)
        XCTAssertNotNil(url)
    }

    func testDataExportCompletesWithEmptyEnrichment() throws {
        // Given - Trip data with empty enrichment
        let tripId = UUID()
        let waypoints = createSampleRoute()

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

        let enrichmentResult = EnrichmentResult.empty
        let generator = DataExportGenerator()

        // When - Generate export (should complete without errors)
        XCTAssertNoThrow(try generator.generateAndWrite(
            tripId: tripId,
            logs: [log],
            route: route,
            metadata: metadata,
            enrichmentResult: enrichmentResult,
            to: tempDirectory
        ))

        // Then - Export file exists
        let exportPath = (tempDirectory as NSString).appendingPathComponent("map-data.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportPath))

        // Verify enrichment status is present but shows no data found
        let data = try Data(contentsOf: URL(fileURLWithPath: exportPath))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(TripDataExport.self, from: data)

        XCTAssertNotNil(export.enrichmentResult)
        XCTAssertFalse(export.enrichmentResult?.status.orderDataFound ?? true)
        XCTAssertFalse(export.enrichmentResult?.status.locationDataFound ?? true)
    }

    func testEnrichmentResultFailedFactoryProducesWarnings() {
        // Given - Warnings that would be logged during failure
        let warnings = [
            "Failed to fetch delivery order logs: HTTP error 401",
            "Failed to fetch restaurant location: Network unavailable"
        ]

        // When - Create a failed enrichment result
        let result = EnrichmentResult.failed(with: warnings)

        // Then - Result should have warnings and no data
        XCTAssertTrue(result.hasWarnings)
        XCTAssertEqual(result.warnings.count, 2)
        XCTAssertTrue(result.deliveryDestinations.isEmpty)
        XCTAssertNil(result.restaurantLocation)
        XCTAssertFalse(result.status.orderDataFound)
        XCTAssertFalse(result.status.locationDataFound)
    }

    func testEmptyEnrichmentResultDoesNotHaveWarnings() {
        // Given/When
        let result = EnrichmentResult.empty

        // Then
        XCTAssertFalse(result.hasWarnings)
        XCTAssertTrue(result.warnings.isEmpty)
    }

    // MARK: - Helpers

    private func createSampleRoute() -> [Waypoint] {
        return [
            Waypoint(latitude: 37.7749, longitude: -122.4194),
            Waypoint(latitude: 37.7755, longitude: -122.4185),
            Waypoint(latitude: 37.7760, longitude: -122.4175),
            Waypoint(latitude: 37.7765, longitude: -122.4165),
            Waypoint(latitude: 37.7770, longitude: -122.4155)
        ]
    }
}
