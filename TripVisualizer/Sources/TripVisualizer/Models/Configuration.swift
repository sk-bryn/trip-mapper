import Foundation

/// Application configuration loaded from file or defaults.
///
/// Configuration supports loading from `~/.tripvisualizer/config.json` or `./config.json`.
/// All fields have sensible defaults and can be overridden via the config file or CLI flags.
public struct Configuration: Codable, Equatable {

    // MARK: - Properties

    /// Where to save generated files (default: current directory)
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

    /// Logging verbosity (default: .info)
    public var logLevel: LogLevel

    /// Network retry count (default: 3)
    public var retryAttempts: Int

    /// Network timeout in seconds (default: 30)
    public var timeoutSeconds: Int

    // MARK: - Default Configuration

    /// Default configuration with sensible defaults
    public static let `default` = Configuration(
        outputDirectory: ".",
        outputFormats: [.image, .html],
        datadogRegion: "us1",
        datadogEnv: "prod",
        datadogService: "delivery-driver-service",
        mapWidth: 800,
        mapHeight: 600,
        logLevel: .info,
        retryAttempts: 3,
        timeoutSeconds: 30
    )

    // MARK: - Initialization

    public init(
        outputDirectory: String = ".",
        outputFormats: [OutputFormat] = [.image, .html],
        datadogRegion: String = "us1",
        datadogEnv: String = "prod",
        datadogService: String = "delivery-driver-service",
        mapWidth: Int = 800,
        mapHeight: Int = 600,
        logLevel: LogLevel = .info,
        retryAttempts: Int = 3,
        timeoutSeconds: Int = 30
    ) {
        self.outputDirectory = outputDirectory
        self.outputFormats = outputFormats
        self.datadogRegion = datadogRegion
        self.datadogEnv = datadogEnv
        self.datadogService = datadogService
        self.mapWidth = mapWidth
        self.mapHeight = mapHeight
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
        case logLevel
        case retryAttempts
        case timeoutSeconds
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        outputDirectory = try container.decodeIfPresent(String.self, forKey: .outputDirectory) ?? "."
        outputFormats = try container.decodeIfPresent([OutputFormat].self, forKey: .outputFormats) ?? [.image, .html]
        datadogRegion = try container.decodeIfPresent(String.self, forKey: .datadogRegion) ?? "us1"
        datadogEnv = try container.decodeIfPresent(String.self, forKey: .datadogEnv) ?? "prod"
        datadogService = try container.decodeIfPresent(String.self, forKey: .datadogService) ?? "delivery-driver-service"
        mapWidth = try container.decodeIfPresent(Int.self, forKey: .mapWidth) ?? 800
        mapHeight = try container.decodeIfPresent(Int.self, forKey: .mapHeight) ?? 600
        logLevel = try container.decodeIfPresent(LogLevel.self, forKey: .logLevel) ?? .info
        retryAttempts = try container.decodeIfPresent(Int.self, forKey: .retryAttempts) ?? 3
        timeoutSeconds = try container.decodeIfPresent(Int.self, forKey: .timeoutSeconds) ?? 30
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
