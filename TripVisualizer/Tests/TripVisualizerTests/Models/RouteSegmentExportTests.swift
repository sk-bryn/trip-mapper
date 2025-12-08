import XCTest
@testable import TripVisualizer

final class RouteSegmentExportTests: XCTestCase {

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
        tripId: UUID = UUID(),
        timestamp: Date = Date(),
        waypoints: [Waypoint]? = nil,
        logLink: String = "https://app.datadoghq.com/logs?query=@id:log123"
    ) -> LogFragment {
        let defaultWaypoints = waypoints ?? [
            makeWaypoint(lat: 37.7749, lon: -122.4194),
            makeWaypoint(lat: 37.7750, lon: -122.4195)
        ]
        return LogFragment(
            id: id,
            tripId: tripId,
            timestamp: timestamp,
            waypoints: defaultWaypoints,
            logLink: logLink
        )
    }

    // MARK: - Initialization Tests

    func testRouteSegmentExportCreation() {
        let timestamp = Date()
        let orders = [OrderSummary(orderId: "ORD-001", waypointCount: 25)]

        let segment = RouteSegmentExport(
            segmentIndex: 0,
            datadogLogId: "log123",
            datadogUrl: "https://app.datadoghq.com/logs?query=@id:log123",
            timestamp: timestamp,
            waypointCount: 50,
            orders: orders
        )

        XCTAssertEqual(segment.segmentIndex, 0)
        XCTAssertEqual(segment.datadogLogId, "log123")
        XCTAssertEqual(segment.datadogUrl, "https://app.datadoghq.com/logs?query=@id:log123")
        XCTAssertEqual(segment.timestamp, timestamp)
        XCTAssertEqual(segment.waypointCount, 50)
        XCTAssertEqual(segment.orders.count, 1)
    }

    // MARK: - Factory Method Tests

    func testFromLogFragmentBasic() {
        let fragment = makeLogFragment()

        let segment = RouteSegmentExport.from(index: 0, fragment: fragment)

        XCTAssertEqual(segment.segmentIndex, 0)
        XCTAssertEqual(segment.datadogLogId, "log123")
        XCTAssertEqual(segment.datadogUrl, fragment.logLink)
        XCTAssertEqual(segment.timestamp, fragment.timestamp)
        XCTAssertEqual(segment.waypointCount, 2)
        XCTAssertTrue(segment.orders.isEmpty) // No orderIds in default waypoints
    }

    func testFromLogFragmentWithOrders() {
        let orderId1 = UUID()
        let orderId2 = UUID()

        let waypoints = [
            makeWaypoint(orderId: orderId1),
            makeWaypoint(orderId: orderId1),
            makeWaypoint(orderId: orderId2),
            makeWaypoint(orderId: orderId1),
            makeWaypoint(orderId: nil) // Return to restaurant
        ]

        let fragment = makeLogFragment(waypoints: waypoints)
        let segment = RouteSegmentExport.from(index: 1, fragment: fragment)

        XCTAssertEqual(segment.segmentIndex, 1)
        XCTAssertEqual(segment.waypointCount, 5)
        XCTAssertEqual(segment.orders.count, 2)

        // Order1 appears first with 3 waypoints
        XCTAssertEqual(segment.orders[0].orderId, orderId1.uuidString)
        XCTAssertEqual(segment.orders[0].waypointCount, 3)

        // Order2 appears second with 1 waypoint
        XCTAssertEqual(segment.orders[1].orderId, orderId2.uuidString)
        XCTAssertEqual(segment.orders[1].waypointCount, 1)
    }

    func testFromLogFragmentWithSingleOrder() {
        let orderId = UUID()

        let waypoints = [
            makeWaypoint(orderId: orderId),
            makeWaypoint(orderId: orderId),
            makeWaypoint(orderId: orderId)
        ]

        let fragment = makeLogFragment(waypoints: waypoints)
        let segment = RouteSegmentExport.from(index: 0, fragment: fragment)

        XCTAssertEqual(segment.orders.count, 1)
        XCTAssertEqual(segment.orders[0].orderId, orderId.uuidString)
        XCTAssertEqual(segment.orders[0].waypointCount, 3)
    }

    func testFromLogFragmentWithNoOrders() {
        let waypoints = [
            makeWaypoint(orderId: nil),
            makeWaypoint(orderId: nil)
        ]

        let fragment = makeLogFragment(waypoints: waypoints)
        let segment = RouteSegmentExport.from(index: 0, fragment: fragment)

        XCTAssertTrue(segment.orders.isEmpty)
    }

    func testFromLogFragmentPreservesFirstOccurrenceOrder() {
        let orderA = UUID()
        let orderB = UUID()
        let orderC = UUID()

        // Orders appear: A, B, C, A, B
        let waypoints = [
            makeWaypoint(orderId: orderA),
            makeWaypoint(orderId: orderB),
            makeWaypoint(orderId: orderC),
            makeWaypoint(orderId: orderA),
            makeWaypoint(orderId: orderB)
        ]

        let fragment = makeLogFragment(waypoints: waypoints)
        let segment = RouteSegmentExport.from(index: 0, fragment: fragment)

        // Order should be A, B, C (first occurrence order)
        XCTAssertEqual(segment.orders.count, 3)
        XCTAssertEqual(segment.orders[0].orderId, orderA.uuidString)
        XCTAssertEqual(segment.orders[1].orderId, orderB.uuidString)
        XCTAssertEqual(segment.orders[2].orderId, orderC.uuidString)
    }

    // MARK: - DataDog URL Tests

    func testDatadogUrlPreserved() {
        let expectedUrl = "https://app.datadoghq.com/logs?query=@id:abc123&time=12345"
        let fragment = makeLogFragment(logLink: expectedUrl)
        let segment = RouteSegmentExport.from(index: 0, fragment: fragment)

        XCTAssertEqual(segment.datadogUrl, expectedUrl)
    }

    func testDatadogUrlFormatInExportOutput() throws {
        let logId = "abc123xyz"
        let expectedUrl = "https://app.datadoghq.com/logs?query=@id:\(logId)"
        let fragment = makeLogFragment(id: logId, logLink: expectedUrl)
        let segment = RouteSegmentExport.from(index: 0, fragment: fragment)

        // Encode to JSON and verify URL appears correctly
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(segment)
        let json = String(data: data, encoding: .utf8)!

        // Verify the URL is in the JSON output and is clickable (contains full URL)
        XCTAssertTrue(json.contains("\"datadogUrl\""), "JSON should contain datadogUrl field. Got: \(json)")
        XCTAssertTrue(json.contains("app.datadoghq.com"), "JSON should contain DataDog URL. Got: \(json)")
        XCTAssertTrue(json.contains(logId), "JSON should contain log ID '\(logId)'. Got: \(json)")
        XCTAssertTrue(json.contains("\"datadogLogId\""), "JSON should contain datadogLogId field. Got: \(json)")
    }

    func testDatadogLogIdMatchesFragmentId() {
        let logId = "test-log-id-12345"
        let fragment = makeLogFragment(id: logId)
        let segment = RouteSegmentExport.from(index: 0, fragment: fragment)

        XCTAssertEqual(segment.datadogLogId, logId)
    }

    // MARK: - Validation Tests

    func testIsValidWithValidSegment() {
        let segment = RouteSegmentExport(
            segmentIndex: 0,
            datadogLogId: "log123",
            datadogUrl: "https://app.datadoghq.com/logs",
            timestamp: Date(),
            waypointCount: 50,
            orders: []
        )

        XCTAssertTrue(segment.isValid)
    }

    func testIsValidWithNegativeIndexReturnsFalse() {
        let segment = RouteSegmentExport(
            segmentIndex: -1,
            datadogLogId: "log123",
            datadogUrl: "https://app.datadoghq.com/logs",
            timestamp: Date(),
            waypointCount: 50,
            orders: []
        )

        XCTAssertFalse(segment.isValid)
    }

    func testIsValidWithEmptyLogIdReturnsFalse() {
        let segment = RouteSegmentExport(
            segmentIndex: 0,
            datadogLogId: "",
            datadogUrl: "https://app.datadoghq.com/logs",
            timestamp: Date(),
            waypointCount: 50,
            orders: []
        )

        XCTAssertFalse(segment.isValid)
    }

    func testIsValidWithEmptyUrlReturnsFalse() {
        let segment = RouteSegmentExport(
            segmentIndex: 0,
            datadogLogId: "log123",
            datadogUrl: "",
            timestamp: Date(),
            waypointCount: 50,
            orders: []
        )

        XCTAssertFalse(segment.isValid)
    }

    func testIsValidWithZeroWaypointsIsValid() {
        // Zero waypoints is valid (e.g., gap segment)
        let segment = RouteSegmentExport(
            segmentIndex: 0,
            datadogLogId: "log123",
            datadogUrl: "https://app.datadoghq.com/logs",
            timestamp: Date(),
            waypointCount: 0,
            orders: []
        )

        XCTAssertTrue(segment.isValid)
    }

    // MARK: - Equatable Tests

    func testRouteSegmentExportEquality() {
        let timestamp = Date()
        let orders = [OrderSummary(orderId: "ORD-001", waypointCount: 25)]

        let segment1 = RouteSegmentExport(
            segmentIndex: 0,
            datadogLogId: "log123",
            datadogUrl: "https://app.datadoghq.com/logs",
            timestamp: timestamp,
            waypointCount: 50,
            orders: orders
        )

        let segment2 = RouteSegmentExport(
            segmentIndex: 0,
            datadogLogId: "log123",
            datadogUrl: "https://app.datadoghq.com/logs",
            timestamp: timestamp,
            waypointCount: 50,
            orders: orders
        )

        XCTAssertEqual(segment1, segment2)
    }

    func testRouteSegmentExportInequality() {
        let timestamp = Date()

        let segment1 = RouteSegmentExport(
            segmentIndex: 0,
            datadogLogId: "log123",
            datadogUrl: "https://app.datadoghq.com/logs",
            timestamp: timestamp,
            waypointCount: 50,
            orders: []
        )

        let segment2 = RouteSegmentExport(
            segmentIndex: 1,
            datadogLogId: "log456",
            datadogUrl: "https://app.datadoghq.com/logs",
            timestamp: timestamp,
            waypointCount: 50,
            orders: []
        )

        XCTAssertNotEqual(segment1, segment2)
    }

    // MARK: - Codable Tests

    func testRouteSegmentExportEncoding() throws {
        let segment = RouteSegmentExport(
            segmentIndex: 0,
            datadogLogId: "log123",
            datadogUrl: "https://app.datadoghq.com/logs",
            timestamp: Date(timeIntervalSince1970: 1700000000),
            waypointCount: 50,
            orders: [OrderSummary(orderId: "ORD-001", waypointCount: 25)]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(segment)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"segmentIndex\" : 0"))
        XCTAssertTrue(json.contains("\"datadogLogId\" : \"log123\""))
        XCTAssertTrue(json.contains("\"datadogUrl\""))
        XCTAssertTrue(json.contains("\"waypointCount\" : 50"))
        XCTAssertTrue(json.contains("\"orders\""))
    }

    func testRouteSegmentExportDecoding() throws {
        let json = """
        {
            "segmentIndex": 0,
            "datadogLogId": "log123",
            "datadogUrl": "https://app.datadoghq.com/logs",
            "timestamp": "2023-11-14T22:13:20Z",
            "waypointCount": 50,
            "orders": [
                { "orderId": "ORD-001", "waypointCount": 25 }
            ]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let segment = try decoder.decode(RouteSegmentExport.self, from: json)

        XCTAssertEqual(segment.segmentIndex, 0)
        XCTAssertEqual(segment.datadogLogId, "log123")
        XCTAssertEqual(segment.waypointCount, 50)
        XCTAssertEqual(segment.orders.count, 1)
        XCTAssertEqual(segment.orders[0].orderId, "ORD-001")
    }

    func testRouteSegmentExportRoundTrip() throws {
        let original = RouteSegmentExport(
            segmentIndex: 5,
            datadogLogId: "test-log-id",
            datadogUrl: "https://app.datadoghq.com/logs?query=test",
            timestamp: Date(timeIntervalSince1970: 1700000000),
            waypointCount: 100,
            orders: [
                OrderSummary(orderId: "ORD-A", waypointCount: 60),
                OrderSummary(orderId: "ORD-B", waypointCount: 40)
            ]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(RouteSegmentExport.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    // MARK: - Description Tests

    func testDescription() {
        let segment = RouteSegmentExport(
            segmentIndex: 0,
            datadogLogId: "log12345678",
            datadogUrl: "https://app.datadoghq.com/logs",
            timestamp: Date(),
            waypointCount: 50,
            orders: [OrderSummary(orderId: "ORD-001", waypointCount: 25)]
        )

        let description = segment.description

        XCTAssertTrue(description.contains("RouteSegmentExport"))
        XCTAssertTrue(description.contains("[0]"))
        XCTAssertTrue(description.contains("log12345"))
        XCTAssertTrue(description.contains("50 waypoints"))
        XCTAssertTrue(description.contains("1 orders"))
    }
}
