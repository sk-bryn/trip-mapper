import XCTest
@testable import TripVisualizer

final class LogFragmentTests: XCTestCase {

    // MARK: - Test Helpers

    private func makeWaypoint(lat: Double = 37.7749, lon: Double = -122.4194) -> Waypoint {
        Waypoint(latitude: lat, longitude: lon, orderId: nil, fragmentId: nil)
    }

    private func makeFragment(
        id: String = "log123",
        tripId: UUID = UUID(),
        timestamp: Date = Date(),
        waypointCount: Int = 3,
        logLink: String = "https://app.datadoghq.com/logs?query=test"
    ) -> LogFragment {
        let waypoints = (0..<waypointCount).map { index in
            makeWaypoint(lat: 37.7749 + Double(index) * 0.001, lon: -122.4194)
        }
        return LogFragment(
            id: id,
            tripId: tripId,
            timestamp: timestamp,
            waypoints: waypoints,
            logLink: logLink
        )
    }

    // MARK: - Initialization Tests

    func testFragmentCreation() {
        let tripId = UUID()
        let timestamp = Date()
        let waypoints = [
            makeWaypoint(lat: 37.7749, lon: -122.4194),
            makeWaypoint(lat: 37.7750, lon: -122.4195)
        ]

        let fragment = LogFragment(
            id: "log123",
            tripId: tripId,
            timestamp: timestamp,
            waypoints: waypoints,
            logLink: "https://app.datadoghq.com/logs?query=test"
        )

        XCTAssertEqual(fragment.id, "log123")
        XCTAssertEqual(fragment.tripId, tripId)
        XCTAssertEqual(fragment.timestamp, timestamp)
        XCTAssertEqual(fragment.waypoints.count, 2)
        XCTAssertEqual(fragment.logLink, "https://app.datadoghq.com/logs?query=test")
    }

    // MARK: - Computed Property Tests

    func testWaypointCount() {
        let fragment = makeFragment(waypointCount: 5)
        XCTAssertEqual(fragment.waypointCount, 5)
    }

    func testStartLocation() {
        let fragment = makeFragment(waypointCount: 3)
        XCTAssertNotNil(fragment.startLocation)
        XCTAssertEqual(fragment.startLocation?.latitude, 37.7749)
    }

    func testEndLocation() {
        let fragment = makeFragment(waypointCount: 3)
        XCTAssertNotNil(fragment.endLocation)
        // Last waypoint should have latitude 37.7749 + 0.002 = 37.7769
        XCTAssertEqual(fragment.endLocation!.latitude, 37.7769, accuracy: 0.0001)
    }

    func testStartLocationEmpty() {
        let fragment = LogFragment(
            id: "empty",
            tripId: UUID(),
            timestamp: Date(),
            waypoints: [],
            logLink: "https://test.com"
        )
        XCTAssertNil(fragment.startLocation)
    }

    func testEndLocationEmpty() {
        let fragment = LogFragment(
            id: "empty",
            tripId: UUID(),
            timestamp: Date(),
            waypoints: [],
            logLink: "https://test.com"
        )
        XCTAssertNil(fragment.endLocation)
    }

    // MARK: - Validation Tests

    func testHasMinimumWaypoints() {
        let validFragment = makeFragment(waypointCount: 2)
        XCTAssertTrue(validFragment.hasMinimumWaypoints)

        let largeFragment = makeFragment(waypointCount: 100)
        XCTAssertTrue(largeFragment.hasMinimumWaypoints)
    }

    func testHasMinimumWaypointsFails() {
        let zeroFragment = makeFragment(waypointCount: 0)
        XCTAssertFalse(zeroFragment.hasMinimumWaypoints)

        let oneFragment = makeFragment(waypointCount: 1)
        XCTAssertFalse(oneFragment.hasMinimumWaypoints)
    }

    func testIsValid() {
        let validFragment = makeFragment(id: "valid123", waypointCount: 3)
        XCTAssertTrue(validFragment.isValid)
    }

