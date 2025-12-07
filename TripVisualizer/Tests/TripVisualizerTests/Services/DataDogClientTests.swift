import XCTest
@testable import TripVisualizer

/// Tests for DataDogClient service
/// Validates query construction, API interaction, and response parsing
final class DataDogClientTests: XCTestCase {

    // MARK: - Query Construction Tests

    func testQueryConstructionWithDefaultConfig() {
        // Given
        let config = Configuration.defaultConfig
        let tripId = UUID()

        // When
        let query = config.buildDatadogQuery(tripId: tripId)

        // Then
        XCTAssertTrue(query.contains("env:prod"), "Query should contain default env:prod")
        XCTAssertTrue(query.contains("@trip_id:\(tripId.uuidString.lowercased())"), "Query should contain trip_id filter")
        XCTAssertTrue(query.contains("service:delivery-driver-service"), "Query should contain default service")
        XCTAssertTrue(query.contains("received request for SaveActualRouteForTrip"), "Query should contain content filter")
    }

    func testQueryConstructionWithCustomEnv() {
        // Given
        var config = Configuration.defaultConfig
        config.datadogEnv = "test"
        let tripId = UUID()

        // When
        let query = config.buildDatadogQuery(tripId: tripId)

        // Then
        XCTAssertTrue(query.contains("env:test"), "Query should contain custom env:test")
        XCTAssertFalse(query.contains("env:prod"), "Query should not contain default env")
    }

    func testQueryConstructionWithCustomService() {
        // Given
        var config = Configuration.defaultConfig
        config.datadogService = "custom-service"
        let tripId = UUID()

        // When
        let query = config.buildDatadogQuery(tripId: tripId)

        // Then
        XCTAssertTrue(query.contains("service:custom-service"), "Query should contain custom service")
    }

    func testDatadogAPIURLDefaultRegion() {
        // Given
        let config = Configuration.defaultConfig

        // Then
        XCTAssertEqual(config.datadogAPIURL, "https://api.datadoghq.com")
    }

    func testDatadogAPIURLEURegion() {
        // Given
        var config = Configuration.defaultConfig
        config.datadogRegion = "eu"

        // Then
        XCTAssertEqual(config.datadogAPIURL, "https://api.datadoghq.eu")
    }

    // MARK: - Request Building Tests

    func testBuildSearchRequestWithValidCredentials() async throws {
        // Given
        let client = DataDogClient(
            apiKey: "test-api-key",
            appKey: "test-app-key",
            configuration: .defaultConfig
        )
        let tripId = UUID()

        // When
        let request = try client.buildSearchRequest(tripId: tripId)

        // Then
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.absoluteString.contains("logs/events/search") ?? false)
        XCTAssertEqual(request.value(forHTTPHeaderField: "DD-API-KEY"), "test-api-key")
        XCTAssertEqual(request.value(forHTTPHeaderField: "DD-APPLICATION-KEY"), "test-app-key")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
    }

    func testBuildSearchRequestBodyContainsQuery() async throws {
        // Given
        let client = DataDogClient(
            apiKey: "test-api-key",
            appKey: "test-app-key",
            configuration: .defaultConfig
        )
        let tripId = UUID()

        // When
        let request = try client.buildSearchRequest(tripId: tripId)
        let body = request.httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }

        // Then
        XCTAssertNotNil(body)
        let filter = body?["filter"] as? [String: Any]
        XCTAssertNotNil(filter)
        let query = filter?["query"] as? String
        XCTAssertNotNil(query)
        XCTAssertTrue(query?.contains(tripId.uuidString.lowercased()) ?? false)
    }

    // MARK: - Response Parsing Tests

    func testParseValidLogResponse() throws {
        // Given
        let client = DataDogClient(
            apiKey: "test-api-key",
            appKey: "test-app-key",
            configuration: .defaultConfig
        )

        let jsonData = """
        {
            "data": [
                {
                    "id": "log-id-123",
                    "attributes": {
                        "timestamp": "2024-01-15T10:30:00.000Z",
                        "message": "received request for SaveActualRouteForTrip",
                        "attributes": {
                            "segment_coords": [
                                {"lat": 37.7749, "lng": -122.4194},
                                {"lat": 37.7750, "lng": -122.4195}
                            ]
                        }
                    }
                }
            ]
        }
        """.data(using: .utf8)!

        // When
        let response = try client.parseResponse(jsonData)

        // Then
        XCTAssertEqual(response.data.count, 1)
        XCTAssertEqual(response.data[0].id, "log-id-123")
    }

    func testParseEmptyLogResponse() throws {
        // Given
        let client = DataDogClient(
            apiKey: "test-api-key",
            appKey: "test-app-key",
            configuration: .defaultConfig
        )

        let jsonData = """
        {
            "data": []
        }
        """.data(using: .utf8)!

        // When
        let response = try client.parseResponse(jsonData)

        // Then
        XCTAssertEqual(response.data.count, 0)
    }

    func testParseInvalidJSONThrowsError() {
        // Given
        let client = DataDogClient(
            apiKey: "test-api-key",
            appKey: "test-app-key",
            configuration: .defaultConfig
        )

        let invalidData = "not valid json".data(using: .utf8)!

        // Then
        XCTAssertThrowsError(try client.parseResponse(invalidData))
    }

    // MARK: - Error Handling Tests

    func testClientInitializationWithEmptyAPIKey() {
        // Given/When
        let client = DataDogClient(
            apiKey: "",
            appKey: "test-app-key",
            configuration: .defaultConfig
        )

        // Then - client should be created but validation should fail on use
        XCTAssertNotNil(client)
    }

    func testClientInitializationWithEmptyAppKey() {
        // Given/When
        let client = DataDogClient(
            apiKey: "test-api-key",
            appKey: "",
            configuration: .defaultConfig
        )

        // Then - client should be created but validation should fail on use
        XCTAssertNotNil(client)
    }

    // MARK: - Log Link Generation Tests

    func testGenerateLogLink() {
        // Given
        let client = DataDogClient(
            apiKey: "test-api-key",
            appKey: "test-app-key",
            configuration: .defaultConfig
        )
        let logId = "test-log-id-123"

        // When
        let link = client.generateLogLink(logId: logId)

        // Then
        XCTAssertTrue(link.contains("datadoghq.com"))
        XCTAssertTrue(link.contains(logId))
    }

    func testGenerateLogLinkEURegion() {
        // Given
        var config = Configuration.defaultConfig
        config.datadogRegion = "eu"
        let client = DataDogClient(
            apiKey: "test-api-key",
            appKey: "test-app-key",
            configuration: config
        )
        let logId = "test-log-id-123"

        // When
        let link = client.generateLogLink(logId: logId)

        // Then
        XCTAssertTrue(link.contains("datadoghq.eu"))
    }
}
