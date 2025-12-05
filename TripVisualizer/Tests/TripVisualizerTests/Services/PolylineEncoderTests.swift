import XCTest
@testable import TripVisualizer

/// Tests for PolylineEncoder service
/// Validates Google's polyline encoding algorithm implementation
final class PolylineEncoderTests: XCTestCase {

    // MARK: - Basic Encoding Tests

    func testEncodeEmptyPath() {
        // Given
        let encoder = PolylineEncoder()
        let waypoints: [Waypoint] = []

        // When
        let encoded = encoder.encode(waypoints)

        // Then
        XCTAssertEqual(encoded, "")
    }

    func testEncodeSinglePoint() {
        // Given
        let encoder = PolylineEncoder()
        let waypoints = [
            Waypoint(latitude: 38.5, longitude: -120.2)
        ]

        // When
        let encoded = encoder.encode(waypoints)

        // Then
        XCTAssertFalse(encoded.isEmpty)
    }

    func testEncodeGoogleExample() {
        // This is the example from Google's polyline encoding documentation
        // Path: (38.5, -120.2), (40.7, -120.95), (43.252, -126.453)
        // Expected encoding: _p~iF~ps|U_ulLnnqC_mqNvxq`@

        // Given
        let encoder = PolylineEncoder()
        let waypoints = [
            Waypoint(latitude: 38.5, longitude: -120.2),
            Waypoint(latitude: 40.7, longitude: -120.95),
            Waypoint(latitude: 43.252, longitude: -126.453)
        ]

        // When
        let encoded = encoder.encode(waypoints)

        // Then
        XCTAssertEqual(encoded, "_p~iF~ps|U_ulLnnqC_mqNvxq`@")
    }

