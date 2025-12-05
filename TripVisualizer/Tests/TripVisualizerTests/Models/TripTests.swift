import XCTest
@testable import TripVisualizer

final class TripTests: XCTestCase {

    // MARK: - Test Data

    private func createValidWaypoints(count: Int) -> [Waypoint] {
        (0..<count).map { index in
            Waypoint(
                latitude: 37.7749 + Double(index) * 0.001,
                longitude: -122.4194 + Double(index) * 0.001,
                orderId: index % 2 == 0 ? UUID() : nil
            )
        }
    }

    // MARK: - Valid Trip Tests

    func testValidTripCreation() {
        let tripId = UUID()
        let waypoints = createValidWaypoints(count: 5)
        let timestamp = Date()

        let trip = Trip(
            id: tripId,
            logId: "log-123",
            logLink: "https://app.datadoghq.com/logs?query=log-123",
            waypoints: waypoints,
            timestamp: timestamp
        )

        XCTAssertEqual(trip.id, tripId)
        XCTAssertEqual(trip.logId, "log-123")
        XCTAssertEqual(trip.logLink, "https://app.datadoghq.com/logs?query=log-123")
        XCTAssertEqual(trip.waypoints.count, 5)
        XCTAssertEqual(trip.timestamp, timestamp)
    }

    // MARK: - Waypoint Count Validation

    func testTripWithMinimumWaypoints() {
        let trip = Trip(
            id: UUID(),
            logId: "log-123",
            logLink: "https://example.com",
            waypoints: createValidWaypoints(count: 2),
            timestamp: Date()
        )

        XCTAssertTrue(trip.hasMinimumWaypoints)
    }

    func testTripWithInsufficientWaypoints() {
        let trip = Trip(
            id: UUID(),
            logId: "log-123",
            logLink: "https://example.com",
            waypoints: createValidWaypoints(count: 1),
            timestamp: Date()
        )

        XCTAssertFalse(trip.hasMinimumWaypoints)
    }

    func testTripWithNoWaypoints() {
        let trip = Trip(
            id: UUID(),
            logId: "log-123",
            logLink: "https://example.com",
            waypoints: [],
            timestamp: Date()
        )

        XCTAssertFalse(trip.hasMinimumWaypoints)
    }

    // MARK: - Start and End Waypoints

    func testStartWaypoint() {
        let waypoints = createValidWaypoints(count: 5)
        let trip = Trip(
            id: UUID(),
            logId: "log-123",
            logLink: "https://example.com",
            waypoints: waypoints,
            timestamp: Date()
        )

        XCTAssertEqual(trip.startWaypoint, waypoints.first)
    }

    func testEndWaypoint() {
        let waypoints = createValidWaypoints(count: 5)
        let trip = Trip(
            id: UUID(),
            logId: "log-123",
            logLink: "https://example.com",
            waypoints: waypoints,
            timestamp: Date()
        )

        XCTAssertEqual(trip.endWaypoint, waypoints.last)
    }

    func testStartWaypointWithEmptyWaypoints() {
        let trip = Trip(
            id: UUID(),
            logId: "log-123",
            logLink: "https://example.com",
            waypoints: [],
            timestamp: Date()
        )

        XCTAssertNil(trip.startWaypoint)
        XCTAssertNil(trip.endWaypoint)
    }

    // MARK: - Valid Waypoints Filtering

    func testValidWaypointsCount() {
        var waypoints = createValidWaypoints(count: 3)
        // Add an invalid waypoint
        waypoints.append(Waypoint(latitude: 91.0, longitude: -122.4194, orderId: nil))

        let trip = Trip(
            id: UUID(),
            logId: "log-123",
            logLink: "https://example.com",
            waypoints: waypoints,
            timestamp: Date()
        )

        XCTAssertEqual(trip.validWaypoints.count, 3)
        XCTAssertEqual(trip.waypoints.count, 4)
    }

    // MARK: - Delivery vs Return Waypoints

    func testDeliveryWaypointsCount() {
        // Create waypoints: even indices have order IDs, odd indices don't
        let waypoints = createValidWaypoints(count: 6)
        let trip = Trip(
            id: UUID(),
            logId: "log-123",
            logLink: "https://example.com",
            waypoints: waypoints,
            timestamp: Date()
        )

        // 0, 2, 4 should have order IDs
        XCTAssertEqual(trip.deliveryWaypoints.count, 3)
    }

    func testReturnToRestaurantWaypointsCount() {
        let waypoints = createValidWaypoints(count: 6)
        let trip = Trip(
            id: UUID(),
            logId: "log-123",
            logLink: "https://example.com",
            waypoints: waypoints,
            timestamp: Date()
        )

        // 1, 3, 5 should NOT have order IDs
        XCTAssertEqual(trip.returnWaypoints.count, 3)
    }

    // MARK: - Equatable Tests

    func testTripEquality() {
        let tripId = UUID()
        let waypoints = createValidWaypoints(count: 3)
        let timestamp = Date()

        let trip1 = Trip(
            id: tripId,
            logId: "log-123",
            logLink: "https://example.com",
            waypoints: waypoints,
            timestamp: timestamp
        )

        let trip2 = Trip(
            id: tripId,
            logId: "log-123",
            logLink: "https://example.com",
            waypoints: waypoints,
            timestamp: timestamp
        )

        XCTAssertEqual(trip1, trip2)
    }

    func testTripInequalityByID() {
        let waypoints = createValidWaypoints(count: 3)
        let timestamp = Date()

        let trip1 = Trip(
            id: UUID(),
            logId: "log-123",
            logLink: "https://example.com",
            waypoints: waypoints,
            timestamp: timestamp
        )

        let trip2 = Trip(
            id: UUID(),
            logId: "log-123",
            logLink: "https://example.com",
            waypoints: waypoints,
            timestamp: timestamp
        )

        XCTAssertNotEqual(trip1, trip2)
    }

    // MARK: - Codable Tests

    func testTripEncoding() throws {
        let trip = Trip(
            id: UUID(),
            logId: "log-123",
            logLink: "https://example.com",
            waypoints: createValidWaypoints(count: 3),
            timestamp: Date()
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(trip)

        XCTAssertFalse(data.isEmpty)
    }

    func testTripDecoding() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "logId": "log-123",
            "logLink": "https://example.com",
            "waypoints": [
                {"latitude": 37.7749, "longitude": -122.4194},
                {"latitude": 37.7750, "longitude": -122.4195}
            ],
            "timestamp": "2025-12-04T10:30:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let trip = try decoder.decode(Trip.self, from: json)

        XCTAssertEqual(trip.logId, "log-123")
        XCTAssertEqual(trip.waypoints.count, 2)
    }
}
