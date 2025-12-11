import Foundation

/// Protocol for enrichment data fetching operations.
///
/// Defines the interface for fetching delivery addresses and restaurant
/// locations from DataDog logs. Implementations can be swapped for testing.
public protocol EnrichmentFetching: Sendable {

    /// Fetches delivery destination for an order.
    ///
    /// - Parameter orderId: The order UUID
    /// - Returns: DeliveryDestination or nil if not found
    func fetchDeliveryDestination(
        orderId: UUID
    ) async throws -> DeliveryDestination?

    /// Fetches restaurant location by location number.
    ///
    /// - Parameter locationNumber: 5-digit location identifier
    /// - Returns: RestaurantLocation or nil if not found
    func fetchRestaurantLocation(
        locationNumber: String
    ) async throws -> RestaurantLocation?

    /// Fetches all enrichment data for a trip.
    ///
    /// - Parameters:
    ///   - orderIds: Array of order UUIDs to enrich
    ///   - locationNumber: Restaurant location number (optional)
    /// - Returns: Combined enrichment result
    func fetchEnrichmentData(
        orderIds: [UUID],
        locationNumber: String?
    ) async -> EnrichmentResult
}

/// Service for fetching order and location enrichment data from DataDog.
///
/// EnrichmentService queries DataDog for GetDeliveryOrder and GetLocationsDetails
/// logs to retrieve delivery addresses and restaurant location data for trip
/// visualizations.
///
/// Features:
/// - Parallel fetching for minimal latency
/// - Graceful degradation when data is unavailable
/// - Warning aggregation for failed lookups
public final class EnrichmentService: EnrichmentFetching, @unchecked Sendable {

    // MARK: - Properties

    /// DataDog client for fetching logs
    private let dataDogClient: DataDogClient

    /// Configuration settings
    private let configuration: Configuration

    // MARK: - Initialization

    /// Creates a new enrichment service.
    ///
    /// - Parameters:
    ///   - dataDogClient: DataDog client for log queries
    ///   - configuration: Configuration settings
    public init(dataDogClient: DataDogClient, configuration: Configuration) {
        self.dataDogClient = dataDogClient
        self.configuration = configuration
    }

    // MARK: - EnrichmentFetching

    /// Fetches delivery destination for an order.
    ///
    /// Queries DataDog for GetDeliveryOrder logs first. If not found,
    /// falls back to OrderOutForDelivery logs which contain the same
    /// delivery address information in a different structure.
    ///
    /// - Parameter orderId: The order UUID
    /// - Returns: DeliveryDestination or nil if not found
    public func fetchDeliveryDestination(
        orderId: UUID
    ) async throws -> DeliveryDestination? {
        // First try: Fetch delivery order logs (GetDeliveryOrder)
        let deliveryOrderLogs = try await dataDogClient.fetchDeliveryOrderLogs(orderId: orderId)

        // Parse the first matching log from GetDeliveryOrder
        for log in deliveryOrderLogs {
            if let destination = parseDeliveryDestination(from: log) {
                logDebug("Found delivery destination from GetDeliveryOrder log for order \(orderId.uuidString)")
                return destination
            }
        }

        // Fallback: Try OutForDelivery logs
        logDebug("GetDeliveryOrder logs not found for order \(orderId.uuidString), trying OutForDelivery fallback")
        let outForDeliveryLogs = try await dataDogClient.fetchOutForDeliveryLogs(orderId: orderId)

        for log in outForDeliveryLogs {
            if let destination = parseOutForDeliveryDestination(from: log) {
                logDebug("Found delivery destination from OutForDelivery log for order \(orderId.uuidString)")
                return destination
            }
        }

        return nil
    }

