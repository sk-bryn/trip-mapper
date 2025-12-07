import XCTest
@testable import TripVisualizer

final class ConfigurationTests: XCTestCase {

    // MARK: - Default Configuration Tests

    func testDefaultConfiguration() {
        let config = Configuration.defaultConfig

        XCTAssertEqual(config.outputDirectory, "output")
        XCTAssertEqual(config.outputFormats, [.image, .html])
        XCTAssertEqual(config.datadogRegion, "us1")
        XCTAssertEqual(config.datadogEnv, "prod")
        XCTAssertEqual(config.datadogService, "delivery-driver-service")
        XCTAssertEqual(config.mapWidth, 800)
        XCTAssertEqual(config.mapHeight, 600)
        XCTAssertEqual(config.routeColor, "0000FF")
        XCTAssertEqual(config.routeWeight, 4)
        XCTAssertEqual(config.logLevel, .info)
        XCTAssertEqual(config.retryAttempts, 3)
        XCTAssertEqual(config.timeoutSeconds, 30)
    }

    // MARK: - Custom Configuration Tests

    func testCustomConfiguration() {
        let config = Configuration(
            outputDirectory: "/tmp/maps",
            outputFormats: [.url],
            datadogRegion: "eu",
            datadogEnv: "test",
            datadogService: "custom-service",
            mapWidth: 640,
            mapHeight: 480,
            routeColor: "FF0000",
            routeWeight: 6,
            logLevel: .debug,
            retryAttempts: 5,
            timeoutSeconds: 60
        )

        XCTAssertEqual(config.outputDirectory, "/tmp/maps")
        XCTAssertEqual(config.outputFormats, [.url])
        XCTAssertEqual(config.datadogRegion, "eu")
        XCTAssertEqual(config.datadogEnv, "test")
        XCTAssertEqual(config.datadogService, "custom-service")
        XCTAssertEqual(config.mapWidth, 640)
        XCTAssertEqual(config.mapHeight, 480)
        XCTAssertEqual(config.routeColor, "FF0000")
        XCTAssertEqual(config.routeWeight, 6)
        XCTAssertEqual(config.logLevel, .debug)
        XCTAssertEqual(config.retryAttempts, 5)
        XCTAssertEqual(config.timeoutSeconds, 60)
    }

    // MARK: - DataDog Environment Tests

    func testValidDatadogEnvValues() {
        let prodConfig = Configuration(
            outputDirectory: ".",
            outputFormats: [.image],
            datadogRegion: "us1",
            datadogEnv: "prod",
            datadogService: "test-service",
            mapWidth: 800,
            mapHeight: 600,
            routeColor: "0000FF",
            routeWeight: 4,
            logLevel: .info,
            retryAttempts: 3,
            timeoutSeconds: 30
        )

        let testConfig = Configuration(
            outputDirectory: ".",
            outputFormats: [.image],
            datadogRegion: "us1",
            datadogEnv: "test",
            datadogService: "test-service",
            mapWidth: 800,
            mapHeight: 600,
            routeColor: "0000FF",
            routeWeight: 4,
            logLevel: .info,
            retryAttempts: 3,
            timeoutSeconds: 30
        )

        XCTAssertEqual(prodConfig.datadogEnv, "prod")
        XCTAssertEqual(testConfig.datadogEnv, "test")
    }

    // MARK: - DataDog Query Construction Tests

    func testDatadogQueryConstruction() {
        let config = Configuration(
            outputDirectory: ".",
            outputFormats: [.image],
            datadogRegion: "us1",
            datadogEnv: "prod",
            datadogService: "delivery-driver-service",
            mapWidth: 800,
            mapHeight: 600,
            routeColor: "0000FF",
            routeWeight: 4,
            logLevel: .info,
            retryAttempts: 3,
            timeoutSeconds: 30
        )

        let tripId = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000")!
        let query = config.buildDatadogQuery(tripId: tripId)

        XCTAssertTrue(query.contains("env:prod"))
        XCTAssertTrue(query.contains("@trip_id:550e8400-e29b-41d4-a716-446655440000"))
        XCTAssertTrue(query.contains("service:delivery-driver-service"))
        XCTAssertTrue(query.contains("received request for SaveActualRouteForTrip"))
    }

    func testDatadogQueryWithTestEnv() {
        let config = Configuration(
            outputDirectory: ".",
            outputFormats: [.image],
            datadogRegion: "us1",
            datadogEnv: "test",
            datadogService: "test-service",
            mapWidth: 800,
            mapHeight: 600,
            routeColor: "0000FF",
            routeWeight: 4,
            logLevel: .info,
            retryAttempts: 3,
            timeoutSeconds: 30
        )

        let tripId = UUID()
        let query = config.buildDatadogQuery(tripId: tripId)

        XCTAssertTrue(query.contains("env:test"))
        XCTAssertTrue(query.contains("service:test-service"))
    }

    // MARK: - DataDog API URL Tests

