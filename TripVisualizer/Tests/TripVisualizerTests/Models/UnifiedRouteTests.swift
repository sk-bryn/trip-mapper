import XCTest
@testable import TripVisualizer

final class UnifiedRouteTests: XCTestCase {

    // MARK: - Test Helpers

    private func makeWaypoint(lat: Double = 37.7749, lon: Double = -122.4194, fragmentId: String? = nil) -> Waypoint {
        Waypoint(latitude: lat, longitude: lon, orderId: nil, fragmentId: fragmentId)
    }

    private func makeWaypoints(count: Int, startLat: Double = 37.7749, fragmentId: String? = nil) -> [Waypoint] {
        (0..<count).map { index in
            makeWaypoint(lat: startLat + Double(index) * 0.001, lon: -122.4194, fragmentId: fragmentId)
        }
    }

    private func makeContinuousSegment(waypointCount: Int, fragmentId: String? = nil) -> RouteSegment {
        RouteSegment(
            waypoints: makeWaypoints(count: waypointCount, fragmentId: fragmentId),
            type: .continuous,
            sourceFragmentId: fragmentId
        )
    }

    private func makeGapSegment() -> RouteSegment {
        RouteSegment(
            waypoints: [
                makeWaypoint(lat: 37.780, lon: -122.420),
                makeWaypoint(lat: 37.785, lon: -122.425)
            ],
            type: .gap,
            sourceFragmentId: nil
        )
    }

    // MARK: - Initialization Tests

    func testUnifiedRouteCreation() {
        let tripId = UUID()
        let waypoints = makeWaypoints(count: 10)
        let segment = makeContinuousSegment(waypointCount: 10)

        let route = UnifiedRoute(
            tripId: tripId,
            waypoints: waypoints,
            segments: [segment],
            fragmentCount: 1,
            isComplete: true
        )

        XCTAssertEqual(route.tripId, tripId)
        XCTAssertEqual(route.waypoints.count, 10)
        XCTAssertEqual(route.segments.count, 1)
        XCTAssertEqual(route.fragmentCount, 1)
        XCTAssertTrue(route.isComplete)
    }

    func testUnifiedRouteWithMultipleSegments() {
        let tripId = UUID()
        let segments = [
            makeContinuousSegment(waypointCount: 5, fragmentId: "frag1"),
            makeGapSegment(),
            makeContinuousSegment(waypointCount: 5, fragmentId: "frag2")
        ]

        let allWaypoints = segments.flatMap { $0.waypoints }

        let route = UnifiedRoute(
            tripId: tripId,
            waypoints: allWaypoints,
            segments: segments,
            fragmentCount: 2,
            isComplete: true
        )

        XCTAssertEqual(route.segments.count, 3)
        XCTAssertEqual(route.fragmentCount, 2)
    }

    // MARK: - Computed Property Tests

    func testTotalWaypointCount() {
        let route = UnifiedRoute(
            tripId: UUID(),
            waypoints: makeWaypoints(count: 15),
            segments: [makeContinuousSegment(waypointCount: 15)],
            fragmentCount: 1,
            isComplete: true
        )

        XCTAssertEqual(route.totalWaypointCount, 15)
    }

    func testHasGapsTrue() {
        let segments = [
            makeContinuousSegment(waypointCount: 5),
            makeGapSegment(),
            makeContinuousSegment(waypointCount: 5)
        ]

        let route = UnifiedRoute(
            tripId: UUID(),
            waypoints: segments.flatMap { $0.waypoints },
            segments: segments,
            fragmentCount: 2,
            isComplete: true
        )

        XCTAssertTrue(route.hasGaps)
    }

    func testHasGapsFalse() {
        let route = UnifiedRoute(
            tripId: UUID(),
            waypoints: makeWaypoints(count: 10),
            segments: [makeContinuousSegment(waypointCount: 10)],
            fragmentCount: 1,
            isComplete: true
        )

        XCTAssertFalse(route.hasGaps)
    }

    func testContinuousSegments() {
        let segments = [
            makeContinuousSegment(waypointCount: 5, fragmentId: "f1"),
            makeGapSegment(),
            makeContinuousSegment(waypointCount: 5, fragmentId: "f2"),
            makeGapSegment(),
            makeContinuousSegment(waypointCount: 5, fragmentId: "f3")
        ]

        let route = UnifiedRoute(
            tripId: UUID(),
            waypoints: segments.flatMap { $0.waypoints },
            segments: segments,
            fragmentCount: 3,
            isComplete: true
        )

        XCTAssertEqual(route.continuousSegments.count, 3)
        XCTAssertTrue(route.continuousSegments.allSatisfy { $0.isContinuous })
    }

