import Foundation

/// Restaurant location data for a trip origin.
///
/// Contains the restaurant details extracted from GetLocationsDetails
/// DataDog logs. Used to display the restaurant origin marker on trip
/// visualizations and included in map-data.json exports.
///
/// Key entities from spec:
/// - location_number: 5-digit identifier
/// - name: Restaurant name
/// - Address components (address1, address2, city, state, zip)
/// - Coordinates (latitude, longitude)
/// - Operator name, time zone (optional)
public struct RestaurantLocation: Codable, Equatable, Sendable {

    // MARK: - Properties

    /// 5-digit location identifier.
    ///
    /// Example: "00070"
    public let locationNumber: String

    /// Restaurant name.
    ///
    /// Example: "West Columbia"
    public let name: String

    /// Street address line 1.
    ///
    /// Example: "2299 Augusta Rd"
    public let address1: String

    /// Street address line 2 (suite, unit, etc.).
    ///
    /// Optional. Example: "Suite 100"
    public let address2: String?

    /// City name.
    ///
    /// Example: "West Columbia"
    public let city: String

    /// State code (2-letter).
    ///
    /// Example: "SC"
    public let state: String

    /// ZIP code.
    ///
    /// Example: "29169"
    public let zip: String

    /// Restaurant latitude.
    public let latitude: Double

    /// Restaurant longitude.
    public let longitude: Double

    /// Restaurant operator name.
    ///
    /// Optional. Example: "John Smith"
    public let operatorName: String?

    /// Time zone identifier.
    ///
    /// Optional. Example: "America/New_York"
    public let timeZone: String?

    // MARK: - Initialization

    /// Creates a new restaurant location.
    ///
    /// - Parameters:
    ///   - locationNumber: 5-digit location identifier
    ///   - name: Restaurant name
    ///   - address1: Street address line 1
    ///   - address2: Street address line 2 (optional)
    ///   - city: City name
    ///   - state: State code
    ///   - zip: ZIP code
    ///   - latitude: Restaurant latitude
    ///   - longitude: Restaurant longitude
    ///   - operatorName: Restaurant operator name (optional)
    ///   - timeZone: Time zone identifier (optional)
    public init(
        locationNumber: String,
        name: String,
        address1: String,
        address2: String?,
        city: String,
        state: String,
        zip: String,
        latitude: Double,
        longitude: Double,
        operatorName: String?,
        timeZone: String?
    ) {
        self.locationNumber = locationNumber
        self.name = name
        self.address1 = address1
        self.address2 = address2
        self.city = city
        self.state = state
        self.zip = zip
        self.latitude = latitude
        self.longitude = longitude
        self.operatorName = operatorName
        self.timeZone = timeZone
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
    /// Format: "address1, address2, city, state zip"
    /// or "address1, city, state zip" if no address2.
    public var formattedAddress: String {
        var parts = [address1]
        if let addr2 = address2, !addr2.isEmpty {
            parts.append(addr2)
        }
        parts.append("\(city), \(state) \(zip)")
        return parts.joined(separator: ", ")
    }

    /// Returns a short description for marker labels.
    ///
    /// Format: "name (locationNumber)"
    public var shortDescription: String {
        "\(name) (#\(locationNumber))"
    }

    /// Returns true if this is a valid location number format (5 digits).
    public var hasValidLocationNumber: Bool {
        locationNumber.count == 5 && locationNumber.allSatisfy { $0.isNumber }
    }

    // MARK: - Factory Methods

    /// Creates a restaurant location from GetLocationsDetails response data.
    ///
    /// Handles both snake_case (API response) and camelCase (legacy) field names:
    /// - `location_number` / `locationNumber`
    /// - `operator_name` / `operatorName`
    /// - `time_zone` / `timeZone`
    ///
    /// - Parameter locationData: Dictionary containing location response fields
    /// - Returns: RestaurantLocation or nil if required fields are missing
    public static func from(locationData: [String: Any]) -> RestaurantLocation? {
        // Extract required fields (try snake_case first, then camelCase)
        guard let locationNumber = locationData["location_number"] as? String
                ?? locationData["locationNumber"] as? String,
              let name = locationData["name"] as? String
        else {
            return nil
        }

        // Extract coordinates
        guard let coordinates = locationData["coordinates"] as? [String: Any],
              let latitude = coordinates["latitude"] as? Double ?? (coordinates["latitude"] as? Float).map(Double.init),
              let longitude = coordinates["longitude"] as? Double ?? (coordinates["longitude"] as? Float).map(Double.init)
        else {
            return nil
        }

        // Extract address components
        let address = locationData["address"] as? [String: Any] ?? [:]
        let address1 = address["address1"] as? String ?? ""
        let address2 = address["address2"] as? String
        let city = address["city"] as? String ?? ""
        let state = address["state"] as? String ?? ""
        let zip = address["zip"] as? String ?? ""

        // Extract optional fields (try snake_case first, then camelCase)
        let operatorName = locationData["operator_name"] as? String
            ?? locationData["operatorName"] as? String
        let timeZone = locationData["time_zone"] as? String
            ?? locationData["timeZone"] as? String

        return RestaurantLocation(
            locationNumber: locationNumber,
            name: name,
            address1: address1,
            address2: address2,
            city: city,
            state: state,
            zip: zip,
            latitude: latitude,
            longitude: longitude,
            operatorName: operatorName,
            timeZone: timeZone
        )
    }
}