    func testDatadogAPIURL() {
        let us1Config = Configuration.defaultConfig
        XCTAssertEqual(us1Config.datadogAPIURL, "https://api.datadoghq.com")

        let euConfig = Configuration(
            outputDirectory: ".",
            outputFormats: [.image],
            datadogRegion: "eu",
            datadogEnv: "prod",
            datadogService: "test-service",
            mapWidth: 800,
            mapHeight: 600,
            routeColor: "0000FF",
            routeWeight: 4,
            logLevel: .info,
            retryAttempts: 3,
            timeoutSeconds: 30
        )
        XCTAssertEqual(euConfig.datadogAPIURL, "https://api.datadoghq.eu")
    }

    // MARK: - Output Format Tests

    func testMultipleOutputFormats() {
        let config = Configuration(
            outputDirectory: ".",
            outputFormats: [.image, .html, .url],
            datadogRegion: "us1",
            datadogEnv: "prod",
            datadogService: "test-service",
            mapWidth: 800,
            mapHeight: 600,
            routeColor: "0000FF",
            routeWeight: 4,
            logLevel: .info,
            retryAttempts: 3,
            timeoutSeconds: 30
        )

        XCTAssertEqual(config.outputFormats.count, 3)
        XCTAssertTrue(config.outputFormats.contains(OutputFormat.image))
        XCTAssertTrue(config.outputFormats.contains(OutputFormat.html))
        XCTAssertTrue(config.outputFormats.contains(OutputFormat.url))
    }

    // MARK: - Codable Tests

    func testConfigurationEncoding() throws {
        let config = Configuration.defaultConfig

        let encoder = JSONEncoder()
        let data = try encoder.encode(config)

        XCTAssertFalse(data.isEmpty)
    }

    func testConfigurationDecoding() throws {
        let json = """
        {
            "outputDirectory": "/custom/path",
            "outputFormats": ["image", "html"],
            "datadogRegion": "us1",
            "datadogEnv": "test",
            "datadogService": "my-service",
            "mapWidth": 640,
            "mapHeight": 480,
            "logLevel": "debug",
            "retryAttempts": 5,
            "timeoutSeconds": 45
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let config = try decoder.decode(Configuration.self, from: json)

        XCTAssertEqual(config.outputDirectory, "/custom/path")
        XCTAssertEqual(config.datadogEnv, "test")
        XCTAssertEqual(config.datadogService, "my-service")
        XCTAssertEqual(config.mapWidth, 640)
        XCTAssertEqual(config.logLevel, .debug)
    }

    func testPartialConfigurationDecoding() throws {
        // Test that missing fields use defaults
        let json = """
        {
            "datadogEnv": "test"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let config = try decoder.decode(Configuration.self, from: json)

        // Custom value
        XCTAssertEqual(config.datadogEnv, "test")

        // Default values
        XCTAssertEqual(config.outputDirectory, "output")
        XCTAssertEqual(config.datadogRegion, "us1")
        XCTAssertEqual(config.datadogService, "delivery-driver-service")
        XCTAssertEqual(config.routeColor, "0000FF")
        XCTAssertEqual(config.routeWeight, 4)
    }

    func testEmptyJSONReturnsAllDefaults() throws {
        // Empty JSON should return all default values
        let json = "{}".data(using: .utf8)!

        let decoder = JSONDecoder()
        let config = try decoder.decode(Configuration.self, from: json)

        // All fields should match defaultConfig
        XCTAssertEqual(config, Configuration.defaultConfig)
    }

    func testInvalidJSONThrowsError() {
        let invalidJSON = "{ invalid json }".data(using: .utf8)!

        let decoder = JSONDecoder()

        XCTAssertThrowsError(try decoder.decode(Configuration.self, from: invalidJSON)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }

    func testInvalidTypeThrowsError() {
        // mapWidth should be Int, not String
        let json = """
        {
            "mapWidth": "not a number"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()

        XCTAssertThrowsError(try decoder.decode(Configuration.self, from: json)) { error in
            guard case DecodingError.typeMismatch = error else {
                XCTFail("Expected typeMismatch error, got \(error)")
                return
            }
        }
    }

    func testInvalidLogLevelThrowsError() {
        let json = """
        {
            "logLevel": "invalid"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()

        XCTAssertThrowsError(try decoder.decode(Configuration.self, from: json)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }

    func testInvalidOutputFormatThrowsError() {
        let json = """
        {
            "outputFormats": ["invalid_format"]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()

        XCTAssertThrowsError(try decoder.decode(Configuration.self, from: json)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }

    // MARK: - Equatable Tests

    func testConfigurationEquality() {
        let config1 = Configuration.defaultConfig
        let config2 = Configuration.defaultConfig

        XCTAssertEqual(config1, config2)
    }

    func testConfigurationInequality() {
        let config1 = Configuration.defaultConfig
        let config2 = Configuration(
            outputDirectory: "/different",
            outputFormats: [.url],
            datadogRegion: "eu",
            datadogEnv: "test",
            datadogService: "other-service",
            mapWidth: 640,
            mapHeight: 480,
            routeColor: "FF0000",
            routeWeight: 2,
            logLevel: .error,
            retryAttempts: 1,
            timeoutSeconds: 10
        )

        XCTAssertNotEqual(config1, config2)
    }
}
