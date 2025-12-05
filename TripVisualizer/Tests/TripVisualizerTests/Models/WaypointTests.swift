import XCTest
@testable import TripVisualizer

final class WaypointTests: XCTestCase {

    // MARK: - Valid Waypoint Tests

    func testValidWaypointCreation() {
        let waypoint = Waypoint(latitude: 37.7749, longitude: -122.4194, orderId: nil)

        XCTAssertEqual(waypoint.latitude, 37.7749)
        XCTAssertEqual(waypoint.longitude, -122.4194)
        XCTAssertNil(waypoint.orderId)
    }

    func testWaypointWithOrderId() {
        let orderId = UUID()
        let waypoint = Waypoint(latitude: 37.7749, longitude: -122.4194, orderId: orderId)

        XCTAssertEqual(waypoint.orderId, orderId)
    }

    // MARK: - Latitude Validation Tests

    func testValidLatitudeBoundaries() {
        // Test minimum valid latitude
        XCTAssertTrue(Waypoint.isValidLatitude(-90.0))

        // Test maximum valid latitude
        XCTAssertTrue(Waypoint.isValidLatitude(90.0))

        // Test zero latitude (equator)
        XCTAssertTrue(Waypoint.isValidLatitude(0.0))

        // Test typical latitude
        XCTAssertTrue(Waypoint.isValidLatitude(37.7749))
    }

    func testInvalidLatitude() {
        // Below minimum
        XCTAssertFalse(Waypoint.isValidLatitude(-90.1))

        // Above maximum
        XCTAssertFalse(Waypoint.isValidLatitude(90.1))

        // Way out of range
        XCTAssertFalse(Waypoint.isValidLatitude(180.0))
        XCTAssertFalse(Waypoint.isValidLatitude(-180.0))
    }

    // MARK: - Longitude Validation Tests

    func testValidLongitudeBoundaries() {
        // Test minimum valid longitude
        XCTAssertTrue(Waypoint.isValidLongitude(-180.0))

        // Test maximum valid longitude
        XCTAssertTrue(Waypoint.isValidLongitude(180.0))

        // Test zero longitude (prime meridian)
        XCTAssertTrue(Waypoint.isValidLongitude(0.0))

        // Test typical longitude
        XCTAssertTrue(Waypoint.isValidLongitude(-122.4194))
    }

    func testInvalidLongitude() {
        // Below minimum
        XCTAssertFalse(Waypoint.isValidLongitude(-180.1))

        // Above maximum
        XCTAssertFalse(Waypoint.isValidLongitude(180.1))

        // Way out of range
        XCTAssertFalse(Waypoint.isValidLongitude(360.0))
        XCTAssertFalse(Waypoint.isValidLongitude(-360.0))
    }

    // MARK: - Coordinate Validation Tests

    func testIsValidCoordinates() {
        // Valid coordinates
        let validWaypoint = Waypoint(latitude: 37.7749, longitude: -122.4194, orderId: nil)
        XCTAssertTrue(validWaypoint.isValid)

        // Invalid latitude
        let invalidLatWaypoint = Waypoint(latitude: 91.0, longitude: -122.4194, orderId: nil)
        XCTAssertFalse(invalidLatWaypoint.isValid)

        // Invalid longitude
        let invalidLngWaypoint = Waypoint(latitude: 37.7749, longitude: 181.0, orderId: nil)
        XCTAssertFalse(invalidLngWaypoint.isValid)

        // Both invalid
        let bothInvalidWaypoint = Waypoint(latitude: 91.0, longitude: 181.0, orderId: nil)
        XCTAssertFalse(bothInvalidWaypoint.isValid)
    }

    // MARK: - Business Logic Tests

    func testIsDeliveryWaypoint() {
        // Waypoint with order ID is a delivery waypoint
        let deliveryWaypoint = Waypoint(latitude: 37.7749, longitude: -122.4194, orderId: UUID())
        XCTAssertTrue(deliveryWaypoint.isDeliveryWaypoint)

        // Waypoint without order ID is return-to-restaurant
        let returnWaypoint = Waypoint(latitude: 37.7749, longitude: -122.4194, orderId: nil)
        XCTAssertFalse(returnWaypoint.isDeliveryWaypoint)
    }

    // MARK: - Equatable Tests

    func testWaypointEquality() {
        let orderId = UUID()
        let waypoint1 = Waypoint(latitude: 37.7749, longitude: -122.4194, orderId: orderId)
        let waypoint2 = Waypoint(latitude: 37.7749, longitude: -122.4194, orderId: orderId)

        XCTAssertEqual(waypoint1, waypoint2)
    }

    func testWaypointInequality() {
        let waypoint1 = Waypoint(latitude: 37.7749, longitude: -122.4194, orderId: nil)
        let waypoint2 = Waypoint(latitude: 37.7750, longitude: -122.4194, orderId: nil)

        XCTAssertNotEqual(waypoint1, waypoint2)
    }

    // MARK: - Codable Tests

    func testWaypointEncoding() throws {
        let orderId = UUID()
        let waypoint = Waypoint(latitude: 37.7749, longitude: -122.4194, orderId: orderId)

        let encoder = JSONEncoder()
        let data = try encoder.encode(waypoint)

        XCTAssertFalse(data.isEmpty)
    }

    func testWaypointDecoding() throws {
        let json = """
        {
            "latitude": 37.7749,
            "longitude": -122.4194,
            "orderId": "550e8400-e29b-41d4-a716-446655440000"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let waypoint = try decoder.decode(Waypoint.self, from: json)

        XCTAssertEqual(waypoint.latitude, 37.7749)
        XCTAssertEqual(waypoint.longitude, -122.4194)
        XCTAssertNotNil(waypoint.orderId)
    }

    func testWaypointDecodingWithoutOrderId() throws {
        let json = """
        {
            "latitude": 37.7749,
            "longitude": -122.4194
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let waypoint = try decoder.decode(Waypoint.self, from: json)

        XCTAssertNil(waypoint.orderId)
    }
}