    /// Fetches restaurant location by location number.
    ///
    /// Queries DataDog for GetLocationsDetails logs and extracts the
    /// restaurant name, address, and coordinates.
    ///
    /// - Parameter locationNumber: 5-digit location identifier
    /// - Returns: RestaurantLocation or nil if not found
    public func fetchRestaurantLocation(
        locationNumber: String
    ) async throws -> RestaurantLocation? {
        // Fetch location details logs filtered by location number
        let logs = try await dataDogClient.fetchLocationDetailsLogs(
            locationNumber: locationNumber,
            limit: 10
        )

        // Find and parse the first matching location
        for log in logs {
            if let location = parseRestaurantLocation(from: log, locationNumber: locationNumber) {
                return location
            }
        }

        return nil
    }

    /// Fetches all enrichment data for a trip.
    ///
    /// Performs parallel fetching of delivery destinations and restaurant
    /// location, with graceful degradation for failures.
    ///
    /// - Parameters:
    ///   - orderIds: Array of order UUIDs to enrich
    ///   - locationNumber: Restaurant location number (optional)
    /// - Returns: Combined enrichment result with status and warnings
    public func fetchEnrichmentData(
        orderIds: [UUID],
        locationNumber: String?
    ) async -> EnrichmentResult {
        // Return empty if no enrichment data requested
        guard !orderIds.isEmpty || locationNumber != nil else {
            return .empty
        }

        // Fetch delivery destinations and restaurant location sequentially
        // to avoid Swift concurrency memory issues with async let closures
        let (destinations, deliveryWarnings) = await fetchDeliveryDestinations(
            orderIds: orderIds
        )

        var restaurant: RestaurantLocation? = nil
        var locationWarnings: [String] = []
        if let locNumber = locationNumber {
            (restaurant, locationWarnings) = await fetchRestaurantLocationWithWarnings(locationNumber: locNumber)
        }

        // Combine warnings
        var allWarnings: [String] = []
        allWarnings.append(contentsOf: deliveryWarnings)
        allWarnings.append(contentsOf: locationWarnings)

        // Determine status
        let orderDataFound = !destinations.isEmpty
        let locationDataFound = restaurant != nil
        let status = EnrichmentStatus(
            orderDataFound: orderDataFound,
            locationDataFound: locationDataFound
        )

        return EnrichmentResult(
            restaurantLocation: restaurant,
            deliveryDestinations: destinations,
            status: status,
            warnings: allWarnings
        )
    }

    // MARK: - Internal Parsing Methods (to be implemented)

    /// Parses a DeliveryDestination from a DataDog log entry.
    ///
    /// Extracts order data from the response.Msg.order structure in the log.
    /// Expected structure:
    /// ```
    /// {
    ///   "response": {
    ///     "Msg": {
    ///       "order": {
    ///         "order_id": "uuid-string",
    ///         "coordinates": { "latitude": 33.7490, "longitude": -84.3880 },
    ///         "address": "123 Main St, Atlanta, GA 30301",
    ///         "address_display_line1": "123 Main St",
    ///         "address_display_line2": "Atlanta, GA 30301",
    ///         "destination_place_id": "ChIJ8dI_QZfV2IcRlfqLN6T4Ru4"
    ///       }
    ///     }
    ///   }
    /// }
    /// ```
    ///
    /// - Parameter logEntry: DataDog log entry containing order data
    /// - Returns: DeliveryDestination or nil if parsing fails
    func parseDeliveryDestination(from logEntry: DataDogLogEntry) -> DeliveryDestination? {
        // Extract response.Msg.order from log attributes
        guard let response = logEntry.attributes.attributes["response"] as? [String: Any],
              let msg = response["Msg"] as? [String: Any],
              let orderData = msg["order"] as? [String: Any]
        else {
            return nil
        }

        // Extract order ID (snake_case in response)
        guard let orderIdString = orderData["order_id"] as? String,
              let orderId = UUID(uuidString: orderIdString)
        else {
            return nil
        }

        // Use the DeliveryDestination factory method
        return DeliveryDestination.from(orderId: orderId, orderResponse: orderData)
    }

