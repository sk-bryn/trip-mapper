import Foundation

/// A single point along a delivery route extracted from the `segment_coords` array.
///
/// Waypoints represent geographic coordinates along a driver's journey.
/// If `orderId` is present, the waypoint is part of a delivery to a customer.
/// If `orderId` is absent, the waypoint represents a return-to-restaurant segment.
public struct Waypoint: Codable, Equatable, Hashable {

    // MARK: - Properties

    /// Latitude coordinate (-90.0 to 90.0)
    public let latitude: Double

    /// Longitude coordinate (-180.0 to 180.0)
    public let longitude: Double

    /// Order being delivered during this segment. If nil, indicates return-to-restaurant.
    public let orderId: UUID?

    // MARK: - Initialization

    public init(latitude: Double, longitude: Double, orderId: UUID? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.orderId = orderId
    }

    // MARK: - Validation

    /// Validates if a latitude value is within the valid range (-90 to 90).
    public static func isValidLatitude(_ latitude: Double) -> Bool {
        latitude >= -90.0 && latitude <= 90.0
    }

    /// Validates if a longitude value is within the valid range (-180 to 180).
    public static func isValidLongitude(_ longitude: Double) -> Bool {
        longitude >= -180.0 && longitude <= 180.0
    }

    /// Returns true if both latitude and longitude are within valid ranges.
    public var isValid: Bool {
        Self.isValidLatitude(latitude) && Self.isValidLongitude(longitude)
    }

    // MARK: - Business Logic

    /// Returns true if this waypoint is part of a delivery (has an order ID).
    public var isDeliveryWaypoint: Bool {
        orderId != nil
    }

    /// Returns true if this waypoint represents a return-to-restaurant segment (no order ID).
    public var isReturnToRestaurant: Bool {
        orderId == nil
    }
}

// MARK: - CustomStringConvertible

extension Waypoint: CustomStringConvertible {
    public var description: String {
        let orderInfo = orderId.map { "order: \($0.uuidString.prefix(8))..." } ?? "return-to-restaurant"
        return "Waypoint(\(latitude), \(longitude), \(orderInfo))"
    }
}
