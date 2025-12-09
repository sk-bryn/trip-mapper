import XCTest
@testable import TripVisualizer

final class DataExportIntegrationTests: XCTestCase {

    // MARK: - Properties

    private var tempDirectory: String!
    private var generator: DataExportGenerator!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        generator = DataExportGenerator()
        tempDirectory = NSTemporaryDirectory() + "DataExportIntegrationTests-\(UUID().uuidString)"
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
        orderId: UUID? = nil,
        fragmentId: String? = nil
    ) -> Waypoint {
        Waypoint(latitude: lat, longitude: lon, orderId: orderId, fragmentId: fragmentId)
    }

    private func makeLogFragment(
        id: String,
        tripId: UUID,
        timestamp: Date,
        waypoints: [Waypoint],
        logLink: String? = nil
    ) -> LogFragment {
        LogFragment(
            id: id,
            tripId: tripId,
            timestamp: timestamp,
            waypoints: waypoints,
            logLink: logLink ?? "https://app.datadoghq.com/logs?event=\(id)"
        )
    }

    // MARK: - End-to-End Tests

    func testFullExportWorkflow() throws {
        // Given - A realistic multi-log trip scenario
        let tripId = UUID()
        let order1 = UUID()
        let order2 = UUID()
        let order3 = UUID()

        // Log 1: Outbound delivery with orders 1 and 2
        let log1 = makeLogFragment(
            id: "log-outbound-1",
            tripId: tripId,
            timestamp: Date(timeIntervalSince1970: 1700000000),
            waypoints: [
                makeWaypoint(lat: 37.7749, lon: -122.4194, orderId: order1, fragmentId: "log-outbound-1"),
                makeWaypoint(lat: 37.7750, lon: -122.4195, orderId: order1, fragmentId: "log-outbound-1"),
                makeWaypoint(lat: 37.7760, lon: -122.4200, orderId: order2, fragmentId: "log-outbound-1"),
                makeWaypoint(lat: 37.7770, lon: -122.4210, orderId: order2, fragmentId: "log-outbound-1")
            ]
        )

        // Log 2: Return to restaurant (no orderIds)
        let log2 = makeLogFragment(
            id: "log-return-1",
            tripId: tripId,
            timestamp: Date(timeIntervalSince1970: 1700001000),
            waypoints: [
                makeWaypoint(lat: 37.7770, lon: -122.4210, orderId: nil, fragmentId: "log-return-1"),
                makeWaypoint(lat: 37.7755, lon: -122.4198, orderId: nil, fragmentId: "log-return-1"),
                makeWaypoint(lat: 37.7749, lon: -122.4194, orderId: nil, fragmentId: "log-return-1")
            ]
        )

        // Log 3: Second outbound with order 3
        let log3 = makeLogFragment(
            id: "log-outbound-2",
            tripId: tripId,
            timestamp: Date(timeIntervalSince1970: 1700002000),
            waypoints: [
                makeWaypoint(lat: 37.7749, lon: -122.4194, orderId: order3, fragmentId: "log-outbound-2"),
                makeWaypoint(lat: 37.7780, lon: -122.4220, orderId: order3, fragmentId: "log-outbound-2"),
                makeWaypoint(lat: 37.7790, lon: -122.4230, orderId: order3, fragmentId: "log-outbound-2")
            ]
        )

        let logs = [log1, log2, log3]

        // Create unified route with gap detection
        let aggregator = FragmentAggregator()
        let route = try aggregator.aggregate(fragments: logs, gapThreshold: 300)

        // Create metadata
        let metadata = TripMetadata.from(logs: logs, truncated: false)

        // When - Generate and write export
        let exportPath = try generator.generateAndWrite(
            tripId: tripId,
            logs: logs,
            route: route,
            metadata: metadata,
            to: tempDirectory
        )

        // Then - Verify file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportPath))

        // Read and parse export
        let data = try Data(contentsOf: URL(fileURLWithPath: exportPath))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(TripDataExport.self, from: data)

        // Verify trip ID
        XCTAssertEqual(export.tripId, tripId)

        // Verify summary
        XCTAssertEqual(export.summary.totalRouteSegments, 3)
        XCTAssertEqual(export.summary.totalWaypoints, 10)
        XCTAssertEqual(export.summary.totalOrders, 3)
        XCTAssertFalse(export.summary.truncated)

        // Verify order sequence (first occurrence order)
        XCTAssertEqual(export.orderSequence.count, 3)
        XCTAssertEqual(export.orderSequence[0], order1.uuidString)
        XCTAssertEqual(export.orderSequence[1], order2.uuidString)
        XCTAssertEqual(export.orderSequence[2], order3.uuidString)

        // Verify route segments
        XCTAssertEqual(export.routeSegments.count, 3)

        // Segment 0: Log 1 with orders 1 and 2
        XCTAssertEqual(export.routeSegments[0].segmentIndex, 0)
        XCTAssertEqual(export.routeSegments[0].datadogLogId, "log-outbound-1")
        XCTAssertTrue(export.routeSegments[0].datadogUrl.contains("log-outbound-1"))
        XCTAssertEqual(export.routeSegments[0].waypointCount, 4)
        XCTAssertEqual(export.routeSegments[0].orders.count, 2)
        XCTAssertEqual(export.routeSegments[0].orders[0].orderId, order1.uuidString)
        XCTAssertEqual(export.routeSegments[0].orders[0].waypointCount, 2)
        XCTAssertEqual(export.routeSegments[0].orders[1].orderId, order2.uuidString)
        XCTAssertEqual(export.routeSegments[0].orders[1].waypointCount, 2)

        // Segment 1: Log 2 with no orders (return to restaurant)
        XCTAssertEqual(export.routeSegments[1].segmentIndex, 1)
        XCTAssertEqual(export.routeSegments[1].datadogLogId, "log-return-1")
        XCTAssertEqual(export.routeSegments[1].waypointCount, 3)
        XCTAssertTrue(export.routeSegments[1].orders.isEmpty)

        // Segment 2: Log 3 with order 3
        XCTAssertEqual(export.routeSegments[2].segmentIndex, 2)
        XCTAssertEqual(export.routeSegments[2].datadogLogId, "log-outbound-2")
        XCTAssertEqual(export.routeSegments[2].waypointCount, 3)
        XCTAssertEqual(export.routeSegments[2].orders.count, 1)
        XCTAssertEqual(export.routeSegments[2].orders[0].orderId, order3.uuidString)
        XCTAssertEqual(export.routeSegments[2].orders[0].waypointCount, 3)
    }

    func testExportWithGapsDetected() throws {
        // Given - Logs with time gap that triggers gap detection
        let tripId = UUID()

        let log1 = makeLogFragment(
            id: "log1",
            tripId: tripId,
            timestamp: Date(timeIntervalSince1970: 1700000000),
            waypoints: [
                makeWaypoint(lat: 37.7749, lon: -122.4194),
                makeWaypoint(lat: 37.7750, lon: -122.4195)
            ]
        )

        // Gap of 600 seconds (exceeds default 300s threshold)
        let log2 = makeLogFragment(
            id: "log2",
            tripId: tripId,
            timestamp: Date(timeIntervalSince1970: 1700000600),
            waypoints: [
                makeWaypoint(lat: 37.7800, lon: -122.4300),
                makeWaypoint(lat: 37.7810, lon: -122.4310)
            ]
        )

        let logs = [log1, log2]

        let aggregator = FragmentAggregator()
        let route = try aggregator.aggregate(fragments: logs, gapThreshold: 300)
        let metadata = TripMetadata.from(logs: logs, truncated: false)

        // When
        let exportPath = try generator.generateAndWrite(
            tripId: tripId,
            logs: logs,
            route: route,
            metadata: metadata,
            to: tempDirectory
        )

        // Then
        let data = try Data(contentsOf: URL(fileURLWithPath: exportPath))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(TripDataExport.self, from: data)

        // Should detect gaps
        XCTAssertTrue(export.summary.hasGaps)
    }

    func testExportWithTruncatedLogs() throws {
        // Given - Metadata indicates truncation
        let tripId = UUID()

        let log = makeLogFragment(
            id: "log1",
            tripId: tripId,
            timestamp: Date(timeIntervalSince1970: 1700000000),
            waypoints: [
                makeWaypoint(),
                makeWaypoint(lat: 37.7750)
            ]
        )

        let logs = [log]
        let route = UnifiedRoute.fromSingleFragment(log)
        let metadata = TripMetadata(
            totalLogs: 50,
            truncated: true,
            firstTimestamp: Date(),
            lastTimestamp: Date()
        )

        // When
        let exportPath = try generator.generateAndWrite(
            tripId: tripId,
            logs: logs,
            route: route,
            metadata: metadata,
            to: tempDirectory
        )

        // Then
        let data = try Data(contentsOf: URL(fileURLWithPath: exportPath))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(TripDataExport.self, from: data)

        XCTAssertTrue(export.summary.truncated)
    }

    func testExportFileNaming() throws {
        // Given
        let tripId = UUID()
        let log = makeLogFragment(
            id: "log1",
            tripId: tripId,
            timestamp: Date(),
            waypoints: [makeWaypoint(), makeWaypoint(lat: 37.7750)]
        )

        let route = UnifiedRoute.fromSingleFragment(log)
        let metadata = TripMetadata.single(timestamp: Date())

        // When
        let exportPath = try generator.generateAndWrite(
            tripId: tripId,
            logs: [log],
            route: route,
            metadata: metadata,
            to: tempDirectory
        )

        // Then - Verify correct file naming
        let expectedFilename = "map-data.json"
        XCTAssertTrue(exportPath.hasSuffix(expectedFilename))
    }

    func testExportIsHumanReadable() throws {
        // Given
        let tripId = UUID()
        let log = makeLogFragment(
            id: "test-log",
            tripId: tripId,
            timestamp: Date(timeIntervalSince1970: 1700000000),
            waypoints: [makeWaypoint(), makeWaypoint(lat: 37.7750)]
        )

        let route = UnifiedRoute.fromSingleFragment(log)
        let metadata = TripMetadata.single(timestamp: Date())

        // When
        let exportPath = try generator.generateAndWrite(
            tripId: tripId,
            logs: [log],
            route: route,
            metadata: metadata,
            to: tempDirectory
        )

        // Then - Verify pretty-printed output
        let content = try String(contentsOfFile: exportPath)

        // Should have newlines (not minified)
        XCTAssertTrue(content.contains("\n"))

        // Should have indentation
        XCTAssertTrue(content.contains("  "))

        // Should have sorted keys (generatedAt before orderSequence)
        let generatedAtPos = content.range(of: "generatedAt")?.lowerBound
        let orderSequencePos = content.range(of: "orderSequence")?.lowerBound
        XCTAssertNotNil(generatedAtPos)
        XCTAssertNotNil(orderSequencePos)
        XCTAssertLessThan(generatedAtPos!, orderSequencePos!)
    }

    func testExportDataDogLinksAreClickable() throws {
        // Given - Fragment with realistic DataDog log URL
        let tripId = UUID()
        let logId = "AYR123ABCdefGHI456"
        let expectedUrl = "https://app.datadoghq.com/logs?event=\(logId)&time=1700000000"

        let log = makeLogFragment(
            id: logId,
            tripId: tripId,
            timestamp: Date(timeIntervalSince1970: 1700000000),
            waypoints: [makeWaypoint(), makeWaypoint(lat: 37.7750)],
            logLink: expectedUrl
        )

        let route = UnifiedRoute.fromSingleFragment(log)
        let metadata = TripMetadata.single(timestamp: Date())

        // When
        let exportPath = try generator.generateAndWrite(
            tripId: tripId,
            logs: [log],
            route: route,
            metadata: metadata,
            to: tempDirectory
        )

        // Then - Verify URL is preserved in export
        let data = try Data(contentsOf: URL(fileURLWithPath: exportPath))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(TripDataExport.self, from: data)

        XCTAssertEqual(export.routeSegments[0].datadogUrl, expectedUrl)
        XCTAssertEqual(export.routeSegments[0].datadogLogId, logId)
    }

    func testExportValidationPassesForValidExport() throws {
        // Given
        let tripId = UUID()
        let log = makeLogFragment(
            id: "log1",
            tripId: tripId,
            timestamp: Date(),
            waypoints: [makeWaypoint(), makeWaypoint(lat: 37.7750)]
        )

        let route = UnifiedRoute.fromSingleFragment(log)
        let metadata = TripMetadata.single(timestamp: Date())

        // When
        let export = generator.generateExport(
            tripId: tripId,
            logs: [log],
            route: route,
            metadata: metadata
        )

        // Then
        XCTAssertTrue(export.isValid)
    }
}
