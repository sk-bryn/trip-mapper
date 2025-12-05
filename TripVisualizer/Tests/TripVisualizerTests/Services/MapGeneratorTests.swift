import XCTest
@testable import TripVisualizer

/// Tests for MapGenerator service
/// Validates HTML generation and Static Maps URL construction
final class MapGeneratorTests: XCTestCase {

    // MARK: - HTML Generation Tests

    func testGenerateHTMLWithValidWaypoints() throws {
        // Given
        let generator = MapGenerator(apiKey: "test-api-key")
        let tripId = UUID()
        let waypoints = [
            Waypoint(latitude: 37.7749, longitude: -122.4194),
            Waypoint(latitude: 37.7750, longitude: -122.4195),
            Waypoint(latitude: 37.7751, longitude: -122.4196)
        ]

        // When
        let html = try generator.generateHTML(tripId: tripId, waypoints: waypoints)

        // Then
        XCTAssertTrue(html.contains("<!DOCTYPE html>"))
        XCTAssertTrue(html.contains(tripId.uuidString))
        XCTAssertTrue(html.contains("test-api-key"))
        XCTAssertTrue(html.contains("37.7749"))
        XCTAssertTrue(html.contains("-122.4194"))
    }

    func testGenerateHTMLContainsGoogleMapsScript() throws {
        // Given
        let generator = MapGenerator(apiKey: "test-api-key")
        let tripId = UUID()
        let waypoints = [
            Waypoint(latitude: 37.7749, longitude: -122.4194),
            Waypoint(latitude: 37.7750, longitude: -122.4195)
        ]

        // When
        let html = try generator.generateHTML(tripId: tripId, waypoints: waypoints)

        // Then
        XCTAssertTrue(html.contains("maps.googleapis.com"))
        XCTAssertTrue(html.contains("initMap"))
        XCTAssertTrue(html.contains("google.maps.Map"))
    }

    func testGenerateHTMLContainsPolyline() throws {
        // Given
        let generator = MapGenerator(apiKey: "test-api-key")
        let tripId = UUID()
        let waypoints = [
            Waypoint(latitude: 37.7749, longitude: -122.4194),
            Waypoint(latitude: 37.7750, longitude: -122.4195)
        ]

        // When
        let html = try generator.generateHTML(tripId: tripId, waypoints: waypoints)

        // Then
        XCTAssertTrue(html.contains("Polyline"))
        XCTAssertTrue(html.contains("path"))
    }

    func testGenerateHTMLContainsMarkers() throws {
        // Given
        let generator = MapGenerator(apiKey: "test-api-key")
        let tripId = UUID()
        let waypoints = [
            Waypoint(latitude: 37.7749, longitude: -122.4194),
            Waypoint(latitude: 37.7751, longitude: -122.4196)
        ]

        // When
        let html = try generator.generateHTML(tripId: tripId, waypoints: waypoints)

        // Then
        XCTAssertTrue(html.contains("Marker"))
        XCTAssertTrue(html.contains("Start"))
        XCTAssertTrue(html.contains("End"))
    }

    func testGenerateHTMLWithEmptyWaypointsThrows() {
        // Given
        let generator = MapGenerator(apiKey: "test-api-key")
        let tripId = UUID()
        let waypoints: [Waypoint] = []

        // When/Then
        XCTAssertThrowsError(try generator.generateHTML(tripId: tripId, waypoints: waypoints))
    }

    // MARK: - Static Maps URL Tests