    func testIsValidWithEmptyId() {
        let fragment = LogFragment(
            id: "",
            tripId: UUID(),
            timestamp: Date(),
            waypoints: [makeWaypoint(), makeWaypoint()],
            logLink: "https://test.com"
        )
        XCTAssertFalse(fragment.isValid)
    }

    func testIsValidWithTooFewWaypoints() {
        let fragment = makeFragment(waypointCount: 1)
        XCTAssertFalse(fragment.isValid)
    }

    func testValidationErrors() {
        let invalidFragment = LogFragment(
            id: "",
            tripId: UUID(),
            timestamp: Date(),
            waypoints: [makeWaypoint()],
            logLink: ""
        )

        let errors = invalidFragment.validationErrors
        XCTAssertTrue(errors.contains { $0.contains("ID is empty") })
        XCTAssertTrue(errors.contains { $0.contains("fewer than") })
        XCTAssertTrue(errors.contains { $0.contains("Log link is empty") })
    }

    func testValidationErrorsEmpty() {
        let validFragment = makeFragment()
        XCTAssertTrue(validFragment.validationErrors.isEmpty)
    }

    // MARK: - Comparable Tests

    func testFragmentComparison() {
        let earlier = Date(timeIntervalSince1970: 1000)
        let later = Date(timeIntervalSince1970: 2000)

        let fragment1 = makeFragment(timestamp: earlier)
        let fragment2 = makeFragment(timestamp: later)

        XCTAssertTrue(fragment1 < fragment2)
        XCTAssertFalse(fragment2 < fragment1)
    }

    func testFragmentSorting() {
        let t1 = Date(timeIntervalSince1970: 3000)
        let t2 = Date(timeIntervalSince1970: 1000)
        let t3 = Date(timeIntervalSince1970: 2000)

        let fragments = [
            makeFragment(id: "f1", timestamp: t1),
            makeFragment(id: "f2", timestamp: t2),
            makeFragment(id: "f3", timestamp: t3)
        ]

        let sorted = fragments.sorted()

        XCTAssertEqual(sorted[0].id, "f2") // t2 = 1000
        XCTAssertEqual(sorted[1].id, "f3") // t3 = 2000
        XCTAssertEqual(sorted[2].id, "f1") // t1 = 3000
    }

    // MARK: - Equatable Tests

    func testFragmentEquality() {
        let tripId = UUID()
        let timestamp = Date()
        let waypoints = [makeWaypoint(), makeWaypoint()]

        let fragment1 = LogFragment(
            id: "log123",
            tripId: tripId,
            timestamp: timestamp,
            waypoints: waypoints,
            logLink: "https://test.com"
        )

        let fragment2 = LogFragment(
            id: "log123",
            tripId: tripId,
            timestamp: timestamp,
            waypoints: waypoints,
            logLink: "https://test.com"
        )

        XCTAssertEqual(fragment1, fragment2)
    }

    func testFragmentInequality() {
        let fragment1 = makeFragment(id: "log1")
        let fragment2 = makeFragment(id: "log2")

        XCTAssertNotEqual(fragment1, fragment2)
    }

    // MARK: - Codable Tests

    func testFragmentEncoding() throws {
        let fragment = makeFragment()

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(fragment)

        XCTAssertFalse(data.isEmpty)
    }

    func testFragmentDecoding() throws {
        let tripId = UUID()
        let json = """
        {
            "id": "log123",
            "tripId": "\(tripId.uuidString)",
            "timestamp": "2025-01-15T10:30:00Z",
            "waypoints": [
                {"latitude": 37.7749, "longitude": -122.4194},
                {"latitude": 37.7750, "longitude": -122.4195}
            ],
            "logLink": "https://app.datadoghq.com/logs"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let fragment = try decoder.decode(LogFragment.self, from: json)

        XCTAssertEqual(fragment.id, "log123")
        XCTAssertEqual(fragment.tripId, tripId)
        XCTAssertEqual(fragment.waypoints.count, 2)
    }

    // MARK: - Description Tests

    func testDescription() {
        let fragment = makeFragment(id: "log12345678")
        let description = fragment.description

        XCTAssertTrue(description.contains("LogFragment"))
        XCTAssertTrue(description.contains("log12345"))
    }
}
