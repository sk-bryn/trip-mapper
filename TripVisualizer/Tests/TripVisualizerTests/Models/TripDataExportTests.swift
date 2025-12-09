import XCTest
@testable import TripVisualizer

final class TripDataExportTests: XCTestCase {

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
            logLink: logLink ?? "https://app.datadoghq.com/logs?query=@id:\(id)"
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

    func testTripDataExportCreation() {
        let tripId = UUID()
        let generatedAt = Date()
        let summary = ExportSummary(
            totalRouteSegments: 5,
            totalWaypoints: 270,
            totalOrders: 3,
            hasGaps: true,
            truncated: false,
            incompleteData: false
        )
        let orderSequence = ["ORD-001", "ORD-002", "ORD-003"]
        let routeSegments = [
            RouteSegmentExport(
                segmentIndex: 0,
                datadogLogId: "log123",
                datadogUrl: "https://app.datadoghq.com/logs",
                timestamp: generatedAt,
                waypointCount: 50,
                orders: []
            )
        ]

        let export = TripDataExport(
            tripId: tripId,
            generatedAt: generatedAt,
            summary: summary,
            orderSequence: orderSequence,
            routeSegments: routeSegments
        )

        XCTAssertEqual(export.tripId, tripId)
        XCTAssertEqual(export.generatedAt, generatedAt)
        XCTAssertEqual(export.summary.totalRouteSegments, 5)
        XCTAssertEqual(export.orderSequence.count, 3)
        XCTAssertEqual(export.routeSegments.count, 1)
    }

    // MARK: - Factory Method Tests

    func testFromLogsBasic() {
        let tripId = UUID()
        let log1 = makeLogFragment(id: "log1", tripId: tripId)
        let log2 = makeLogFragment(id: "log2", tripId: tripId)
        let logs = [log1, log2]

        let route = makeUnifiedRoute(tripId: tripId)
        let metadata = makeMetadata()

        let export = TripDataExport.from(
            tripId: tripId,
            logs: logs,
            route: route,
            metadata: metadata
        )

        XCTAssertEqual(export.tripId, tripId)
        XCTAssertEqual(export.routeSegments.count, 2)
        XCTAssertEqual(export.summary.totalRouteSegments, 2)
    }

    func testFromLogsWithOrders() {
        let tripId = UUID()
        let order1 = UUID()
        let order2 = UUID()
        let order3 = UUID()

        let log1Waypoints = [
            makeWaypoint(orderId: order1),
            makeWaypoint(orderId: order2)
        ]
        let log2Waypoints = [
            makeWaypoint(orderId: order2),
            makeWaypoint(orderId: order3)
        ]

        let log1 = makeLogFragment(id: "log1", tripId: tripId, waypoints: log1Waypoints)
        let log2 = makeLogFragment(id: "log2", tripId: tripId, waypoints: log2Waypoints)
        let logs = [log1, log2]

        let route = makeUnifiedRoute(tripId: tripId)
        let metadata = makeMetadata()

        let export = TripDataExport.from(
            tripId: tripId,
            logs: logs,
            route: route,
            metadata: metadata
        )

        // Order sequence should be order1, order2, order3 (first occurrence)
        XCTAssertEqual(export.orderSequence.count, 3)
        XCTAssertEqual(export.orderSequence[0], order1.uuidString)
        XCTAssertEqual(export.orderSequence[1], order2.uuidString)
        XCTAssertEqual(export.orderSequence[2], order3.uuidString)
        XCTAssertEqual(export.summary.totalOrders, 3)
    }

    func testFromLogsWithGaps() {
        let tripId = UUID()
        let log = makeLogFragment(tripId: tripId)
        let route = makeUnifiedRoute(tripId: tripId, hasGaps: true)
        let metadata = makeMetadata()

        let export = TripDataExport.from(
            tripId: tripId,
            logs: [log],
            route: route,
            metadata: metadata
        )

        XCTAssertTrue(export.summary.hasGaps)
    }

    func testFromLogsWithTruncation() {
        let tripId = UUID()
        let log = makeLogFragment(tripId: tripId)
        let route = makeUnifiedRoute(tripId: tripId)
        let metadata = makeMetadata(truncated: true)

        let export = TripDataExport.from(
            tripId: tripId,
            logs: [log],
            route: route,
            metadata: metadata
        )

        XCTAssertTrue(export.summary.truncated)
    }

    func testFromLogsWithIncompleteData() {
        let tripId = UUID()
        let log = makeLogFragment(tripId: tripId)
        let route = makeUnifiedRoute(tripId: tripId, isComplete: false)
        let metadata = makeMetadata()

        let export = TripDataExport.from(
            tripId: tripId,
            logs: [log],
            route: route,
            metadata: metadata
        )

        XCTAssertTrue(export.summary.incompleteData)
    }

