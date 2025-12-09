import Foundation

/// Visual style configuration for map markers.
///
/// MarkerStyle defines the icon and color used to render markers
/// on trip visualizations, enabling distinct visual representation
/// for different marker types (delivery destinations, restaurant origins, etc.).
public struct MarkerStyle: Codable, Equatable, Sendable {

    // MARK: - Properties

    /// Icon identifier (e.g., "home", "restaurant", "circle")
    ///
    /// Used in Google Maps marker rendering. Common values:
    /// - "home": House icon for delivery destinations
    /// - "restaurant": Utensils icon for restaurant origins
    /// - "circle": Generic circular marker
    public let icon: String

    /// Hex color without # prefix (e.g., "9900FF")
    ///
    /// Must be a valid 6-character hex color code.
    /// Used for marker fill color in map rendering.
    public let color: String

    // MARK: - Initialization

    /// Creates a new marker style configuration.
    ///
    /// - Parameters:
    ///   - icon: Icon identifier for the marker
    ///   - color: Hex color code without # prefix (6 characters)
    public init(icon: String, color: String) {
        self.icon = icon
        self.color = color
    }

    // MARK: - Default Styles

    /// Default style for delivery destination markers.
    ///
    /// Uses a home icon with purple color (#9900FF) to distinguish
    /// intended delivery locations from route waypoints.
    public static let defaultDeliveryDestination = MarkerStyle(
        icon: "home",
        color: "9900FF"
    )

    /// Default style for restaurant origin markers.
    ///
    /// Uses a restaurant icon with blue color (#0066FF) to mark
    /// the trip starting point.
    public static let defaultRestaurantOrigin = MarkerStyle(
        icon: "restaurant",
        color: "0066FF"
    )

    // MARK: - Validation

    /// Validates the color is a valid 6-character hex string.
    ///
    /// - Returns: `true` if color is valid hex format, `false` otherwise
    public var isValidColor: Bool {
        guard color.count == 6 else { return false }
        return color.allSatisfy { $0.isHexDigit }
    }

    /// Returns the color with # prefix for CSS/HTML usage.
    public var cssColor: String {
        "#\(color)"
    }

    /// Returns the color with 0x prefix for URL encoding.
    public var urlColor: String {
        "0x\(color)"
    }
}
