import XCTest
@testable import TripVisualizer

/// Tests for LogParser service
/// Validates coordinate extraction from DataDog log entries
final class LogParserTests: XCTestCase {

    // MARK: - Basic Coordinate Extraction Tests

    func testExtractWaypointsFromValidSegmentCoords() throws {
        // Given
        let parser = LogParser()
        let segmentCoords: [[String: Any]] = [
            ["lat": 37.7749, "lng": -122.4194],
            ["lat": 37.7750, "lng": -122.4195],
            ["lat": 37.7751, "lng": -122.4196]
        ]

        // When
        let waypoints = try parser.extractWaypoints(from: segmentCoords)

        // Then
        XCTAssertEqual(waypoints.count, 3)
        XCTAssertEqual(waypoints[0].latitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(waypoints[0].longitude, -122.4194, accuracy: 0.0001)
        XCTAssertEqual(waypoints[2].latitude, 37.7751, accuracy: 0.0001)
    }

    func testExtractWaypointsWithOrderId() throws {
        // Given
        let parser = LogParser()
        let orderId = UUID()
        let segmentCoords: [[String: Any]] = [
            ["lat": 37.7749, "lng": -122.4194, "order_id": orderId.uuidString],
            ["lat": 37.7750, "lng": -122.4195]
        ]

        // When
        let waypoints = try parser.extractWaypoints(from: segmentCoords)

        // Then
        XCTAssertEqual(waypoints.count, 2)
        XCTAssertEqual(waypoints[0].orderId, orderId)
        XCTAssertNil(waypoints[1].orderId)
    }

    func testExtractWaypointsFromEmptyArray() throws {
        // Given
        let parser = LogParser()
        let segmentCoords: [[String: Any]] = []

        // When/Then
        XCTAssertThrowsError(try parser.extractWaypoints(from: segmentCoords)) { error in
            guard let vizError = error as? TripVisualizerError else {
                XCTFail("Expected TripVisualizerError")
                return
            }
            if case .noRouteData = vizError {
                // Expected
            } else {
                XCTFail("Expected noRouteData error, got \(vizError)")
            }
        }
    }

    func testExtractWaypointsWithSingleCoordinate() throws {
        // Given
        let parser = LogParser()
        let segmentCoords: [[String: Any]] = [
            ["lat": 37.7749, "lng": -122.4194]
        ]

        // When/Then
        XCTAssertThrowsError(try parser.extractWaypoints(from: segmentCoords)) { error in
            guard let vizError = error as? TripVisualizerError else {
                XCTFail("Expected TripVisualizerError")
                return
            }
            if case .insufficientWaypoints(let count) = vizError {
                XCTAssertEqual(count, 1)
            } else {
                XCTFail("Expected insufficientWaypoints error")
            }
        }
    }

    // MARK: - Invalid Coordinate Handling Tests

    func testSkipsInvalidLatitude() throws {
        // Given
        let parser = LogParser()
        let segmentCoords: [[String: Any]] = [
            ["lat": 37.7749, "lng": -122.4194],
            ["lat": 91.0, "lng": -122.4195], // Invalid latitude > 90
            ["lat": 37.7751, "lng": -122.4196]
        ]

        // When
        let waypoints = try parser.extractWaypoints(from: segmentCoords)

        // Then - invalid coordinate should be skipped
        XCTAssertEqual(waypoints.count, 2)
        XCTAssertEqual(waypoints[0].latitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(waypoints[1].latitude, 37.7751, accuracy: 0.0001)
    }

    func testSkipsInvalidLongitude() throws {
        // Given
        let parser = LogParser()
        let segmentCoords: [[String: Any]] = [
            ["lat": 37.7749, "lng": -122.4194],
            ["lat": 37.7750, "lng": -181.0], // Invalid longitude < -180
            ["lat": 37.7751, "lng": -122.4196]
        ]

        // When
        let waypoints = try parser.extractWaypoints(from: segmentCoords)

        // Then - invalid coordinate should be skipped
        XCTAssertEqual(waypoints.count, 2)
    }

    func testSkipsMissingLatitude() throws {
        // Given
        let parser = LogParser()
        let segmentCoords: [[String: Any]] = [
            ["lat": 37.7749, "lng": -122.4194],
            ["lng": -122.4195], // Missing latitude
            ["lat": 37.7751, "lng": -122.4196]
        ]

        // When
        let waypoints = try parser.extractWaypoints(from: segmentCoords)

        // Then
        XCTAssertEqual(waypoints.count, 2)
    }

    func testSkipsMissingLongitude() throws {
        // Given
        let parser = LogParser()
        let segmentCoords: [[String: Any]] = [
            ["lat": 37.7749, "lng": -122.4194],
            ["lat": 37.7750], // Missing longitude
            ["lat": 37.7751, "lng": -122.4196]
        ]

        // When
        let waypoints = try parser.extractWaypoints(from: segmentCoords)

        // Then
        XCTAssertEqual(waypoints.count, 2)
    }

    func testHandlesStringCoordinates() throws {
        // Given
        let parser = LogParser()
        let segmentCoords: [[String: Any]] = [
            ["lat": "37.7749", "lng": "-122.4194"],
            ["lat": "37.7750", "lng": "-122.4195"]
        ]

        // When
        let waypoints = try parser.extractWaypoints(from: segmentCoords)

        // Then
        XCTAssertEqual(waypoints.count, 2)
        XCTAssertEqual(waypoints[0].latitude, 37.7749, accuracy: 0.0001)
    }

    // MARK: - DataDog Log Entry Parsing Tests

    func testParseLogEntryWithSegmentCoords() throws {
        // Given
        let parser = LogParser()
        let logEntry = DataDogLogEntry(
            id: "log-123",
            attributes: DataDogLogAttributes(
                timestamp: "2024-01-15T10:30:00.000Z",
                message: "received request for SaveActualRouteForTrip",
                attributes: [
                    "segment_coords": [
                        ["lat": 37.7749, "lng": -122.4194],
                        ["lat": 37.7750, "lng": -122.4195]
                    ]
                ]
            )
        )

        // When
        let waypoints = try parser.parseLogEntry(logEntry)

        // Then
        XCTAssertEqual(waypoints.count, 2)
    }

    func testParseLogEntryWithMissingSegmentCoords() throws {
        // Given
        let parser = LogParser()
        let logEntry = DataDogLogEntry(
            id: "log-123",
            attributes: DataDogLogAttributes(
                timestamp: "2024-01-15T10:30:00.000Z",
                message: "received request for SaveActualRouteForTrip",
                attributes: [:]
            )
        )

        // When/Then
        XCTAssertThrowsError(try parser.parseLogEntry(logEntry)) { error in
            guard let vizError = error as? TripVisualizerError else {
                XCTFail("Expected TripVisualizerError")
                return
            }
            if case .noRouteData = vizError {
                // Expected
            } else {
                XCTFail("Expected noRouteData error")
            }
        }
    }

    func testParseLogEntryWithEmptySegmentCoords() throws {
        // Given
        let parser = LogParser()
        let logEntry = DataDogLogEntry(
            id: "log-123",
            attributes: DataDogLogAttributes(
                timestamp: "2024-01-15T10:30:00.000Z",
                message: "received request for SaveActualRouteForTrip",
                attributes: ["segment_coords": []]
            )
        )

        // When/Then
        XCTAssertThrowsError(try parser.parseLogEntry(logEntry)) { error in
            guard let vizError = error as? TripVisualizerError else {
                XCTFail("Expected TripVisualizerError")
                return
            }
            if case .noRouteData = vizError {
                // Expected
            } else {
                XCTFail("Expected noRouteData error")
            }
        }
    }

    // MARK: - Boundary Coordinate Tests

    func testAcceptsBoundaryLatitudes() throws {
        // Given
        let parser = LogParser()
        let segmentCoords: [[String: Any]] = [
            ["lat": 90.0, "lng": 0.0],  // North pole
            ["lat": -90.0, "lng": 0.0]  // South pole
        ]

        // When
        let waypoints = try parser.extractWaypoints(from: segmentCoords)

        // Then
        XCTAssertEqual(waypoints.count, 2)
        XCTAssertEqual(waypoints[0].latitude, 90.0, accuracy: 0.0001)
        XCTAssertEqual(waypoints[1].latitude, -90.0, accuracy: 0.0001)
    }

    func testAcceptsBoundaryLongitudes() throws {
        // Given
        let parser = LogParser()
        let segmentCoords: [[String: Any]] = [
            ["lat": 0.0, "lng": 180.0],
            ["lat": 0.0, "lng": -180.0]
        ]

        // When
        let waypoints = try parser.extractWaypoints(from: segmentCoords)

        // Then
        XCTAssertEqual(waypoints.count, 2)
        XCTAssertEqual(waypoints[0].longitude, 180.0, accuracy: 0.0001)
        XCTAssertEqual(waypoints[1].longitude, -180.0, accuracy: 0.0001)
    }

    // MARK: - Large Dataset Tests

    func testHandlesLargeNumberOfWaypoints() throws {
        // Given
        let parser = LogParser()
        var segmentCoords: [[String: Any]] = []
        for i in 0..<500 {
            segmentCoords.append([
                "lat": 37.0 + Double(i) * 0.001,
                "lng": -122.0 + Double(i) * 0.001
            ])
        }

        // When
        let waypoints = try parser.extractWaypoints(from: segmentCoords)

        // Then
        XCTAssertEqual(waypoints.count, 500)
    }
}