    func testFromLogsCalculatesTotalWaypoints() {
        let tripId = UUID()
        let log1Waypoints = [
            makeWaypoint(),
            makeWaypoint(),
            makeWaypoint()
        ]
        let log2Waypoints = [
            makeWaypoint(),
            makeWaypoint()
        ]

        let log1 = makeLogFragment(id: "log1", tripId: tripId, waypoints: log1Waypoints)
        let log2 = makeLogFragment(id: "log2", tripId: tripId, waypoints: log2Waypoints)

        let route = makeUnifiedRoute(tripId: tripId)
        let metadata = makeMetadata()

        let export = TripDataExport.from(
            tripId: tripId,
            logs: [log1, log2],
            route: route,
            metadata: metadata
        )

        XCTAssertEqual(export.summary.totalWaypoints, 5)
    }

    func testFromLogsWithNoOrders() {
        let tripId = UUID()
        let waypoints = [
            makeWaypoint(orderId: nil),
            makeWaypoint(orderId: nil)
        ]
        let log = makeLogFragment(tripId: tripId, waypoints: waypoints)

        let route = makeUnifiedRoute(tripId: tripId)
        let metadata = makeMetadata()

        let export = TripDataExport.from(
            tripId: tripId,
            logs: [log],
            route: route,
            metadata: metadata
        )

        XCTAssertTrue(export.orderSequence.isEmpty)
        XCTAssertEqual(export.summary.totalOrders, 0)
    }

    func testOrderSequencePreservesFirstOccurrenceOrder() {
        let tripId = UUID()
        let orderA = UUID()
        let orderB = UUID()

        // Log1: A, B, A
        // Log2: B, A
        // Expected: A, B (first occurrence)
        let log1Waypoints = [
            makeWaypoint(orderId: orderA),
            makeWaypoint(orderId: orderB),
            makeWaypoint(orderId: orderA)
        ]
        let log2Waypoints = [
            makeWaypoint(orderId: orderB),
            makeWaypoint(orderId: orderA)
        ]

        let log1 = makeLogFragment(id: "log1", tripId: tripId, waypoints: log1Waypoints)
        let log2 = makeLogFragment(id: "log2", tripId: tripId, waypoints: log2Waypoints)

        let route = makeUnifiedRoute(tripId: tripId)
        let metadata = makeMetadata()

        let export = TripDataExport.from(
            tripId: tripId,
            logs: [log1, log2],
            route: route,
            metadata: metadata
        )

        XCTAssertEqual(export.orderSequence.count, 2)
        XCTAssertEqual(export.orderSequence[0], orderA.uuidString)
        XCTAssertEqual(export.orderSequence[1], orderB.uuidString)
    }

    // MARK: - Validation Tests

    func testIsValidWithValidExport() {
        let tripId = UUID()
        let summary = ExportSummary(
            totalRouteSegments: 1,
            totalWaypoints: 50,
            totalOrders: 1,
            hasGaps: false,
            truncated: false,
            incompleteData: false
        )
        let segment = RouteSegmentExport(
            segmentIndex: 0,
            datadogLogId: "log123",
            datadogUrl: "https://app.datadoghq.com/logs",
            timestamp: Date(),
            waypointCount: 50,
            orders: [OrderSummary(orderId: "ORD-001", waypointCount: 50)]
        )

        let export = TripDataExport(
            tripId: tripId,
            generatedAt: Date(),
            summary: summary,
            orderSequence: ["ORD-001"],
            routeSegments: [segment]
        )

        XCTAssertTrue(export.isValid)
    }

    func testIsValidWithEmptySegmentsReturnsFalse() {
        let tripId = UUID()
        let summary = ExportSummary(
            totalRouteSegments: 0,
            totalWaypoints: 0,
            totalOrders: 0,
            hasGaps: false,
            truncated: false,
            incompleteData: false
        )

        let export = TripDataExport(
            tripId: tripId,
            generatedAt: Date(),
            summary: summary,
            orderSequence: [],
            routeSegments: []
        )

        XCTAssertFalse(export.isValid)
    }

    func testIsValidWithMismatchedSegmentCountReturnsFalse() {
        let tripId = UUID()
        let summary = ExportSummary(
            totalRouteSegments: 2, // Says 2
            totalWaypoints: 50,
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
            waypointCount: 50,
            orders: []
        )

        let export = TripDataExport(
            tripId: tripId,
            generatedAt: Date(),
            summary: summary,
            orderSequence: [],
            routeSegments: [segment] // Only 1 segment
        )

        XCTAssertFalse(export.isValid)
    }

