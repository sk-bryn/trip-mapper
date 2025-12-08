import XCTest
@testable import TripVisualizer

final class RouteSegmentTests: XCTestCase {

    // MARK: - Test Helpers

    private func makeWaypoint(lat: Double = 37.7749, lon: Double = -122.4194) -> Waypoint {
        Waypoint(latitude: lat, longitude: lon, orderId: nil, fragmentId: nil)
    }

    private func makeWaypoints(count: Int) -> [Waypoint] {
        (0..<count).map { index in
            makeWaypoint(lat: 37.7749 + Double(index) * 0.001, lon: -122.4194)
        }
    }

    // MARK: - SegmentType Tests

    func testSegmentTypeRawValues() {
        XCTAssertEqual(SegmentType.continuous.rawValue, "continuous")
        XCTAssertEqual(SegmentType.gap.rawValue, "gap")
    }

    func testSegmentTypeCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // Encode and decode continuous
        let continuousData = try encoder.encode(SegmentType.continuous)
        let decodedContinuous = try decoder.decode(SegmentType.self, from: continuousData)
        XCTAssertEqual(decodedContinuous, .continuous)

        // Encode and decode gap
        let gapData = try encoder.encode(SegmentType.gap)
        let decodedGap = try decoder.decode(SegmentType.self, from: gapData)
        XCTAssertEqual(decodedGap, .gap)
    }

    // MARK: - RouteSegment Initialization Tests

    func testContinuousSegmentCreation() {
        let waypoints = makeWaypoints(count: 5)

        let segment = RouteSegment(
            waypoints: waypoints,
            type: .continuous,
            sourceFragmentId: "log123"
        )

        XCTAssertEqual(segment.waypoints.count, 5)
        XCTAssertEqual(segment.type, .continuous)
        XCTAssertEqual(segment.sourceFragmentId, "log123")
    }

    func testGapSegmentCreation() {
        let waypoints = makeWaypoints(count: 2)

        let segment = RouteSegment(
            waypoints: waypoints,
            type: .gap,
            sourceFragmentId: nil
        )

        XCTAssertEqual(segment.waypoints.count, 2)
        XCTAssertEqual(segment.type, .gap)
        XCTAssertNil(segment.sourceFragmentId)
    }

    func testDefaultSourceFragmentId() {
        let segment = RouteSegment(
            waypoints: makeWaypoints(count: 3),
            type: .continuous
        )

        XCTAssertNil(segment.sourceFragmentId)
    }

    // MARK: - Computed Property Tests

    func testWaypointCount() {
        let segment = RouteSegment(
            waypoints: makeWaypoints(count: 10),
            type: .continuous
        )

        XCTAssertEqual(segment.waypointCount, 10)
    }

    func testWaypointCountEmpty() {
        let segment = RouteSegment(
            waypoints: [],
            type: .continuous
        )

        XCTAssertEqual(segment.waypointCount, 0)
    }

    func testStartWaypoint() {
        let waypoints = makeWaypoints(count: 5)
        let segment = RouteSegment(waypoints: waypoints, type: .continuous)

        XCTAssertEqual(segment.startWaypoint?.latitude, 37.7749)
    }

    func testStartWaypointEmpty() {
        let segment = RouteSegment(waypoints: [], type: .continuous)

        XCTAssertNil(segment.startWaypoint)
    }

    func testEndWaypoint() {
        let waypoints = makeWaypoints(count: 5)
        let segment = RouteSegment(waypoints: waypoints, type: .continuous)

        XCTAssertNotNil(segment.endWaypoint)
        // Last waypoint: 37.7749 + 0.004 = 37.7789
        XCTAssertEqual(segment.endWaypoint!.latitude, 37.7789, accuracy: 0.0001)
    }

    func testEndWaypointEmpty() {
        let segment = RouteSegment(waypoints: [], type: .continuous)

        XCTAssertNil(segment.endWaypoint)
    }

    func testIsContinuous() {
        let continuousSegment = RouteSegment(
            waypoints: makeWaypoints(count: 3),
            type: .continuous
        )
        let gapSegment = RouteSegment(
            waypoints: makeWaypoints(count: 2),
            type: .gap
        )

        XCTAssertTrue(continuousSegment.isContinuous)
        XCTAssertFalse(gapSegment.isContinuous)
    }

    func testIsGap() {
        let continuousSegment = RouteSegment(
            waypoints: makeWaypoints(count: 3),
            type: .continuous
        )
        let gapSegment = RouteSegment(
            waypoints: makeWaypoints(count: 2),
            type: .gap
        )

        XCTAssertFalse(continuousSegment.isGap)
        XCTAssertTrue(gapSegment.isGap)
    }

    // MARK: - Equatable Tests

    func testSegmentEquality() {
        let waypoints = makeWaypoints(count: 3)

        let segment1 = RouteSegment(
            waypoints: waypoints,
            type: .continuous,
            sourceFragmentId: "log123"
        )

        let segment2 = RouteSegment(
            waypoints: waypoints,
            type: .continuous,
            sourceFragmentId: "log123"
        )

        XCTAssertEqual(segment1, segment2)
    }

    func testSegmentInequalityType() {
        let waypoints = makeWaypoints(count: 3)

        let segment1 = RouteSegment(waypoints: waypoints, type: .continuous)
        let segment2 = RouteSegment(waypoints: waypoints, type: .gap)

        XCTAssertNotEqual(segment1, segment2)
    }

    func testSegmentInequalityWaypoints() {
        let segment1 = RouteSegment(
            waypoints: makeWaypoints(count: 3),
            type: .continuous
        )
        let segment2 = RouteSegment(
            waypoints: makeWaypoints(count: 4),
            type: .continuous
        )

        XCTAssertNotEqual(segment1, segment2)
    }

    func testSegmentInequalityFragmentId() {
        let waypoints = makeWaypoints(count: 3)

        let segment1 = RouteSegment(
            waypoints: waypoints,
            type: .continuous,
            sourceFragmentId: "log1"
        )
        let segment2 = RouteSegment(
            waypoints: waypoints,
            type: .continuous,
            sourceFragmentId: "log2"
        )

        XCTAssertNotEqual(segment1, segment2)
    }

    // MARK: - Codable Tests

    func testSegmentEncoding() throws {
        let segment = RouteSegment(
            waypoints: makeWaypoints(count: 3),
            type: .continuous,
            sourceFragmentId: "log123"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(segment)

        XCTAssertFalse(data.isEmpty)
    }

    func testSegmentDecoding() throws {
        let json = """
        {
            "waypoints": [
                {"latitude": 37.7749, "longitude": -122.4194},
                {"latitude": 37.7750, "longitude": -122.4195}
            ],
            "type": "continuous",
            "sourceFragmentId": "log123"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let segment = try decoder.decode(RouteSegment.self, from: json)

        XCTAssertEqual(segment.waypoints.count, 2)
        XCTAssertEqual(segment.type, .continuous)
        XCTAssertEqual(segment.sourceFragmentId, "log123")
    }

    func testGapSegmentDecoding() throws {
        let json = """
        {
            "waypoints": [
                {"latitude": 37.7749, "longitude": -122.4194},
                {"latitude": 37.7760, "longitude": -122.4200}
            ],
            "type": "gap",
            "sourceFragmentId": null
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let segment = try decoder.decode(RouteSegment.self, from: json)

        XCTAssertEqual(segment.type, .gap)
        XCTAssertNil(segment.sourceFragmentId)
    }

    // MARK: - Description Tests

    func testContinuousDescription() {
        let segment = RouteSegment(
            waypoints: makeWaypoints(count: 5),
            type: .continuous,
            sourceFragmentId: "log12345678"
        )

        let description = segment.description
        XCTAssertTrue(description.contains("RouteSegment"))
        XCTAssertTrue(description.contains("continuous"))
        XCTAssertTrue(description.contains("5 waypoints"))
        XCTAssertTrue(description.contains("log12345"))
    }

    func testGapDescription() {
        let segment = RouteSegment(
            waypoints: makeWaypoints(count: 2),
            type: .gap
        )

        let description = segment.description
        XCTAssertTrue(description.contains("gap"))
        XCTAssertTrue(description.contains("2 waypoints"))
    }
}