    func testGapSegments() {
        let segments = [
            makeContinuousSegment(waypointCount: 5),
            makeGapSegment(),
            makeContinuousSegment(waypointCount: 5),
            makeGapSegment(),
            makeContinuousSegment(waypointCount: 5)
        ]

        let route = UnifiedRoute(
            tripId: UUID(),
            waypoints: segments.flatMap { $0.waypoints },
            segments: segments,
            fragmentCount: 3,
            isComplete: true
        )

        XCTAssertEqual(route.gapSegments.count, 2)
        XCTAssertTrue(route.gapSegments.allSatisfy { $0.isGap })
    }

    func testContinuousSegmentCount() {
        let segments = [
            makeContinuousSegment(waypointCount: 5),
            makeGapSegment(),
            makeContinuousSegment(waypointCount: 5)
        ]

        let route = UnifiedRoute(
            tripId: UUID(),
            waypoints: segments.flatMap { $0.waypoints },
            segments: segments,
            fragmentCount: 2,
            isComplete: true
        )

        XCTAssertEqual(route.continuousSegmentCount, 2)
    }

    func testGapCount() {
        let segments = [
            makeContinuousSegment(waypointCount: 5),
            makeGapSegment(),
            makeContinuousSegment(waypointCount: 5),
            makeGapSegment(),
            makeContinuousSegment(waypointCount: 5)
        ]

        let route = UnifiedRoute(
            tripId: UUID(),
            waypoints: segments.flatMap { $0.waypoints },
            segments: segments,
            fragmentCount: 3,
            isComplete: true
        )

        XCTAssertEqual(route.gapCount, 2)
    }

    func testStartWaypoint() {
        let waypoints = makeWaypoints(count: 10)
        let route = UnifiedRoute(
            tripId: UUID(),
            waypoints: waypoints,
            segments: [makeContinuousSegment(waypointCount: 10)],
            fragmentCount: 1,
            isComplete: true
        )

        XCTAssertEqual(route.startWaypoint?.latitude, 37.7749)
    }

    func testEndWaypoint() {
        let waypoints = makeWaypoints(count: 10)
        let route = UnifiedRoute(
            tripId: UUID(),
            waypoints: waypoints,
            segments: [makeContinuousSegment(waypointCount: 10)],
            fragmentCount: 1,
            isComplete: true
        )

        XCTAssertNotNil(route.endWaypoint)
        // Last waypoint: 37.7749 + 0.009 = 37.7839
        XCTAssertEqual(route.endWaypoint!.latitude, 37.7839, accuracy: 0.0001)
    }

    func testHasMinimumWaypoints() {
        let routeWith2 = UnifiedRoute(
            tripId: UUID(),
            waypoints: makeWaypoints(count: 2),
            segments: [makeContinuousSegment(waypointCount: 2)],
            fragmentCount: 1,
            isComplete: true
        )
        XCTAssertTrue(routeWith2.hasMinimumWaypoints)

        let routeWith1 = UnifiedRoute(
            tripId: UUID(),
            waypoints: makeWaypoints(count: 1),
            segments: [],
            fragmentCount: 1,
            isComplete: false
        )
        XCTAssertFalse(routeWith1.hasMinimumWaypoints)
    }

    // MARK: - Factory Method Tests

    func testFromSingleFragment() {
        let tripId = UUID()
        let waypoints = makeWaypoints(count: 5)
        let fragment = LogFragment(
            id: "log123",
            tripId: tripId,
            timestamp: Date(),
            waypoints: waypoints,
            logLink: "https://test.com"
        )

        let route = UnifiedRoute.fromSingleFragment(fragment)

        XCTAssertEqual(route.tripId, tripId)
        XCTAssertEqual(route.waypoints.count, 5)
        XCTAssertEqual(route.segments.count, 1)
        XCTAssertEqual(route.segments[0].type, .continuous)
        XCTAssertEqual(route.segments[0].sourceFragmentId, "log123")
        XCTAssertEqual(route.fragmentCount, 1)
        XCTAssertTrue(route.isComplete)
        XCTAssertFalse(route.hasGaps)
    }