    /// Parses a DeliveryDestination from an OrderOutForDelivery log entry.
    ///
    /// This is a fallback parser for when GetDeliveryOrder logs are unavailable.
    /// Extracts order data from the `order` attribute in the log.
    /// Expected structure:
    /// ```
    /// {
    ///   "order": {
    ///     "OrderID": "uuid-string",
    ///     "Latitude": 36.0934931,
    ///     "Longitude": -80.0342805,
    ///     "DeliveryAddress": {
    ///       "AddressLine1": "1014 Grays Land Court",
    ///       "AddressLine2": "Apt. 315",
    ///       "AddressLine3": "Hand-off at door; Building 300, Apt 315",
    ///       "City": "Kernersville",
    ///       "State": "NC",
    ///       "Zip": "27284"
    ///     },
    ///     "DropOffInstructions": "Hand-off at door; Building 300, Apt 315",
    ///     "DestinationPlaceID": "Ek..."
    ///   }
    /// }
    /// ```
    ///
    /// - Parameter logEntry: DataDog log entry containing OutForDelivery order data
    /// - Returns: DeliveryDestination or nil if parsing fails
    func parseOutForDeliveryDestination(from logEntry: DataDogLogEntry) -> DeliveryDestination? {
        // Extract order from log attributes (OutForDelivery uses PascalCase)
        guard let orderData = logEntry.attributes.attributes["order"] as? [String: Any] else {
            return nil
        }

        // Extract order ID (PascalCase in OutForDelivery logs)
        guard let orderIdString = orderData["OrderID"] as? String,
              let orderId = UUID(uuidString: orderIdString)
        else {
            return nil
        }

        // Extract coordinates (top-level in order, PascalCase)
        guard let latitude = orderData["Latitude"] as? Double ?? (orderData["Latitude"] as? Float).map(Double.init),
              let longitude = orderData["Longitude"] as? Double ?? (orderData["Longitude"] as? Float).map(Double.init)
        else {
            return nil
        }

        // Extract delivery address (PascalCase structure)
        let deliveryAddress = orderData["DeliveryAddress"] as? [String: Any] ?? [:]
        let addressLine1 = deliveryAddress["AddressLine1"] as? String ?? ""
        let addressLine2 = deliveryAddress["AddressLine2"] as? String ?? ""
        let city = deliveryAddress["City"] as? String ?? ""
        let state = deliveryAddress["State"] as? String ?? ""
        let zip = deliveryAddress["Zip"] as? String ?? ""

        // Build full address string
        var addressParts: [String] = []
        if !addressLine1.isEmpty { addressParts.append(addressLine1) }
        if !addressLine2.isEmpty { addressParts.append(addressLine2) }
        if !city.isEmpty || !state.isEmpty || !zip.isEmpty {
            addressParts.append("\(city), \(state) \(zip)")
        }
        let fullAddress = addressParts.joined(separator: ", ")

        // Build display lines
        var displayLine1 = addressLine1
        if !addressLine2.isEmpty {
            displayLine1 += ", \(addressLine2)"
        }
        let displayLine2 = "\(city), \(state) \(zip)"

        // Extract optional fields
        let dropoffInstructions = orderData["DropOffInstructions"] as? String
        let destinationPlaceId = orderData["DestinationPlaceID"] as? String

        return DeliveryDestination(
            orderId: orderId,
            address: fullAddress,
            addressDisplayLine1: displayLine1,
            addressDisplayLine2: displayLine2,
            latitude: latitude,
            longitude: longitude,
            dropoffInstructions: dropoffInstructions,
            destinationPlaceId: destinationPlaceId
        )
    }

