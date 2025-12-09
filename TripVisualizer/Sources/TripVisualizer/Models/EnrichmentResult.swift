import Foundation

/// Aggregated enrichment data for a trip visualization.
///
/// EnrichmentResult contains all additional location data fetched for a trip:
/// - Restaurant location (origin point)
/// - Delivery destinations (per-order addresses)
/// - Status flags indicating data availability
/// - Warning messages for failed lookups
///
/// This struct is used internally during visualization processing and
/// its data is included in the map-data.json export.
public struct EnrichmentResult: Codable, Equatable, Sendable {

    // MARK: - Properties

    /// Restaurant location where the trip originated.
    ///
    /// Nil if restaurant location could not be retrieved from
    /// GetLocationsDetails logs.
    public let restaurantLocation: RestaurantLocation?

    /// Delivery destinations for orders in this trip.
    ///
    /// May be empty (no orders found) or partial (some orders
    /// had unavailable address data). Each entry contains the
    /// intended delivery address, not actual route waypoints.
    public let deliveryDestinations: [DeliveryDestination]

    /// Status flags indicating what enrichment data was found.
    ///
    /// Always present, enabling consumers to know if enrichment
    /// was attempted and what data is available.
    public let status: EnrichmentStatus

    /// Warning messages for failed lookups.
    ///
    /// Contains descriptive messages for any enrichment failures,
    /// such as missing orderId data or location_number lookup failures.
    /// Empty if all enrichment succeeded.
    public let warnings: [String]

    // MARK: - Initialization

    /// Creates a new enrichment result.
    ///
    /// - Parameters:
    ///   - restaurantLocation: Restaurant location data (nil if not found)
    ///   - deliveryDestinations: Array of delivery destinations (may be empty)
    ///   - status: Enrichment status flags
    ///   - warnings: Warning messages for failed lookups
    public init(
        restaurantLocation: RestaurantLocation?,
        deliveryDestinations: [DeliveryDestination],
        status: EnrichmentStatus,
        warnings: [String]
    ) {
        self.restaurantLocation = restaurantLocation
        self.deliveryDestinations = deliveryDestinations
        self.status = status
        self.warnings = warnings
    }

    // MARK: - Factory Methods

    /// Creates an empty result for when enrichment is skipped or fails completely.
    ///
    /// Use this when enrichment cannot be performed at all, such as when
    /// no orderIds are present in the route data.
    public static var empty: EnrichmentResult {
        EnrichmentResult(
            restaurantLocation: nil,
            deliveryDestinations: [],
            status: EnrichmentStatus(orderDataFound: false, locationDataFound: false),
            warnings: []
        )
    }

    /// Creates a result with specific warnings when enrichment fails.
    ///
    /// - Parameter warnings: Warning messages describing the failures
    /// - Returns: Empty enrichment result with warnings
    public static func failed(with warnings: [String]) -> EnrichmentResult {
        EnrichmentResult(
            restaurantLocation: nil,
            deliveryDestinations: [],
            status: EnrichmentStatus(orderDataFound: false, locationDataFound: false),
            warnings: warnings
        )
    }

    // MARK: - Computed Properties

    /// Returns true if any enrichment data is available.
    public var hasData: Bool {
        status.hasAnyData
    }

    /// Returns true if there are any warnings.
    public var hasWarnings: Bool {
        !warnings.isEmpty
    }

    /// Returns the count of delivery destinations found.
    public var deliveryCount: Int {
        deliveryDestinations.count
    }

    /// Returns a summary string describing the enrichment result.
    public var summary: String {
        var parts: [String] = []

        if let restaurant = restaurantLocation {
            parts.append("Restaurant: \(restaurant.name)")
        }

        if !deliveryDestinations.isEmpty {
            parts.append("Deliveries: \(deliveryDestinations.count)")
        }

        if !warnings.isEmpty {
            parts.append("Warnings: \(warnings.count)")
        }

        if parts.isEmpty {
            return "No enrichment data"
        }

        return parts.joined(separator: ", ")
    }
}