    func testEncodeTwoPoints() {
        // Given
        let encoder = PolylineEncoder()
        let waypoints = [
            Waypoint(latitude: 37.7749, longitude: -122.4194),
            Waypoint(latitude: 37.7750, longitude: -122.4195)
        ]

        // When
        let encoded = encoder.encode(waypoints)

        // Then
        XCTAssertFalse(encoded.isEmpty)
        // Verify it can be decoded back (round-trip test)
        let decoded = encoder.decode(encoded)
        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].latitude, 37.7749, accuracy: 0.00001)
        XCTAssertEqual(decoded[0].longitude, -122.4194, accuracy: 0.00001)
    }

    // MARK: - Precision Tests

    func testEncodingPrecision() {
        // Given
        let encoder = PolylineEncoder()
        let originalWaypoints = [
            Waypoint(latitude: 37.12345, longitude: -122.54321),
            Waypoint(latitude: 37.98765, longitude: -122.12345)
        ]

        // When
        let encoded = encoder.encode(originalWaypoints)
        let decoded = encoder.decode(encoded)

        // Then - Google polyline uses 5 decimal places precision
        XCTAssertEqual(decoded[0].latitude, originalWaypoints[0].latitude, accuracy: 0.00001)
        XCTAssertEqual(decoded[0].longitude, originalWaypoints[0].longitude, accuracy: 0.00001)
        XCTAssertEqual(decoded[1].latitude, originalWaypoints[1].latitude, accuracy: 0.00001)
        XCTAssertEqual(decoded[1].longitude, originalWaypoints[1].longitude, accuracy: 0.00001)
    }

    // MARK: - Edge Cases

    func testEncodeNegativeCoordinates() {
        // Given
        let encoder = PolylineEncoder()
        let waypoints = [
            Waypoint(latitude: -33.8688, longitude: 151.2093), // Sydney
            Waypoint(latitude: -37.8136, longitude: 144.9631)  // Melbourne
        ]

        // When
        let encoded = encoder.encode(waypoints)
        let decoded = encoder.decode(encoded)

        // Then
        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].latitude, -33.8688, accuracy: 0.00001)
        XCTAssertEqual(decoded[0].longitude, 151.2093, accuracy: 0.00001)
    }

    func testEncodeZeroCoordinates() {
        // Given
        let encoder = PolylineEncoder()
        let waypoints = [
            Waypoint(latitude: 0.0, longitude: 0.0),
            Waypoint(latitude: 1.0, longitude: 1.0)
        ]

        // When
        let encoded = encoder.encode(waypoints)
        let decoded = encoder.decode(encoded)

        // Then
        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].latitude, 0.0, accuracy: 0.00001)
        XCTAssertEqual(decoded[0].longitude, 0.0, accuracy: 0.00001)
    }

    func testEncodeBoundaryCoordinates() {
        // Given
        let encoder = PolylineEncoder()
        let waypoints = [
            Waypoint(latitude: 90.0, longitude: 180.0),   // Max values
            Waypoint(latitude: -90.0, longitude: -180.0)  // Min values
        ]

        // When
        let encoded = encoder.encode(waypoints)
        let decoded = encoder.decode(encoded)

        // Then
        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].latitude, 90.0, accuracy: 0.00001)
        XCTAssertEqual(decoded[0].longitude, 180.0, accuracy: 0.00001)
        XCTAssertEqual(decoded[1].latitude, -90.0, accuracy: 0.00001)
        XCTAssertEqual(decoded[1].longitude, -180.0, accuracy: 0.00001)
    }

    // MARK: - Decoding Tests

    func testDecodeGoogleExample() {
        // Given
        let encoder = PolylineEncoder()
        let encoded = "_p~iF~ps|U_ulLnnqC_mqNvxq`@"

        // When
        let decoded = encoder.decode(encoded)

        // Then
        XCTAssertEqual(decoded.count, 3)
        XCTAssertEqual(decoded[0].latitude, 38.5, accuracy: 0.00001)
        XCTAssertEqual(decoded[0].longitude, -120.2, accuracy: 0.00001)
        XCTAssertEqual(decoded[1].latitude, 40.7, accuracy: 0.00001)
        XCTAssertEqual(decoded[1].longitude, -120.95, accuracy: 0.00001)
        XCTAssertEqual(decoded[2].latitude, 43.252, accuracy: 0.00001)
        XCTAssertEqual(decoded[2].longitude, -126.453, accuracy: 0.00001)
    }

    func testDecodeEmptyString() {
        // Given
        let encoder = PolylineEncoder()

        // When
        let decoded = encoder.decode("")

        // Then
        XCTAssertEqual(decoded.count, 0)
    }

    // MARK: - Round Trip Tests

    func testRoundTripWithManyPoints() {
        // Given
        let encoder = PolylineEncoder()
        var waypoints: [Waypoint] = []
        for i in 0..<100 {
            waypoints.append(Waypoint(
                latitude: 37.0 + Double(i) * 0.01,
                longitude: -122.0 + Double(i) * 0.01
            ))
        }

        // When
        let encoded = encoder.encode(waypoints)
        let decoded = encoder.decode(encoded)

        // Then
        XCTAssertEqual(decoded.count, waypoints.count)
        for i in 0..<waypoints.count {
            XCTAssertEqual(decoded[i].latitude, waypoints[i].latitude, accuracy: 0.00001)
            XCTAssertEqual(decoded[i].longitude, waypoints[i].longitude, accuracy: 0.00001)
        }
    }

    func testRoundTripWithSmallDeltas() {
        // Given - very close points
        let encoder = PolylineEncoder()
        let waypoints = [
            Waypoint(latitude: 37.77490, longitude: -122.41940),
            Waypoint(latitude: 37.77491, longitude: -122.41941),
            Waypoint(latitude: 37.77492, longitude: -122.41942)
        ]

        // When
        let encoded = encoder.encode(waypoints)
        let decoded = encoder.decode(encoded)

        // Then
        XCTAssertEqual(decoded.count, 3)
        for i in 0..<waypoints.count {
            XCTAssertEqual(decoded[i].latitude, waypoints[i].latitude, accuracy: 0.00001)
            XCTAssertEqual(decoded[i].longitude, waypoints[i].longitude, accuracy: 0.00001)
        }
    }

    // MARK: - URL Length Tests

    func testEncodedLengthReasonable() {
        // Given - typical trip with 50 waypoints
        let encoder = PolylineEncoder()
        var waypoints: [Waypoint] = []
        for i in 0..<50 {
            waypoints.append(Waypoint(
                latitude: 37.7 + Double(i) * 0.005,
                longitude: -122.4 + Double(i) * 0.005
            ))
        }

        // When
        let encoded = encoder.encode(waypoints)

        // Then - encoded string should be reasonably short for URL usage
        // Each point typically adds 6-10 characters when deltas are small
        XCTAssertLessThan(encoded.count, 1000)
    }
}