    func testGenerateStaticMapsURL() {
        // Given
        let generator = MapGenerator(apiKey: "test-api-key")
        let waypoints = [
            Waypoint(latitude: 37.7749, longitude: -122.4194),
            Waypoint(latitude: 37.7750, longitude: -122.4195)
        ]

        // When
        let url = generator.generateStaticMapsURL(waypoints: waypoints)

        // Then
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.contains("maps.googleapis.com/maps/api/staticmap"))
        XCTAssertTrue(url!.absoluteString.contains("key=test-api-key"))
    }

    func testStaticMapsURLContainsEncodedPath() {
        // Given
        let generator = MapGenerator(apiKey: "test-api-key")
        let waypoints = [
            Waypoint(latitude: 37.7749, longitude: -122.4194),
            Waypoint(latitude: 37.7750, longitude: -122.4195)
        ]

        // When
        let url = generator.generateStaticMapsURL(waypoints: waypoints)

        // Then
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.contains("path="))
        XCTAssertTrue(url!.absoluteString.contains("enc:"))
    }

    func testStaticMapsURLContainsMarkers() {
        // Given
        let generator = MapGenerator(apiKey: "test-api-key")
        let waypoints = [
            Waypoint(latitude: 37.7749, longitude: -122.4194),
            Waypoint(latitude: 37.7751, longitude: -122.4196)
        ]

        // When
        let url = generator.generateStaticMapsURL(waypoints: waypoints)

        // Then
        XCTAssertNotNil(url)
        let urlString = url!.absoluteString
        XCTAssertTrue(urlString.contains("markers="))
        XCTAssertTrue(urlString.contains("green") || urlString.contains("color:0x"))
        XCTAssertTrue(urlString.contains("red") || urlString.contains("color:0x"))
    }

    func testStaticMapsURLWithCustomSize() {
        // Given
        let generator = MapGenerator(apiKey: "test-api-key")
        let waypoints = [
            Waypoint(latitude: 37.7749, longitude: -122.4194),
            Waypoint(latitude: 37.7750, longitude: -122.4195)
        ]

        // When
        let url = generator.generateStaticMapsURL(waypoints: waypoints, width: 800, height: 600)

        // Then
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.contains("size=800x600"))
    }

    func testStaticMapsURLDefaultSize() {
        // Given
        let generator = MapGenerator(apiKey: "test-api-key")
        let waypoints = [
            Waypoint(latitude: 37.7749, longitude: -122.4194),
            Waypoint(latitude: 37.7750, longitude: -122.4195)
        ]

        // When
        let url = generator.generateStaticMapsURL(waypoints: waypoints)

        // Then
        XCTAssertNotNil(url)
        // Default size should be 640x480 or similar reasonable default
        XCTAssertTrue(url!.absoluteString.contains("size="))
    }

    func testStaticMapsURLWithEmptyWaypoints() {
        // Given
        let generator = MapGenerator(apiKey: "test-api-key")
        let waypoints: [Waypoint] = []

        // When
        let url = generator.generateStaticMapsURL(waypoints: waypoints)

        // Then
        XCTAssertNil(url)
    }

    // MARK: - File Output Tests

    func testWriteHTMLToFile() throws {
        // Given
        let generator = MapGenerator(apiKey: "test-api-key")
        let tripId = UUID()
        let waypoints = [
            Waypoint(latitude: 37.7749, longitude: -122.4194),
            Waypoint(latitude: 37.7750, longitude: -122.4195)
        ]
        let tempDir = FileManager.default.temporaryDirectory.path
        let outputPath = (tempDir as NSString).appendingPathComponent("test-\(tripId.uuidString).html")

        // When
        try generator.writeHTML(tripId: tripId, waypoints: waypoints, to: outputPath)

        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputPath))
        let content = try String(contentsOfFile: outputPath, encoding: .utf8)
        XCTAssertTrue(content.contains("<!DOCTYPE html>"))

        // Cleanup
        try? FileManager.default.removeItem(atPath: outputPath)
    }

    func testWriteHTMLToInvalidPathThrows() {
        // Given
        let generator = MapGenerator(apiKey: "test-api-key")
        let tripId = UUID()
        let waypoints = [
            Waypoint(latitude: 37.7749, longitude: -122.4194),
            Waypoint(latitude: 37.7750, longitude: -122.4195)
        ]
        let invalidPath = "/nonexistent/directory/test.html"

        // When/Then
        XCTAssertThrowsError(try generator.writeHTML(tripId: tripId, waypoints: waypoints, to: invalidPath))
    }

    // MARK: - URL Output Tests

    func testGenerateGoogleMapsWebURL() {
        // Given
        let generator = MapGenerator(apiKey: "test-api-key")
        let waypoints = [
            Waypoint(latitude: 37.7749, longitude: -122.4194),
            Waypoint(latitude: 37.7751, longitude: -122.4196)
        ]

        // When
        let url = generator.generateGoogleMapsWebURL(waypoints: waypoints)

        // Then
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.contains("google.com/maps"))
    }

    // MARK: - Coordinate Formatting Tests

    func testCoordinatesJSONFormatting() throws {
        // Given
        let generator = MapGenerator(apiKey: "test-api-key")
        let waypoints = [
            Waypoint(latitude: 37.7749, longitude: -122.4194),
            Waypoint(latitude: 37.7750, longitude: -122.4195)
        ]

        // When
        let json = generator.coordinatesToJSON(waypoints)

        // Then
        XCTAssertTrue(json.contains("lat"))
        XCTAssertTrue(json.contains("lng"))
        XCTAssertTrue(json.contains("37.7749"))
        XCTAssertTrue(json.contains("-122.4194"))
    }
}