    /// Parses a RestaurantLocation from a DataDog log entry.
    ///
    /// Extracts location data from the response.Msg.locations array in the log.
    /// Expected structure:
    /// ```
    /// {
    ///   "response": {
    ///     "Msg": {
    ///       "locations": [
    ///         {
    ///           "location_number": "00070",
    ///           "name": "West Columbia",
    ///           "coordinates": { "latitude": 33.98325, "longitude": -81.096 },
    ///           "address": {
    ///             "address1": "2299 Augusta Rd",
    ///             "address2": "Suite 100",
    ///             "city": "West Columbia",
    ///             "state": "SC",
    ///             "zip": "29169"
    ///           },
    ///           "operator_name": "John Smith",
    ///           "time_zone": "America/New_York"
    ///         }
    ///       ]
    ///     }
    ///   }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - logEntry: DataDog log entry containing location data
    ///   - locationNumber: Target location number to match
    /// - Returns: RestaurantLocation or nil if not found or parsing fails
    func parseRestaurantLocation(from logEntry: DataDogLogEntry, locationNumber: String) -> RestaurantLocation? {
        // Extract response.Msg.locations from log attributes
        guard let response = logEntry.attributes.attributes["response"] as? [String: Any],
              let msg = response["Msg"] as? [String: Any],
              let locations = msg["locations"] as? [[String: Any]]
        else {
            return nil
        }

        // Find the location matching the requested location number
        // Try both snake_case and camelCase for location_number
        for locationData in locations {
            let locNumber = locationData["location_number"] as? String
                ?? locationData["locationNumber"] as? String
            guard locNumber == locationNumber else {
                continue
            }

            // Use the RestaurantLocation factory method
            return RestaurantLocation.from(locationData: locationData)
        }

        return nil
    }

    // MARK: - Delivery Destination Methods

    /// Fetches all delivery destinations for the given order IDs.
    ///
    /// Queries DataDog for each order ID individually. Missing orders generate
    /// warnings but don't fail the entire operation.
    ///
    /// - Parameter orderIds: Array of order UUIDs to look up
    /// - Returns: Tuple of (found destinations, warnings)
    func fetchDeliveryDestinations(
        orderIds: [UUID]
    ) async -> ([DeliveryDestination], [String]) {
        guard !orderIds.isEmpty else {
            return ([], [])
        }

        var destinations: [DeliveryDestination] = []
        var warnings: [String] = []

        // Fetch each order individually
        for orderId in orderIds {
            do {
                if let destination = try await fetchDeliveryDestination(orderId: orderId) {
                    destinations.append(destination)
                } else {
                    // FR-010: Log warning when orderId lookup fails
                    let warning = "Delivery address unavailable for order \(orderId.uuidString)"
                    warnings.append(warning)
                    logWarning(warning)
                }
            } catch {
                // FR-009: Graceful degradation - add warning but don't fail
                let warning = "Failed to fetch delivery order for \(orderId.uuidString): \(error.localizedDescription)"
                warnings.append(warning)
                logWarning(warning)
            }
        }

        return (destinations, warnings)
    }

    // MARK: - Restaurant Location Methods

    /// Fetches restaurant location with graceful degradation.
    ///
    /// Queries DataDog for GetLocationsDetails logs and extracts the
    /// restaurant data. Network failures and missing data generate
    /// warnings but don't fail the operation.
    ///
    /// - Parameter locationNumber: 5-digit location identifier
    /// - Returns: Tuple of (location or nil, warnings)
    func fetchRestaurantLocationWithWarnings(
        locationNumber: String
    ) async -> (RestaurantLocation?, [String]) {
        var warnings: [String] = []

        do {
            let location = try await fetchRestaurantLocation(locationNumber: locationNumber)

            if location == nil {
                // FR-010: Log warning when location_number lookup fails
                let warning = "Restaurant location unavailable for location number \(locationNumber)"
                warnings.append(warning)
                logWarning(warning)
            }

            return (location, warnings)
        } catch {
            // FR-009: Graceful degradation - add warning but don't fail
            let warning = "Failed to fetch restaurant location: \(error.localizedDescription)"
            warnings.append(warning)
            logWarning(warning)
            return (nil, warnings)
        }
    }
}
