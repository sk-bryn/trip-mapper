import Foundation

/// Status indicators for enrichment data availability.
///
/// EnrichmentStatus is always included in map-data.json exports to indicate
/// whether order and location enrichment data was successfully retrieved,
/// regardless of whether the enrichment succeeded or failed.
///
/// This enables consumers of the export to:
/// - Understand if enrichment was attempted
/// - Know what data is available vs unavailable
/// - Make decisions based on data completeness
public struct EnrichmentStatus: Codable, Equatable, Sendable {

    // MARK: - Properties

    /// True if at least one order's delivery address was found.
    ///
    /// When `true`, the `deliveryDestinations` array in the export will
    /// contain at least one entry with address information.
    /// When `false`, no delivery address data was retrieved (but orderIds
    /// may still be present in route waypoints).
    public let orderDataFound: Bool

    /// True if restaurant location was found.
    ///
    /// When `true`, the `restaurantLocation` field in the export will
    /// contain restaurant name, address, and coordinates.
    /// When `false`, no restaurant location data was retrieved.
    public let locationDataFound: Bool

    // MARK: - Initialization

    /// Creates a new enrichment status.
    ///
    /// - Parameters:
    ///   - orderDataFound: Whether order delivery address data was found
    ///   - locationDataFound: Whether restaurant location data was found
    public init(orderDataFound: Bool, locationDataFound: Bool) {
        self.orderDataFound = orderDataFound
        self.locationDataFound = locationDataFound
    }

    // MARK: - Factory Methods

    /// Creates a status indicating no enrichment data was found.
    public static let noDataFound = EnrichmentStatus(
        orderDataFound: false,
        locationDataFound: false
    )

    /// Creates a status indicating all enrichment data was found.
    public static let allDataFound = EnrichmentStatus(
        orderDataFound: true,
        locationDataFound: true
    )

    // MARK: - Computed Properties

    /// Returns true if any enrichment data was found.
    public var hasAnyData: Bool {
        orderDataFound || locationDataFound
    }

    /// Returns true if all enrichment data was found.
    public var hasAllData: Bool {
        orderDataFound && locationDataFound
    }

    /// Returns a human-readable summary of the enrichment status.
    public var summary: String {
        switch (orderDataFound, locationDataFound) {
        case (true, true):
            return "All enrichment data available"
        case (true, false):
            return "Order data available, restaurant location unavailable"
        case (false, true):
            return "Restaurant location available, order data unavailable"
        case (false, false):
            return "No enrichment data available"
        }
    }
}
