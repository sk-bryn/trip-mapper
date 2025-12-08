import XCTest
@testable import TripVisualizer

final class FragmentAggregatorTests: XCTestCase {

    // MARK: - Properties

    private var aggregator: FragmentAggregator!
    private let tripId = UUID()

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        aggregator = FragmentAggregator()
    }

    override func tearDown() {
        aggregator = nil
        super.tearDown()
    }

    // MARK: - Test Helpers

    private func makeWaypoint(lat: Double = 37.7749, lon: Double = -122.4194) -> Waypoint {
        Waypoint(latitude: lat, longitude: lon, orderId: nil, fragmentId: nil)
    }

    private func makeWaypoints(count: Int, startLat: Double = 37.7749) -> [Waypoint] {
        (0..<count).map { index in
            makeWaypoint(lat: startLat + Double(index) * 0.001, lon: -122.4194)
        }
    }

    private func makeFragment(
        id: String,
        tripId: UUID? = nil,
        timestamp: Date,
        waypointCount: Int = 3,
        startLat: Double = 37.7749
    ) -> LogFragment {
        LogFragment(
            id: id,
            tripId: tripId ?? self.tripId,
            timestamp: timestamp,
            waypoints: makeWaypoints(count: waypointCount, startLat: startLat),
            logLink: "https://app.datadoghq.com/logs?query=\(id)"
        )
    }

    // MARK: - Empty Input Tests

    func testAggregateEmptyFragmentsThrows() {
        XCTAssertThrowsError(try aggregator.aggregate(fragments: [])) { error in
            guard let aggregationError = error as? AggregationError else {
                XCTFail("Expected AggregationError")
                return
            }
            XCTAssertEqual(aggregationError, .emptyFragments)
        }
    }

    // MARK: - Single Fragment Tests

    func testAggregateSingleFragment() throws {
        let fragment = makeFragment(id: "f1", timestamp: Date())

        let route = try aggregator.aggregate(fragments: [fragment])

        XCTAssertEqual(route.tripId, tripId)
        XCTAssertEqual(route.fragmentCount, 1)
        XCTAssertEqual(route.segments.count, 1)
        XCTAssertEqual(route.segments[0].type, .continuous)
        XCTAssertEqual(route.segments[0].sourceFragmentId, "f1")
        XCTAssertTrue(route.isComplete)
        XCTAssertFalse(route.hasGaps)
    }

    func testAggregateSingleFragmentInvalidThrows() {
        let invalidFragment = LogFragment(
            id: "invalid",
            tripId: tripId,
            timestamp: Date(),
            waypoints: [makeWaypoint()], // Only 1 waypoint
            logLink: "https://test.com"
        )

        XCTAssertThrowsError(try aggregator.aggregate(fragments: [invalidFragment])) { error in
            guard let aggregationError = error as? AggregationError else {
                XCTFail("Expected AggregationError")
                return
            }
            if case .invalidFragment(let id, _) = aggregationError {
                XCTAssertEqual(id, "invalid")
            } else {
                XCTFail("Expected invalidFragment error")
            }
        }
    }

    // MARK: - Multiple Fragment Tests

    func testAggregateMultipleFragmentsNoGap() throws {
        let t1 = Date(timeIntervalSince1970: 1000)
        let t2 = Date(timeIntervalSince1970: 1060) // 1 minute later (no gap)

        let fragments = [
            makeFragment(id: "f1", timestamp: t1, waypointCount: 3, startLat: 37.7749),
            makeFragment(id: "f2", timestamp: t2, waypointCount: 3, startLat: 37.7779)
        ]

        let route = try aggregator.aggregate(fragments: fragments, gapThreshold: 300)

        XCTAssertEqual(route.fragmentCount, 2)
        XCTAssertEqual(route.segments.count, 2) // No gap segment
        XCTAssertTrue(route.segments.allSatisfy { $0.type == .continuous })
        XCTAssertFalse(route.hasGaps)
    }

    func testAggregateMultipleFragmentsWithGap() throws {
        let t1 = Date(timeIntervalSince1970: 1000)
        let t2 = Date(timeIntervalSince1970: 1400) // 6+ minutes later (gap)

        let fragments = [
            makeFragment(id: "f1", timestamp: t1, waypointCount: 3, startLat: 37.7749),
            makeFragment(id: "f2", timestamp: t2, waypointCount: 3, startLat: 37.7800)
        ]

        let route = try aggregator.aggregate(fragments: fragments, gapThreshold: 300)

        XCTAssertEqual(route.fragmentCount, 2)
        XCTAssertEqual(route.segments.count, 3) // continuous, gap, continuous
        XCTAssertEqual(route.segments[0].type, .continuous)
        XCTAssertEqual(route.segments[1].type, .gap)
        XCTAssertEqual(route.segments[2].type, .continuous)
        XCTAssertTrue(route.hasGaps)
        XCTAssertEqual(route.gapCount, 1)
    }

    func testAggregateFragmentsOrderedByTimestamp() throws {
        let t1 = Date(timeIntervalSince1970: 3000) // Latest
        let t2 = Date(timeIntervalSince1970: 1000) // Earliest
        let t3 = Date(timeIntervalSince1970: 2000) // Middle

        let fragments = [
            makeFragment(id: "f1", timestamp: t1),
            makeFragment(id: "f2", timestamp: t2),
            makeFragment(id: "f3", timestamp: t3)
        ]

        let route = try aggregator.aggregate(fragments: fragments, gapThreshold: 300)

        // Segments should be in chronological order: f2, f3, f1
        let fragmentIds = route.segments
            .filter { $0.type == .continuous }
            .compactMap { $0.sourceFragmentId }

        XCTAssertEqual(fragmentIds, ["f2", "f3", "f1"])
    }

    // MARK: - Trip ID Mismatch Tests

    func testAggregateMismatchedTripIdsThrows() {
        let tripId1 = UUID()
        let tripId2 = UUID()

        let fragments = [
            makeFragment(id: "f1", tripId: tripId1, timestamp: Date()),
            makeFragment(id: "f2", tripId: tripId2, timestamp: Date())
        ]

        XCTAssertThrowsError(try aggregator.aggregate(fragments: fragments)) { error in
            guard let aggregationError = error as? AggregationError else {
                XCTFail("Expected AggregationError")
                return
            }
            if case .tripIdMismatch(let expected, let found) = aggregationError {
                XCTAssertEqual(expected, tripId1)
                XCTAssertEqual(found, tripId2)
            } else {
                XCTFail("Expected tripIdMismatch error")
            }
        }
    }

    // MARK: - Invalid Fragment Handling Tests

    func testAggregateSkipsInvalidFragments() throws {
        let t1 = Date(timeIntervalSince1970: 1000)
        let t2 = Date(timeIntervalSince1970: 1060)
        let t3 = Date(timeIntervalSince1970: 1120)

        let validFragment1 = makeFragment(id: "f1", timestamp: t1)
        let invalidFragment = LogFragment(
            id: "invalid",
            tripId: tripId,
            timestamp: t2,
            waypoints: [makeWaypoint()], // Only 1 waypoint
            logLink: "https://test.com"
        )
        let validFragment2 = makeFragment(id: "f3", timestamp: t3)

        let route = try aggregator.aggregate(
            fragments: [validFragment1, invalidFragment, validFragment2],
            gapThreshold: 300
        )

        XCTAssertEqual(route.fragmentCount, 2)
        XCTAssertFalse(route.isComplete) // Not complete because one fragment was skipped
    }

    func testAggregateAllInvalidFragmentsThrows() {
        let invalid1 = LogFragment(
            id: "i1",
            tripId: tripId,
            timestamp: Date(),
            waypoints: [makeWaypoint()],
            logLink: "https://test.com"
        )
        let invalid2 = LogFragment(
            id: "i2",
            tripId: tripId,
            timestamp: Date(),
            waypoints: [],
            logLink: "https://test.com"
        )

        XCTAssertThrowsError(try aggregator.aggregate(fragments: [invalid1, invalid2])) { error in
            guard let aggregationError = error as? AggregationError else {
                XCTFail("Expected AggregationError")
                return
            }
            XCTAssertEqual(aggregationError, .allFragmentsInvalid)
        }
    }

    // MARK: - Deduplication Tests

    func testAggregateDeduplicatesOverlappingWaypoints() throws {
        let t1 = Date(timeIntervalSince1970: 1000)
        let t2 = Date(timeIntervalSince1970: 1060)

        // Fragment 1 ends at 37.7769
        let fragment1 = LogFragment(
            id: "f1",
            tripId: tripId,
            timestamp: t1,
            waypoints: makeWaypoints(count: 3, startLat: 37.7749), // 37.7749, 37.7759, 37.7769
            logLink: "https://test.com"
        )

        // Fragment 2 starts at nearly the same location as fragment 1 ends
        let fragment2 = LogFragment(
            id: "f2",
            tripId: tripId,
            timestamp: t2,
            waypoints: [
                makeWaypoint(lat: 37.7769 + 0.000005, lon: -122.4194), // Very close to 37.7769
                makeWaypoint(lat: 37.7779, lon: -122.4194),
                makeWaypoint(lat: 37.7789, lon: -122.4194)
            ],
            logLink: "https://test.com"
        )

        let route = try aggregator.aggregate(fragments: [fragment1, fragment2], gapThreshold: 300)

        // Fragment 2's first waypoint should be deduplicated
        // Original: 3 + 3 = 6 waypoints
        // After dedup: 3 + 2 = 5 waypoints
        XCTAssertEqual(route.waypoints.count, 5)
    }

    func testAggregateNoDeduplicationForDistantWaypoints() throws {
        let t1 = Date(timeIntervalSince1970: 1000)
        let t2 = Date(timeIntervalSince1970: 1060)

        let fragment1 = makeFragment(id: "f1", timestamp: t1, waypointCount: 3, startLat: 37.7749)
        let fragment2 = makeFragment(id: "f2", timestamp: t2, waypointCount: 3, startLat: 37.8000) // Far away

        let route = try aggregator.aggregate(fragments: [fragment1, fragment2], gapThreshold: 300)

        // No deduplication should occur
        XCTAssertEqual(route.waypoints.count, 6)
    }

    // MARK: - Gap Threshold Tests

    func testAggregateCustomGapThreshold() throws {
        let t1 = Date(timeIntervalSince1970: 1000)
        let t2 = Date(timeIntervalSince1970: 1120) // 2 minutes later

        let fragments = [
            makeFragment(id: "f1", timestamp: t1),
            makeFragment(id: "f2", timestamp: t2)
        ]

        // With 60 second threshold, should have gap
        let routeWithGap = try aggregator.aggregate(fragments: fragments, gapThreshold: 60)
        XCTAssertTrue(routeWithGap.hasGaps)

        // With 180 second threshold, should not have gap
        let routeNoGap = try aggregator.aggregate(fragments: fragments, gapThreshold: 180)
        XCTAssertFalse(routeNoGap.hasGaps)
    }

    // MARK: - Fragment ID Assignment Tests

    func testAggregateAssignsFragmentIdToWaypoints() throws {
        let fragment = makeFragment(id: "test-fragment", timestamp: Date())

        let route = try aggregator.aggregate(fragments: [fragment])

        // All waypoints should have fragmentId set
        XCTAssertTrue(route.waypoints.allSatisfy { $0.fragmentId == "test-fragment" })
    }

    // MARK: - Gap Segment Tests

    func testGapSegmentHasTwoWaypoints() throws {
        let t1 = Date(timeIntervalSince1970: 1000)
        let t2 = Date(timeIntervalSince1970: 1500) // Gap

        let fragments = [
            makeFragment(id: "f1", timestamp: t1, waypointCount: 5),
            makeFragment(id: "f2", timestamp: t2, waypointCount: 5)
        ]

        let route = try aggregator.aggregate(fragments: fragments, gapThreshold: 300)

        let gapSegment = route.segments.first { $0.isGap }
        XCTAssertNotNil(gapSegment)
        XCTAssertEqual(gapSegment?.waypointCount, 2)
    }

    func testGapSegmentConnectsFragments() throws {
        let t1 = Date(timeIntervalSince1970: 1000)
        let t2 = Date(timeIntervalSince1970: 1500)

        let fragment1 = LogFragment(
            id: "f1",
            tripId: tripId,
            timestamp: t1,
            waypoints: [
                makeWaypoint(lat: 37.7749, lon: -122.4194),
                makeWaypoint(lat: 37.7759, lon: -122.4194),
                makeWaypoint(lat: 37.7769, lon: -122.4194) // End
            ],
            logLink: "https://test.com"
        )

        let fragment2 = LogFragment(
            id: "f2",
            tripId: tripId,
            timestamp: t2,
            waypoints: [
                makeWaypoint(lat: 37.7800, lon: -122.4194), // Start
                makeWaypoint(lat: 37.7810, lon: -122.4194),
                makeWaypoint(lat: 37.7820, lon: -122.4194)
            ],
            logLink: "https://test.com"
        )

        let route = try aggregator.aggregate(fragments: [fragment1, fragment2], gapThreshold: 300)

        let gapSegment = route.segments.first { $0.isGap }!

        // Gap should connect last waypoint of f1 to first waypoint of f2
        XCTAssertNotNil(gapSegment.startWaypoint)
        XCTAssertNotNil(gapSegment.endWaypoint)
        XCTAssertEqual(gapSegment.startWaypoint!.latitude, 37.7769, accuracy: 0.0001)
        XCTAssertEqual(gapSegment.endWaypoint!.latitude, 37.7800, accuracy: 0.0001)
    }

    // MARK: - Many Fragments Tests

    func testAggregateManyFragments() throws {
        var fragments: [LogFragment] = []

        for i in 0..<20 {
            let timestamp = Date(timeIntervalSince1970: Double(i * 60))
            let fragment = makeFragment(
                id: "f\(i)",
                timestamp: timestamp,
                waypointCount: 3,
                startLat: 37.7749 + Double(i) * 0.01
            )
            fragments.append(fragment)
        }

        let route = try aggregator.aggregate(fragments: fragments, gapThreshold: 300)

        XCTAssertEqual(route.fragmentCount, 20)
        XCTAssertTrue(route.isComplete)
    }

    // MARK: - Multiple Gaps Tests

    func testAggregateMultipleGaps() throws {
        let fragments = [
            makeFragment(id: "f1", timestamp: Date(timeIntervalSince1970: 0), startLat: 37.77),
            makeFragment(id: "f2", timestamp: Date(timeIntervalSince1970: 400), startLat: 37.78),
            makeFragment(id: "f3", timestamp: Date(timeIntervalSince1970: 800), startLat: 37.79),
            makeFragment(id: "f4", timestamp: Date(timeIntervalSince1970: 1200), startLat: 37.80)
        ]

        let route = try aggregator.aggregate(fragments: fragments, gapThreshold: 300)

        XCTAssertEqual(route.fragmentCount, 4)
        XCTAssertEqual(route.gapCount, 3) // Gap between each consecutive pair
        XCTAssertEqual(route.continuousSegmentCount, 4)
        XCTAssertEqual(route.segments.count, 7) // 4 continuous + 3 gaps
    }
}
