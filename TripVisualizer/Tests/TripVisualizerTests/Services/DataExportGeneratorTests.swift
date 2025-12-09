import XCTest
@testable import TripVisualizer

final class DataExportGeneratorTests: XCTestCase {

    // MARK: - Properties

    private var generator: DataExportGenerator!
    private var tempDirectory: String!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        generator = DataExportGenerator()
        tempDirectory = NSTemporaryDirectory() + "DataExportGeneratorTests-\(UUID().uuidString)"
        try? FileManager.default.createDirectory(atPath: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: tempDirectory)
        generator = nil
        tempDirectory = nil
        super.tearDown()
    }

    // MARK: - Test Helpers

    private func makeWaypoint(
        lat: Double = 37.7749,
        lon: Double = -122.4194,
        orderId: UUID? = nil
    ) -> Waypoint {
        Waypoint(latitude: lat, longitude: lon, orderId: orderId, fragmentId: nil)
    }

    private func makeLogFragment(
        id: String = "log123",
        tripId: UUID,
        timestamp: Date = Date(),
        waypoints: [Waypoint]? = nil,
        logLink: String? = nil
    ) -> LogFragment {
        let defaultWaypoints = waypoints ?? [
            makeWaypoint(),
            makeWaypoint(lat: 37.7750)
        ]
        return LogFragment(
            id: id,
            tripId: tripId,
            timestamp: timestamp,
            waypoints: defaultWaypoints,
            logLink: logLink ?? "https://app.datadoghq.com/logs?event=\(id)"
        )
    }

    private func makeUnifiedRoute(
        tripId: UUID,
        waypoints: [Waypoint] = [],
        hasGaps: Bool = false,
        isComplete: Bool = true
    ) -> UnifiedRoute {
        let segments = hasGaps
            ? [
                RouteSegment(waypoints: waypoints, type: .continuous, sourceFragmentId: nil),
                RouteSegment(waypoints: [], type: .gap, sourceFragmentId: nil)
            ]
            : [RouteSegment(waypoints: waypoints, type: .continuous, sourceFragmentId: nil)]

        return UnifiedRoute(
            tripId: tripId,
            waypoints: waypoints,
            segments: segments,
            fragmentCount: 1,
            isComplete: isComplete
        )
    }

    private func makeMetadata(truncated: Bool = false) -> TripMetadata {
        TripMetadata(
            totalLogs: 1,
            truncated: truncated,
            firstTimestamp: Date(),
            lastTimestamp: Date()
        )
    }

    // MARK: - Initialization Tests

    func testDataExportGeneratorCreation() {
        let gen = DataExportGenerator()
        XCTAssertNotNil(gen)
    }

    // MARK: - generateExport Tests

    func testGenerateExportBasic() {
        let tripId = UUID()
        let log = makeLogFragment(tripId: tripId)
        let route = makeUnifiedRoute(tripId: tripId)
        let metadata = makeMetadata()

        let export = generator.generateExport(
            tripId: tripId,
            logs: [log],
            route: route,
            metadata: metadata
        )

        XCTAssertEqual(export.tripId, tripId)
        XCTAssertEqual(export.routeSegments.count, 1)
        XCTAssertEqual(export.summary.totalRouteSegments, 1)
    }

    func testGenerateExportWithMultipleLogs() {
        let tripId = UUID()
        let log1 = makeLogFragment(id: "log1", tripId: tripId)
        let log2 = makeLogFragment(id: "log2", tripId: tripId)
        let log3 = makeLogFragment(id: "log3", tripId: tripId)
        let logs = [log1, log2, log3]

        let route = makeUnifiedRoute(tripId: tripId)
        let metadata = makeMetadata()

        let export = generator.generateExport(
            tripId: tripId,
            logs: logs,
            route: route,
            metadata: metadata
        )

        XCTAssertEqual(export.routeSegments.count, 3)
        XCTAssertEqual(export.summary.totalRouteSegments, 3)
    }

    func testGenerateExportWithOrders() {
        let tripId = UUID()
        let order1 = UUID()
        let order2 = UUID()

        let waypoints = [
            makeWaypoint(orderId: order1),
            makeWaypoint(orderId: order1),
            makeWaypoint(orderId: order2)
        ]

        let log = makeLogFragment(tripId: tripId, waypoints: waypoints)
        let route = makeUnifiedRoute(tripId: tripId)
        let metadata = makeMetadata()

        let export = generator.generateExport(
            tripId: tripId,
            logs: [log],
            route: route,
            metadata: metadata
        )

        XCTAssertEqual(export.orderSequence.count, 2)
        XCTAssertEqual(export.summary.totalOrders, 2)
        XCTAssertEqual(export.summary.totalWaypoints, 3)
    }

    func testGenerateExportWithGaps() {
        let tripId = UUID()
        let log = makeLogFragment(tripId: tripId)
        let route = makeUnifiedRoute(tripId: tripId, hasGaps: true)
        let metadata = makeMetadata()

        let export = generator.generateExport(
            tripId: tripId,
            logs: [log],
            route: route,
            metadata: metadata
        )

        XCTAssertTrue(export.summary.hasGaps)
    }

    func testGenerateExportWithTruncation() {
        let tripId = UUID()
        let log = makeLogFragment(tripId: tripId)
        let route = makeUnifiedRoute(tripId: tripId)
        let metadata = makeMetadata(truncated: true)

        let export = generator.generateExport(
            tripId: tripId,
            logs: [log],
            route: route,
            metadata: metadata
        )

        XCTAssertTrue(export.summary.truncated)
    }

    // MARK: - writeExport Tests

    func testWriteExportCreatesFile() throws {
        let tripId = UUID()
        let summary = ExportSummary(
            totalRouteSegments: 1,
            totalWaypoints: 2,
            totalOrders: 0,
            hasGaps: false,
            truncated: false,
            incompleteData: false
        )
        let segment = RouteSegmentExport(
            segmentIndex: 0,
            datadogLogId: "log123",
            datadogUrl: "https://app.datadoghq.com/logs",
            timestamp: Date(),
            waypointCount: 2,
            orders: []
        )
        let export = TripDataExport(
            tripId: tripId,
            generatedAt: Date(),
            summary: summary,
            orderSequence: [],
            routeSegments: [segment]
        )

        let path = (tempDirectory as NSString).appendingPathComponent("test-export.json")

        try generator.writeExport(export, to: path)

        XCTAssertTrue(FileManager.default.fileExists(atPath: path))
    }

    func testWriteExportContentIsValidJSON() throws {
        let tripId = UUID()
        let summary = ExportSummary(
            totalRouteSegments: 1,
            totalWaypoints: 2,
            totalOrders: 0,
            hasGaps: false,
            truncated: false,
            incompleteData: false
        )
        let segment = RouteSegmentExport(
            segmentIndex: 0,
            datadogLogId: "log123",
            datadogUrl: "https://app.datadoghq.com/logs",
            timestamp: Date(),
            waypointCount: 2,
            orders: []
        )
        let export = TripDataExport(
            tripId: tripId,
            generatedAt: Date(),
            summary: summary,
            orderSequence: [],
            routeSegments: [segment]
        )

        let path = (tempDirectory as NSString).appendingPathComponent("test-export.json")

        try generator.writeExport(export, to: path)

        // Read and parse to verify valid JSON
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let decoded = try JSONDecoder().decode([String: Any].self, from: data)

        XCTAssertNotNil(decoded)
    }

    func testWriteExportIsPrettyPrinted() throws {
        let tripId = UUID()
        let summary = ExportSummary(
            totalRouteSegments: 1,
            totalWaypoints: 2,
            totalOrders: 0,
            hasGaps: false,
            truncated: false,
            incompleteData: false
        )
        let segment = RouteSegmentExport(
            segmentIndex: 0,
            datadogLogId: "log123",
            datadogUrl: "https://app.datadoghq.com/logs",
            timestamp: Date(),
            waypointCount: 2,
            orders: []
        )
        let export = TripDataExport(
            tripId: tripId,
            generatedAt: Date(),
            summary: summary,
            orderSequence: [],
            routeSegments: [segment]
        )

        let path = (tempDirectory as NSString).appendingPathComponent("test-export.json")

        try generator.writeExport(export, to: path)

        let content = try String(contentsOfFile: path)

        // Pretty printed JSON should have newlines
        XCTAssertTrue(content.contains("\n"))
        // And should have indentation
        XCTAssertTrue(content.contains("  "))
    }

    func testWriteExportUsesISO8601Dates() throws {
        let tripId = UUID()
        let timestamp = Date(timeIntervalSince1970: 1700000000)
        let summary = ExportSummary(
            totalRouteSegments: 1,
            totalWaypoints: 2,
            totalOrders: 0,
            hasGaps: false,
            truncated: false,
            incompleteData: false
        )
        let segment = RouteSegmentExport(
            segmentIndex: 0,
            datadogLogId: "log123",
            datadogUrl: "https://app.datadoghq.com/logs",
            timestamp: timestamp,
            waypointCount: 2,
            orders: []
        )
        let export = TripDataExport(
            tripId: tripId,
            generatedAt: timestamp,
            summary: summary,
            orderSequence: [],
            routeSegments: [segment]
        )

        let path = (tempDirectory as NSString).appendingPathComponent("test-export.json")

        try generator.writeExport(export, to: path)

        let content = try String(contentsOfFile: path)

        // ISO8601 format
        XCTAssertTrue(content.contains("2023-11-14T"))
    }

    func testWriteExportHasSortedKeys() throws {
        let tripId = UUID()
        let summary = ExportSummary(
            totalRouteSegments: 1,
            totalWaypoints: 2,
            totalOrders: 0,
            hasGaps: false,
            truncated: false,
            incompleteData: false
        )
        let segment = RouteSegmentExport(
            segmentIndex: 0,
            datadogLogId: "log123",
            datadogUrl: "https://app.datadoghq.com/logs",
            timestamp: Date(),
            waypointCount: 2,
            orders: []
        )
        let export = TripDataExport(
            tripId: tripId,
            generatedAt: Date(),
            summary: summary,
            orderSequence: [],
            routeSegments: [segment]
        )

        let path = (tempDirectory as NSString).appendingPathComponent("test-export.json")

        try generator.writeExport(export, to: path)

        let content = try String(contentsOfFile: path)

        // Find position of key appearances (generatedAt should come before orderSequence alphabetically)
        let generatedAtPos = content.range(of: "generatedAt")?.lowerBound
        let orderSequencePos = content.range(of: "orderSequence")?.lowerBound

        XCTAssertNotNil(generatedAtPos)
        XCTAssertNotNil(orderSequencePos)
        XCTAssertLessThan(generatedAtPos!, orderSequencePos!)
    }

    func testWriteExportThrowsOnInvalidPath() {
        let tripId = UUID()
        let summary = ExportSummary(
            totalRouteSegments: 1,
            totalWaypoints: 2,
            totalOrders: 0,
            hasGaps: false,
            truncated: false,
            incompleteData: false
        )
        let segment = RouteSegmentExport(
            segmentIndex: 0,
            datadogLogId: "log123",
            datadogUrl: "https://app.datadoghq.com/logs",
            timestamp: Date(),
            waypointCount: 2,
            orders: []
        )
        let export = TripDataExport(
            tripId: tripId,
            generatedAt: Date(),
            summary: summary,
            orderSequence: [],
            routeSegments: [segment]
        )

        let invalidPath = "/nonexistent/directory/export.json"

        XCTAssertThrowsError(try generator.writeExport(export, to: invalidPath)) { error in
            guard let vizError = error as? TripVisualizerError else {
                XCTFail("Expected TripVisualizerError")
                return
            }
            if case .cannotWriteOutput(let path, _) = vizError {
                XCTAssertEqual(path, invalidPath)
            } else {
                XCTFail("Expected cannotWriteOutput error")
            }
        }
    }

    // MARK: - generateAndWrite Tests

    func testGenerateAndWriteCreatesFile() throws {
        let tripId = UUID()
        let log = makeLogFragment(tripId: tripId)
        let route = makeUnifiedRoute(tripId: tripId)
        let metadata = makeMetadata()

        let path = try generator.generateAndWrite(
            tripId: tripId,
            logs: [log],
            route: route,
            metadata: metadata,
            to: tempDirectory
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: path))
    }

    func testGenerateAndWriteUsesCorrectFilename() throws {
        let tripId = UUID()
        let log = makeLogFragment(tripId: tripId)
        let route = makeUnifiedRoute(tripId: tripId)
        let metadata = makeMetadata()

        let path = try generator.generateAndWrite(
            tripId: tripId,
            logs: [log],
            route: route,
            metadata: metadata,
            to: tempDirectory
        )

        let expectedFilename = "map-data.json"
        XCTAssertTrue(path.hasSuffix(expectedFilename))
    }

    func testGenerateAndWriteReturnsFullPath() throws {
        let tripId = UUID()
        let log = makeLogFragment(tripId: tripId)
        let route = makeUnifiedRoute(tripId: tripId)
        let metadata = makeMetadata()

        let path = try generator.generateAndWrite(
            tripId: tripId,
            logs: [log],
            route: route,
            metadata: metadata,
            to: tempDirectory
        )

        XCTAssertTrue(path.hasPrefix(tempDirectory))
        XCTAssertTrue(path.hasSuffix("map-data.json"))
    }

    func testGenerateAndWriteContentIsReadable() throws {
        let tripId = UUID()
        let order1 = UUID()

        let waypoints = [
            makeWaypoint(orderId: order1),
            makeWaypoint(orderId: order1)
        ]

        let log = makeLogFragment(tripId: tripId, waypoints: waypoints)
        let route = makeUnifiedRoute(tripId: tripId)
        let metadata = makeMetadata()

        let path = try generator.generateAndWrite(
            tripId: tripId,
            logs: [log],
            route: route,
            metadata: metadata,
            to: tempDirectory
        )

        // Read back and decode
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(TripDataExport.self, from: data)

        XCTAssertEqual(export.tripId, tripId)
        XCTAssertEqual(export.routeSegments.count, 1)
        XCTAssertEqual(export.orderSequence.count, 1)
        XCTAssertEqual(export.orderSequence[0], order1.uuidString)
    }

    func testGenerateAndWriteOverwritesExistingFile() throws {
        let tripId = UUID()
        let log1 = makeLogFragment(id: "log1", tripId: tripId)
        let log2 = makeLogFragment(id: "log2", tripId: tripId)
        let route = makeUnifiedRoute(tripId: tripId)
        let metadata = makeMetadata()

        // First write with 1 log
        let path1 = try generator.generateAndWrite(
            tripId: tripId,
            logs: [log1],
            route: route,
            metadata: metadata,
            to: tempDirectory
        )

        // Second write with 2 logs
        let path2 = try generator.generateAndWrite(
            tripId: tripId,
            logs: [log1, log2],
            route: route,
            metadata: metadata,
            to: tempDirectory
        )

        XCTAssertEqual(path1, path2)

        // Read and verify it has 2 segments
        let data = try Data(contentsOf: URL(fileURLWithPath: path2))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(TripDataExport.self, from: data)

        XCTAssertEqual(export.routeSegments.count, 2)
    }

    // MARK: - Enrichment Integration Tests (T034)

    func testGenerateExportWithEnrichmentResult() {
        let tripId = UUID()
        let orderId = UUID()
        let log = makeLogFragment(tripId: tripId, waypoints: [makeWaypoint(orderId: orderId)])
        let route = makeUnifiedRoute(tripId: tripId)
        let metadata = makeMetadata()

        let destination = DeliveryDestination(
            orderId: orderId,
            address: "123 Main St, Atlanta, GA 30301",
            addressDisplayLine1: "123 Main St",
            addressDisplayLine2: "Atlanta, GA 30301",
            latitude: 33.7490,
            longitude: -84.3880,
            dropoffInstructions: nil
        )

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

        let enrichmentResult = EnrichmentResult(
            restaurantLocation: restaurant,
            deliveryDestinations: [destination],
            status: EnrichmentStatus.allDataFound,
            warnings: []
        )

        let export = generator.generateExport(
            tripId: tripId,
            logs: [log],
            route: route,
            metadata: metadata,
            enrichmentResult: enrichmentResult
        )

        XCTAssertNotNil(export.enrichmentResult)
        XCTAssertEqual(export.enrichmentResult?.restaurantLocation?.locationNumber, "00070")
        XCTAssertEqual(export.enrichmentResult?.deliveryDestinations.count, 1)
        XCTAssertTrue(export.enrichmentResult?.status.orderDataFound ?? false)
        XCTAssertTrue(export.enrichmentResult?.status.locationDataFound ?? false)
    }

    func testGenerateExportWithNilEnrichment() {
        let tripId = UUID()
        let log = makeLogFragment(tripId: tripId)
        let route = makeUnifiedRoute(tripId: tripId)
        let metadata = makeMetadata()

        let export = generator.generateExport(
            tripId: tripId,
            logs: [log],
            route: route,
            metadata: metadata,
            enrichmentResult: nil
        )

        XCTAssertNil(export.enrichmentResult)
    }

    func testGenerateAndWriteWithEnrichmentResult() throws {
        let tripId = UUID()
        let orderId = UUID()
        let log = makeLogFragment(tripId: tripId, waypoints: [makeWaypoint(orderId: orderId)])
        let route = makeUnifiedRoute(tripId: tripId)
        let metadata = makeMetadata()

        let enrichmentResult = EnrichmentResult(
            restaurantLocation: nil,
            deliveryDestinations: [],
            status: EnrichmentStatus(orderDataFound: false, locationDataFound: false),
            warnings: ["Test warning for export"]
        )

        let path = try generator.generateAndWrite(
            tripId: tripId,
            logs: [log],
            route: route,
            metadata: metadata,
            enrichmentResult: enrichmentResult,
            to: tempDirectory
        )

        // Verify file exists and contains enrichment data
        let content = try String(contentsOfFile: path)

        XCTAssertTrue(content.contains("enrichmentResult"))
        XCTAssertTrue(content.contains("status"))
        XCTAssertTrue(content.contains("orderDataFound"))
        XCTAssertTrue(content.contains("locationDataFound"))
        XCTAssertTrue(content.contains("Test warning for export"))
    }

    func testWriteExportWithEnrichmentCreatesValidJSON() throws {
        let tripId = UUID()
        let summary = ExportSummary(
            totalRouteSegments: 1,
            totalWaypoints: 2,
            totalOrders: 0,
            hasGaps: false,
            truncated: false,
            incompleteData: false
        )
        let segment = RouteSegmentExport(
            segmentIndex: 0,
            datadogLogId: "log123",
            datadogUrl: "https://app.datadoghq.com/logs",
            timestamp: Date(),
            waypointCount: 2,
            orders: []
        )

        let orderId = UUID()
        let destination = DeliveryDestination(
            orderId: orderId,
            address: "456 Oak Ave, Boston, MA 02101",
            addressDisplayLine1: "456 Oak Ave",
            addressDisplayLine2: "Boston, MA 02101",
            latitude: 42.3601,
            longitude: -71.0589,
            dropoffInstructions: "Leave at door"
        )

        let enrichmentResult = EnrichmentResult(
            restaurantLocation: nil,
            deliveryDestinations: [destination],
            status: EnrichmentStatus(orderDataFound: true, locationDataFound: false),
            warnings: []
        )

        let export = TripDataExport(
            tripId: tripId,
            generatedAt: Date(),
            summary: summary,
            orderSequence: [],
            routeSegments: [segment],
            enrichmentResult: enrichmentResult
        )

        let path = (tempDirectory as NSString).appendingPathComponent("test-enrichment-export.json")

        try generator.writeExport(export, to: path)

        // Verify we can read it back with enrichment
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TripDataExport.self, from: data)

        XCTAssertNotNil(decoded.enrichmentResult)
        XCTAssertEqual(decoded.enrichmentResult?.deliveryDestinations.count, 1)
        XCTAssertEqual(decoded.enrichmentResult?.deliveryDestinations.first?.address, "456 Oak Ave, Boston, MA 02101")
        XCTAssertTrue(decoded.enrichmentResult?.status.orderDataFound ?? false)
        XCTAssertFalse(decoded.enrichmentResult?.status.locationDataFound ?? true)
    }

    func testEnrichmentStatusAlwaysPresentEvenWhenEmpty() throws {
        let tripId = UUID()
        let log = makeLogFragment(tripId: tripId)
        let route = makeUnifiedRoute(tripId: tripId)
        let metadata = makeMetadata()

        let emptyEnrichment = EnrichmentResult.empty

        let path = try generator.generateAndWrite(
            tripId: tripId,
            logs: [log],
            route: route,
            metadata: metadata,
            enrichmentResult: emptyEnrichment,
            to: tempDirectory
        )

        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TripDataExport.self, from: data)

        // Status should be present even with empty enrichment
        XCTAssertNotNil(decoded.enrichmentResult)
        XCTAssertFalse(decoded.enrichmentResult?.status.orderDataFound ?? true)
        XCTAssertFalse(decoded.enrichmentResult?.status.locationDataFound ?? true)
    }

    // MARK: - Large Trip Tests

    func testGenerateExportWithManySegments() {
        let tripId = UUID()
        let logs = (0..<50).map { index in
            makeLogFragment(id: "log\(index)", tripId: tripId)
        }
        let route = makeUnifiedRoute(tripId: tripId)
        let metadata = TripMetadata(
            totalLogs: 50,
            truncated: true,
            firstTimestamp: Date(),
            lastTimestamp: Date()
        )

        let export = generator.generateExport(
            tripId: tripId,
            logs: logs,
            route: route,
            metadata: metadata
        )

        XCTAssertEqual(export.routeSegments.count, 50)
        XCTAssertEqual(export.summary.totalRouteSegments, 50)
        XCTAssertTrue(export.summary.truncated)
    }
}

// MARK: - JSONDecoder Extension for Testing

extension JSONDecoder {
    fileprivate func decode(_ type: [String: Any].Type, from data: Data) throws -> [String: Any] {
        guard let result = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw DecodingError.typeMismatch(
                [String: Any].self,
                DecodingError.Context(codingPath: [], debugDescription: "Expected dictionary")
            )
        }
        return result
    }
}
