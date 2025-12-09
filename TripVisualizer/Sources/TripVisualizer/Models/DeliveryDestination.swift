import Foundation

/// Delivery destination data for an order.
///
/// Contains the delivery dropoff location extracted from GetDeliveryOrder
/// DataDog logs. Used to display intended delivery markers on trip visualizations
/// and included in map-data.json exports.
///
/// Key entities from spec:
/// - orderId: The order UUID
/// - Full address string
/// - Address display lines (for UI rendering)
/// - Coordinates (latitude, longitude)
/// - Dropoff instructions (optional)
/// - Destination place ID (Google Places ID for precise location lookup)
public struct DeliveryDestination: Codable, Equatable, Sendable {

    // MARK: - Properties

    /// The order UUID this destination belongs to.
    public let orderId: UUID

    /// Full concatenated address string.
    ///
    /// Example: "123 Main St, Apt #2, New York, NY, 10001"
    public let address: String

    /// First line of address for display.
    ///
    /// Example: "123 Main St, Apt #2"
    public let addressDisplayLine1: String

    /// Second line of address for display.
    ///
    /// Example: "New York, NY 10001"
    public let addressDisplayLine2: String

    /// Delivery destination latitude.
    public let latitude: Double

    /// Delivery destination longitude.
    public let longitude: Double

    /// Optional dropoff instructions from the customer.
    ///
    /// Example: "Leave at front door", "Ring doorbell twice"
    public let dropoffInstructions: String?

    /// Google Places ID for the destination.
    ///
    /// Used for precise location identification and can be used with
    /// Google Maps APIs for additional location details.
    public let destinationPlaceId: String?

    // MARK: - Initialization

    /// Creates a new delivery destination.
    ///
    /// - Parameters:
    ///   - orderId: The order UUID
    ///   - address: Full concatenated address string
    ///   - addressDisplayLine1: First line of address for display
    ///   - addressDisplayLine2: Second line of address for display
    ///   - latitude: Delivery destination latitude
    ///   - longitude: Delivery destination longitude
    ///   - dropoffInstructions: Optional dropoff instructions
    ///   - destinationPlaceId: Optional Google Places ID
    public init(
        orderId: UUID,
        address: String,
        addressDisplayLine1: String,
        addressDisplayLine2: String,
        latitude: Double,
        longitude: Double,
        dropoffInstructions: String?,
        destinationPlaceId: String? = nil
    ) {
        self.orderId = orderId
        self.address = address
        self.addressDisplayLine1 = addressDisplayLine1
        self.addressDisplayLine2 = addressDisplayLine2
        self.latitude = latitude
        self.longitude = longitude
        self.dropoffInstructions = dropoffInstructions
        self.destinationPlaceId = destinationPlaceId
    }

    // MARK: - Computed Properties

    /// Returns true if coordinates are within valid ranges.
    ///
    /// Valid ranges:
    /// - Latitude: -90 to 90
    /// - Longitude: -180 to 180
    public var hasValidCoordinates: Bool {
        latitude >= -90 && latitude <= 90 &&
        longitude >= -180 && longitude <= 180
    }

    /// Returns the formatted full address.
    ///
    /// Uses addressDisplayLine1 and addressDisplayLine2 if available,
    /// otherwise falls back to the full address string.
    public var formattedAddress: String {
        if !addressDisplayLine1.isEmpty && !addressDisplayLine2.isEmpty {
            return "\(addressDisplayLine1), \(addressDisplayLine2)"
        }
        return address
    }

    /// Returns a short description for marker labels.
    ///
    /// Uses the first line of the address if available,
    /// truncated to 30 characters.
    public var shortDescription: String {
        let text = addressDisplayLine1.isEmpty ? address : addressDisplayLine1
        if text.count > 30 {
            return String(text.prefix(27)) + "..."
        }
        return text
    }

    // MARK: - Factory Methods

    /// Creates a delivery destination from GetDeliveryOrder response data.
    ///
    /// Field names in the response use snake_case:
    /// - `address`, `address_display_line1`, `address_display_line2`
    /// - `coordinates.latitude`, `coordinates.longitude`
    /// - `destination_place_id`
    ///
    /// - Parameters:
    ///   - orderId: The order UUID
    ///   - orderResponse: Dictionary containing order response fields
    /// - Returns: DeliveryDestination or nil if required fields are missing
    public static func from(
        orderId: UUID,
        orderResponse: [String: Any]
    ) -> DeliveryDestination? {
        // Extract coordinates
        guard let coordinates = orderResponse["coordinates"] as? [String: Any],
              let latitude = coordinates["latitude"] as? Double ?? (coordinates["latitude"] as? Float).map(Double.init),
              let longitude = coordinates["longitude"] as? Double ?? (coordinates["longitude"] as? Float).map(Double.init)
        else {
            return nil
        }

        // Extract address fields (snake_case in response)
        let address = orderResponse["address"] as? String ?? ""
        let displayLine1 = orderResponse["address_display_line1"] as? String ?? ""
        let displayLine2 = orderResponse["address_display_line2"] as? String ?? ""
        let instructions = orderResponse["dropoff_instructions"] as? String
        let placeId = orderResponse["destination_place_id"] as? String

        return DeliveryDestination(
            orderId: orderId,
            address: address,
            addressDisplayLine1: displayLine1,
            addressDisplayLine2: displayLine2,
            latitude: latitude,
            longitude: longitude,
            dropoffInstructions: instructions,
            destinationPlaceId: placeId
        )
    }
}
