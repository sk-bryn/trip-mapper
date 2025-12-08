import Foundation

/// Client for interacting with DataDog Logs Search API v2
///
/// Handles authentication, query construction, and response parsing
/// for fetching trip route logs from DataDog.
public final class DataDogClient {

    // MARK: - Properties

    /// DataDog API key for authentication
    private let apiKey: String

    /// DataDog Application key for authentication
    private let appKey: String

    /// Configuration containing DataDog settings
    private let configuration: Configuration

    /// URL session for making requests
    private let session: URLSession

    // MARK: - Constants

    private static let searchEndpoint = "/api/v2/logs/events/search"
    public static let defaultLimit = 10

    // MARK: - Initialization

    /// Creates a new DataDog client
    /// - Parameters:
    ///   - apiKey: DataDog API key
    ///   - appKey: DataDog Application key
    ///   - configuration: Configuration with DataDog settings
    ///   - session: URL session for requests (default: shared)
    public init(
        apiKey: String,
        appKey: String,
        configuration: Configuration,
        session: URLSession = .shared
    ) {
        self.apiKey = apiKey
        self.appKey = appKey
        self.configuration = configuration
        self.session = session
    }

    // MARK: - Public Methods

    /// Fetches ALL log entries for a specific trip (up to limit).
    ///
    /// This method returns all matching log entries sorted by timestamp ascending,
    /// unlike `fetchLogs` which may return only the most recent.
    ///
    /// - Parameters:
    ///   - tripId: The trip UUID to search for
    ///   - limit: Maximum logs to return (default: 50, max: 100)
    /// - Returns: Array of DataDogLogEntry sorted by timestamp ascending
    /// - Throws: `TripVisualizerError` on failure
    public func fetchAllLogs(tripId: UUID, limit: Int? = nil) async throws -> [DataDogLogEntry] {
        let effectiveLimit = min(limit ?? configuration.maxFragments, 100)

        // Validate credentials
        guard !apiKey.isEmpty else {
            throw TripVisualizerError.missingEnvironmentVariable("DD_API_KEY")
        }
        guard !appKey.isEmpty else {
            throw TripVisualizerError.missingEnvironmentVariable("DD_APP_KEY")
        }

        let request = try buildSearchRequest(tripId: tripId, limit: effectiveLimit)

        let response = try await RetryHandler.withRetry(
            retryCount: configuration.retryAttempts
        ) {
            let (data, response) = try await performRequest(request)
            try validateResponse(response)
            return try parseResponse(data)
        }

        // Sort by timestamp ascending (oldest first)
        return response.data.sorted { entry1, entry2 in
            entry1.attributes.timestamp < entry2.attributes.timestamp
        }
    }

    /// Fetches log entries for a specific trip
    /// - Parameter tripId: The trip UUID to search for
    /// - Returns: DataDog log response containing matching entries
    /// - Throws: `TripVisualizerError` on failure
    public func fetchLogs(tripId: UUID) async throws -> DataDogLogResponse {
        // Validate credentials
        guard !apiKey.isEmpty else {
            throw TripVisualizerError.missingEnvironmentVariable("DD_API_KEY")
        }
        guard !appKey.isEmpty else {
            throw TripVisualizerError.missingEnvironmentVariable("DD_APP_KEY")
        }

        let request = try buildSearchRequest(tripId: tripId)

        // Use retry handler for transient failures
        return try await RetryHandler.withRetry(
            retryCount: configuration.retryAttempts
        ) {
            let (data, response) = try await performRequest(request)
            try validateResponse(response)
            return try parseResponse(data)
        }
    }

    /// Builds the search request for a trip
    /// - Parameters:
    ///   - tripId: The trip UUID to search for
    ///   - limit: Maximum number of logs to return (default: 10)
    /// - Returns: Configured URLRequest
    public func buildSearchRequest(tripId: UUID, limit: Int = defaultLimit) throws -> URLRequest {
        let urlString = configuration.datadogAPIURL + Self.searchEndpoint
        guard let url = URL(string: urlString) else {
            throw TripVisualizerError.networkUnreachable("Invalid DataDog API URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "DD-API-KEY")
        request.setValue(appKey, forHTTPHeaderField: "DD-APPLICATION-KEY")

        let query = configuration.buildDatadogQuery(tripId: tripId)
        let body: [String: Any] = [
            "filter": [
                "query": query,
                "from": "now-30d",
                "to": "now"
            ],
            "sort": "timestamp",
            "page": [
                "limit": limit
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    /// Parses the DataDog response data
    /// - Parameter data: Raw response data
    /// - Returns: Parsed DataDogLogResponse
    public func parseResponse(_ data: Data) throws -> DataDogLogResponse {
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(DataDogLogResponse.self, from: data)
        } catch {
            logDebug("Failed to parse DataDog response: \(error)")
            throw TripVisualizerError.noRouteData
        }
    }

    /// Generates a link to view the log in DataDog UI
    /// - Parameter logId: The log entry ID
    /// - Returns: URL to view the log in DataDog
    public func generateLogLink(logId: String) -> String {
        let baseURL: String
        switch configuration.datadogRegion.lowercased() {
        case "eu":
            baseURL = "https://app.datadoghq.eu"
        case "us3":
            baseURL = "https://us3.datadoghq.com"
        case "us5":
            baseURL = "https://us5.datadoghq.com"
        case "gov":
            baseURL = "https://app.ddog-gov.com"
        default:
            baseURL = "https://app.datadoghq.com"
        }
        return "\(baseURL)/logs?query=@id:\(logId)"
    }

    // MARK: - Private Methods

    private func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost:
                throw TripVisualizerError.networkUnreachable(error.localizedDescription)
            case .timedOut:
                throw TripVisualizerError.networkTimeout
            default:
                throw TripVisualizerError.networkUnreachable(error.localizedDescription)
            }
        }
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TripVisualizerError.networkUnreachable("Invalid response type")
        }

        switch httpResponse.statusCode {
        case 200...299:
            return // Success
        case 401, 403:
            throw TripVisualizerError.httpError(
                statusCode: httpResponse.statusCode,
                message: "Authentication failed. Check DD_API_KEY and DD_APP_KEY."
            )
        case 429:
            throw TripVisualizerError.rateLimitExceeded
        case 500...599:
            throw TripVisualizerError.httpError(
                statusCode: httpResponse.statusCode,
                message: "DataDog server error"
            )
        default:
            throw TripVisualizerError.httpError(
                statusCode: httpResponse.statusCode,
                message: "Unexpected HTTP status"
            )
        }
    }
}
