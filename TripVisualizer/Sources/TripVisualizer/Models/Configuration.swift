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

    /// Maximum logs to process per trip (default: 50)
    public var maxLogs: Int

    /// Time threshold for gap detection in seconds (default: 300 = 5 minutes)
    public var gapThresholdSeconds: TimeInterval

    /// Generate outputs for each individual log in addition to aggregate (default: true)
    /// When true, creates HTML/PNG/URL for each log named with the log's timestamp,
    /// then produces the aggregate results as usual.
    public var perLogOutput: Bool

    /// Marker style for delivery destination markers (default: purple home icon)
    public var deliveryDestinationMarkerStyle: MarkerStyle

    /// Marker style for restaurant origin markers (default: blue restaurant icon)
    public var restaurantOriginMarkerStyle: MarkerStyle

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
        timeoutSeconds: 30,
        maxLogs: 50,
        gapThresholdSeconds: 300,
        perLogOutput: true,
        deliveryDestinationMarkerStyle: .defaultDeliveryDestination,
        restaurantOriginMarkerStyle: .defaultRestaurantOrigin
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
        timeoutSeconds: Int,
        maxLogs: Int = 50,
        gapThresholdSeconds: TimeInterval = 300,
        perLogOutput: Bool = true,
        deliveryDestinationMarkerStyle: MarkerStyle = .defaultDeliveryDestination,
        restaurantOriginMarkerStyle: MarkerStyle = .defaultRestaurantOrigin
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
        self.maxLogs = maxLogs
        self.gapThresholdSeconds = gapThresholdSeconds
        self.perLogOutput = perLogOutput
        self.deliveryDestinationMarkerStyle = deliveryDestinationMarkerStyle
        self.restaurantOriginMarkerStyle = restaurantOriginMarkerStyle
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
        case maxLogs
        case gapThresholdSeconds
        case perLogOutput
        case deliveryDestinationMarkerStyle
        case restaurantOriginMarkerStyle
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
        maxLogs = try container.decodeIfPresent(Int.self, forKey: .maxLogs) ?? Self.defaultConfig.maxLogs
        gapThresholdSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .gapThresholdSeconds) ?? Self.defaultConfig.gapThresholdSeconds
        perLogOutput = try container.decodeIfPresent(Bool.self, forKey: .perLogOutput) ?? Self.defaultConfig.perLogOutput
        deliveryDestinationMarkerStyle = try container.decodeIfPresent(MarkerStyle.self, forKey: .deliveryDestinationMarkerStyle) ?? Self.defaultConfig.deliveryDestinationMarkerStyle
        restaurantOriginMarkerStyle = try container.decodeIfPresent(MarkerStyle.self, forKey: .restaurantOriginMarkerStyle) ?? Self.defaultConfig.restaurantOriginMarkerStyle
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

    /// Whether verbose output is enabled (debug log level)
    public var isVerbose: Bool {
        logLevel == .debug
    }

    // MARK: - Enrichment Query Configuration

    /// Service name for delivery order logs (different from driver service)
    public static let deliveryOrderService = "delivery-order-service"

    /// Builds the DataDog query string for GetDeliveryOrder logs.
    ///
    /// Query format: `env:<datadogEnv> @orderId:<uuid> service:delivery-order-service "handled request for GetDeliveryOrder"`
    ///
    /// - Parameter orderId: The order UUID to filter by
    /// - Returns: DataDog query string for order enrichment logs
    public func buildDeliveryOrderQuery(orderId: UUID) -> String {
        "env:\(datadogEnv) @orderId:\(orderId.uuidString.lowercased()) service:\(Self.deliveryOrderService) \"handled request for GetDeliveryOrder\""
    }

    /// Builds the DataDog query string for GetLocationsDetails logs.
    ///
    /// Query format: `env:<datadogEnv> service:<datadogService> "handled request for GetLocationsDetails"`
    ///
    /// Note: This query does not include tripId because GetLocationsDetails
    /// uses location_number as input, not tripId.
    ///
    /// - Returns: DataDog query string for restaurant location logs
    public func buildLocationsDetailsQuery() -> String {
        "env:\(datadogEnv) service:\(datadogService) \"handled request for GetLocationsDetails\""
    }

    /// Builds the DataDog query string for GetLocationsDetails logs filtered by location number.
    ///
    /// - Parameter locationNumber: The 5-digit location identifier
    /// - Returns: DataDog query string for specific restaurant location
    public func buildLocationsDetailsQuery(locationNumber: String) -> String {
        "env:\(datadogEnv) service:\(datadogService) \"handled request for GetLocationsDetails\" @response.Msg.locations.location_number:\(locationNumber)"
    }

    /// Builds the DataDog query string for OrderOutForDelivery logs.
    ///
    /// Query format: `env:<datadogEnv> service:delivery-order-service @cfadEventName:OrderOutForDelivery @orderId:<uuid>`
    ///
    /// This is a fallback query used when GetDeliveryOrder logs are unavailable.
    /// The OutForDelivery logs contain delivery address in `order.DeliveryAddress`.
    ///
    /// - Parameter orderId: The order UUID to filter by
    /// - Returns: DataDog query string for out-for-delivery logs
    public func buildOutForDeliveryQuery(orderId: UUID) -> String {
        "env:\(datadogEnv) service:\(Self.deliveryOrderService) @cfadEventName:OrderOutForDelivery @orderId:\(orderId.uuidString.lowercased())"
    }
}