    func testFromWaypoints() {
        let tripId = UUID()
        let waypoints = makeWaypoints(count: 8)

        let route = UnifiedRoute.fromWaypoints(waypoints, tripId: tripId)

        XCTAssertEqual(route.tripId, tripId)
        XCTAssertEqual(route.waypoints.count, 8)
        XCTAssertEqual(route.segments.count, 1)
        XCTAssertEqual(route.segments[0].type, .continuous)
        XCTAssertNil(route.segments[0].sourceFragmentId)
        XCTAssertEqual(route.fragmentCount, 1)
        XCTAssertTrue(route.isComplete)
    }

    // MARK: - Equatable Tests

    func testRouteEquality() {
        let tripId = UUID()
        let waypoints = makeWaypoints(count: 5)
        let segment = RouteSegment(waypoints: waypoints, type: .continuous)

        let route1 = UnifiedRoute(
            tripId: tripId,
            waypoints: waypoints,
            segments: [segment],
            fragmentCount: 1,
            isComplete: true
        )

        let route2 = UnifiedRoute(
            tripId: tripId,
            waypoints: waypoints,
            segments: [segment],
            fragmentCount: 1,
            isComplete: true
        )

        XCTAssertEqual(route1, route2)
    }

    func testRouteInequalityTripId() {
        let waypoints = makeWaypoints(count: 5)
        let segment = RouteSegment(waypoints: waypoints, type: .continuous)

        let route1 = UnifiedRoute(
            tripId: UUID(),
            waypoints: waypoints,
            segments: [segment],
            fragmentCount: 1,
            isComplete: true
        )

        let route2 = UnifiedRoute(
            tripId: UUID(),
            waypoints: waypoints,
            segments: [segment],
            fragmentCount: 1,
            isComplete: true
        )

        XCTAssertNotEqual(route1, route2)
    }

    // MARK: - Codable Tests

    func testRouteEncoding() throws {
        let route = UnifiedRoute(
            tripId: UUID(),
            waypoints: makeWaypoints(count: 3),
            segments: [makeContinuousSegment(waypointCount: 3)],
            fragmentCount: 1,
            isComplete: true
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(route)

        XCTAssertFalse(data.isEmpty)
    }

    func testRouteDecoding() throws {
        let tripId = UUID()
        let json = """
        {
            "tripId": "\(tripId.uuidString)",
            "waypoints": [
                {"latitude": 37.7749, "longitude": -122.4194},
                {"latitude": 37.7750, "longitude": -122.4195}
            ],
            "segments": [
                {
                    "waypoints": [
                        {"latitude": 37.7749, "longitude": -122.4194},
                        {"latitude": 37.7750, "longitude": -122.4195}
                    ],
                    "type": "continuous"
                }
            ],
            "fragmentCount": 1,
            "isComplete": true
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let route = try decoder.decode(UnifiedRoute.self, from: json)

        XCTAssertEqual(route.tripId, tripId)
        XCTAssertEqual(route.waypoints.count, 2)
        XCTAssertEqual(route.segments.count, 1)
    }

    // MARK: - Description Tests

    func testDescriptionBasic() {
        let route = UnifiedRoute(
            tripId: UUID(),
            waypoints: makeWaypoints(count: 10),
            segments: [makeContinuousSegment(waypointCount: 10)],
            fragmentCount: 1,
            isComplete: true
        )

        let description = route.description
        XCTAssertTrue(description.contains("UnifiedRoute"))
        XCTAssertTrue(description.contains("10 waypoints"))
        XCTAssertTrue(description.contains("1 fragments"))
    }

    func testDescriptionWithGaps() {
        let segments = [
            makeContinuousSegment(waypointCount: 5),
            makeGapSegment(),
            makeContinuousSegment(waypointCount: 5)
        ]

        let route = UnifiedRoute(
            tripId: UUID(),
            waypoints: segments.flatMap { $0.waypoints },
            segments: segments,
            fragmentCount: 2,
            isComplete: true
        )

        let description = route.description
        XCTAssertTrue(description.contains("1 gaps"))
    }

    func testDescriptionIncomplete() {
        let route = UnifiedRoute(
            tripId: UUID(),
            waypoints: makeWaypoints(count: 5),
            segments: [makeContinuousSegment(waypointCount: 5)],
            fragmentCount: 1,
            isComplete: false
        )

        let description = route.description
        XCTAssertTrue(description.contains("incomplete"))
    }
}
