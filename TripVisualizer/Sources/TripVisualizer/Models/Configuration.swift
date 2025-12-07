import Foundation

/// Application configuration loaded from file or defaults.
///
/// Configuration supports loading from `~/.tripvisualizer/config.json` or `./config.json`.
/// All fields have sensible defaults and can be overridden via the config file or CLI flags.
public struct Configuration: Codable, Equatable {

    // MARK: - Properties

    /// Where to save generated files (default: "output")
    public var outputDirectory: String

    /// Which outputs to generate (default: [.image, .html])
    public var outputFormats: [OutputFormat]

    /// DataDog API region (default: "us1")
    public var datadogRegion: String

    /// DataDog environment filter - "prod" or "test" (default: "prod")
    public var datadogEnv: String

    /// DataDog service filter (default: "delivery-driver-service")
    public var datadogService: String

    /// Static map width in pixels (default: 800)
    public var mapWidth: Int

    /// Static map height in pixels (default: 600)
    public var mapHeight: Int

    /// Route polyline color as hex string (default: "0000FF" blue)
    public var routeColor: String

    /// Route polyline weight in pixels (default: 4)
    public var routeWeight: Int

    /// Logging verbosity (default: .info)
    public var logLevel: LogLevel

    /// Network retry count (default: 3)
    public var retryAttempts: Int

    /// Network timeout in seconds (default: 30)
    public var timeoutSeconds: Int

    // MARK: - Default Configuration

    /// Default configuration with sensible defaults
    public static let defaultConfig = Configuration(
        outputDirectory: "output",
        outputFormats: [.image, .html],
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

    // MARK: - Initialization

    public init(
        outputDirectory: String,
        outputFormats: [OutputFormat],
        datadogRegion: String,
        datadogEnv: String,
        datadogService: String,
        mapWidth: Int,
        mapHeight: Int,
        routeColor: String,
        routeWeight: Int,
        logLevel: LogLevel,
        retryAttempts: Int,
        timeoutSeconds: Int
    ) {
        self.outputDirectory = outputDirectory
        self.outputFormats = outputFormats
        self.datadogRegion = datadogRegion
        self.datadogEnv = datadogEnv
        self.datadogService = datadogService
        self.mapWidth = mapWidth
        self.mapHeight = mapHeight
        self.routeColor = routeColor
        self.routeWeight = routeWeight
        self.logLevel = logLevel
        self.retryAttempts = retryAttempts
        self.timeoutSeconds = timeoutSeconds
    }

    // MARK: - Codable with Defaults

    enum CodingKeys: String, CodingKey {
        case outputDirectory
        case outputFormats
        case datadogRegion
        case datadogEnv
        case datadogService
        case mapWidth
        case mapHeight
        case routeColor
        case routeWeight
        case logLevel
        case retryAttempts
        case timeoutSeconds
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        outputDirectory = try container.decodeIfPresent(String.self, forKey: .outputDirectory) ?? Self.defaultConfig.outputDirectory
        outputFormats = try container.decodeIfPresent([OutputFormat].self, forKey: .outputFormats) ?? Self.defaultConfig.outputFormats
        datadogRegion = try container.decodeIfPresent(String.self, forKey: .datadogRegion) ?? Self.defaultConfig.datadogRegion
        datadogEnv = try container.decodeIfPresent(String.self, forKey: .datadogEnv) ?? Self.defaultConfig.datadogEnv
        datadogService = try container.decodeIfPresent(String.self, forKey: .datadogService) ?? Self.defaultConfig.datadogService
        mapWidth = try container.decodeIfPresent(Int.self, forKey: .mapWidth) ?? Self.defaultConfig.mapWidth
        mapHeight = try container.decodeIfPresent(Int.self, forKey: .mapHeight) ?? Self.defaultConfig.mapHeight
        routeColor = try container.decodeIfPresent(String.self, forKey: .routeColor) ?? Self.defaultConfig.routeColor
        routeWeight = try container.decodeIfPresent(Int.self, forKey: .routeWeight) ?? Self.defaultConfig.routeWeight
        logLevel = try container.decodeIfPresent(LogLevel.self, forKey: .logLevel) ?? Self.defaultConfig.logLevel
        retryAttempts = try container.decodeIfPresent(Int.self, forKey: .retryAttempts) ?? Self.defaultConfig.retryAttempts
        timeoutSeconds = try container.decodeIfPresent(Int.self, forKey: .timeoutSeconds) ?? Self.defaultConfig.timeoutSeconds
    }

    // MARK: - DataDog Configuration

    /// Returns the DataDog API base URL for the configured region
    public var datadogAPIURL: String {
        switch datadogRegion.lowercased() {
        case "us1", "":
            return "https://api.datadoghq.com"
        case "us3":
            return "https://api.us3.datadoghq.com"
        case "us5":
            return "https://api.us5.datadoghq.com"
        case "eu":
            return "https://api.datadoghq.eu"
        case "ap1":
            return "https://api.ap1.datadoghq.com"
        default:
            return "https://api.datadoghq.com"
        }
    }

    /// Builds the DataDog log query string for a given trip ID
    ///
    /// Query format: `env:<datadogEnv> @trip_id:<uuid> service:<datadogService> "received request for SaveActualRouteForTrip"`
    public func buildDatadogQuery(tripId: UUID) -> String {
        "env:\(datadogEnv) @trip_id:\(tripId.uuidString.lowercased()) service:\(datadogService) \"received request for SaveActualRouteForTrip\""
    }

    // MARK: - Map Configuration

    /// Returns the map size string for Google Maps Static API (e.g., "800x600")
    public var mapSize: String {
        "\(mapWidth)x\(mapHeight)"
    }
}