    func testIsValidWithMismatchedOrderCountReturnsFalse() {
        let tripId = UUID()
        let summary = ExportSummary(
            totalRouteSegments: 1,
            totalWaypoints: 50,
            totalOrders: 2, // Says 2
            hasGaps: false,
            truncated: false,
            incompleteData: false
        )
        let segment = RouteSegmentExport(
            segmentIndex: 0,
            datadogLogId: "log123",
            datadogUrl: "https://app.datadoghq.com/logs",
            timestamp: Date(),
            waypointCount: 50,
            orders: []
        )

        let export = TripDataExport(
            tripId: tripId,
            generatedAt: Date(),
            summary: summary,
            orderSequence: ["ORD-001"], // Only 1 order
            routeSegments: [segment]
        )

        XCTAssertFalse(export.isValid)
    }

    // MARK: - Codable Tests

    func testTripDataExportEncoding() throws {
        let tripId = UUID()
        let summary = ExportSummary(
            totalRouteSegments: 1,
            totalWaypoints: 50,
            totalOrders: 1,
            hasGaps: false,
            truncated: false,
            incompleteData: false
        )
        let segment = RouteSegmentExport(
            segmentIndex: 0,
            datadogLogId: "log123",
            datadogUrl: "https://app.datadoghq.com/logs",
            timestamp: Date(timeIntervalSince1970: 1700000000),
            waypointCount: 50,
            orders: [OrderSummary(orderId: "ORD-001", waypointCount: 50)]
        )

        let export = TripDataExport(
            tripId: tripId,
            generatedAt: Date(timeIntervalSince1970: 1700000000),
            summary: summary,
            orderSequence: ["ORD-001"],
            routeSegments: [segment]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(export)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"tripId\""))
        XCTAssertTrue(json.contains("\"generatedAt\""))
        XCTAssertTrue(json.contains("\"summary\""))
        XCTAssertTrue(json.contains("\"orderSequence\""))
        XCTAssertTrue(json.contains("\"routeSegments\""))
        XCTAssertTrue(json.contains("ORD-001"))
    }

    func testTripDataExportDecoding() throws {
        let tripId = UUID()
        let json = """
        {
            "tripId": "\(tripId.uuidString)",
            "generatedAt": "2023-11-14T22:13:20Z",
            "summary": {
                "totalRouteSegments": 1,
                "totalWaypoints": 50,
                "totalOrders": 1,
                "hasGaps": false,
                "truncated": false,
                "incompleteData": false
            },
            "orderSequence": ["ORD-001"],
            "routeSegments": [
                {
                    "segmentIndex": 0,
                    "datadogLogId": "log123",
                    "datadogUrl": "https://app.datadoghq.com/logs",
                    "timestamp": "2023-11-14T22:13:20Z",
                    "waypointCount": 50,
                    "orders": [
                        { "orderId": "ORD-001", "waypointCount": 50 }
                    ]
                }
            ]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(TripDataExport.self, from: json)

        XCTAssertEqual(export.tripId, tripId)
        XCTAssertEqual(export.summary.totalRouteSegments, 1)
        XCTAssertEqual(export.orderSequence.count, 1)
        XCTAssertEqual(export.routeSegments.count, 1)
    }

    func testTripDataExportRoundTrip() throws {
        let tripId = UUID()
        let summary = ExportSummary(
            totalRouteSegments: 2,
            totalWaypoints: 100,
            totalOrders: 2,
            hasGaps: true,
            truncated: false,
            incompleteData: false
        )
        let segments = [
            RouteSegmentExport(
                segmentIndex: 0,
                datadogLogId: "log1",
                datadogUrl: "https://app.datadoghq.com/logs?1",
                timestamp: Date(timeIntervalSince1970: 1700000000),
                waypointCount: 60,
                orders: [OrderSummary(orderId: "ORD-A", waypointCount: 60)]
            ),
            RouteSegmentExport(
                segmentIndex: 1,
                datadogLogId: "log2",
                datadogUrl: "https://app.datadoghq.com/logs?2",
                timestamp: Date(timeIntervalSince1970: 1700001000),
                waypointCount: 40,
                orders: [OrderSummary(orderId: "ORD-B", waypointCount: 40)]
            )
        ]

        let original = TripDataExport(
            tripId: tripId,
            generatedAt: Date(timeIntervalSince1970: 1700002000),
            summary: summary,
            orderSequence: ["ORD-A", "ORD-B"],
            routeSegments: segments
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TripDataExport.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    // MARK: - Description Tests

    func testDescription() {
        let tripId = UUID()
        let summary = ExportSummary(
            totalRouteSegments: 5,
            totalWaypoints: 270,
            totalOrders: 3,
            hasGaps: false,
            truncated: false,
            incompleteData: false
        )

        let export = TripDataExport(
            tripId: tripId,
            generatedAt: Date(),
            summary: summary,
            orderSequence: ["ORD-001", "ORD-002", "ORD-003"],
            routeSegments: []
        )

        let description = export.description

        XCTAssertTrue(description.contains("TripDataExport"))
        XCTAssertTrue(description.contains("5 segments"))
        XCTAssertTrue(description.contains("270 waypoints"))
        XCTAssertTrue(description.contains("3 orders"))
    }
}
