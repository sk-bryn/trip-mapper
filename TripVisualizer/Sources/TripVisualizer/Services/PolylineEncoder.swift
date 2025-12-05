import Foundation

/// Encoder/decoder for Google's Polyline Algorithm
///
/// Implements the polyline encoding algorithm as specified at:
/// https://developers.google.com/maps/documentation/utilities/polylinealgorithm
///
/// The algorithm compresses a sequence of coordinates into a compact ASCII string
/// by encoding deltas between consecutive points using a variable-length encoding.
public final class PolylineEncoder {

    // MARK: - Constants

    /// Precision factor for coordinate encoding (5 decimal places)
    private static let precision: Double = 1e5

    // MARK: - Initialization

    public init() {}

    // MARK: - Encoding

    /// Encodes an array of waypoints into a polyline string
    /// - Parameter waypoints: Array of waypoints to encode
    /// - Returns: Encoded polyline string
    public func encode(_ waypoints: [Waypoint]) -> String {
        guard !waypoints.isEmpty else { return "" }

        var result = ""
        var previousLatitude: Int = 0
        var previousLongitude: Int = 0

        for waypoint in waypoints {
            // Scale coordinates to integer values
            let latitude = Int(round(waypoint.latitude * Self.precision))
            let longitude = Int(round(waypoint.longitude * Self.precision))

            // Encode delta from previous point
            result += encodeSignedNumber(latitude - previousLatitude)
            result += encodeSignedNumber(longitude - previousLongitude)

            previousLatitude = latitude
            previousLongitude = longitude
        }

        return result
    }

    // MARK: - Decoding

    /// Decodes a polyline string into an array of waypoints
    /// - Parameter polyline: Encoded polyline string
    /// - Returns: Array of decoded waypoints
    public func decode(_ polyline: String) -> [Waypoint] {
        guard !polyline.isEmpty else { return [] }

        var waypoints: [Waypoint] = []
        var index = polyline.startIndex
        var latitude: Int = 0
        var longitude: Int = 0

        while index < polyline.endIndex {
            // Decode latitude delta
            let (latDelta, nextIndex1) = decodeSignedNumber(from: polyline, startingAt: index)
            index = nextIndex1
            latitude += latDelta

            // Decode longitude delta
            let (lngDelta, nextIndex2) = decodeSignedNumber(from: polyline, startingAt: index)
            index = nextIndex2
            longitude += lngDelta

            // Convert back to coordinates
            let lat = Double(latitude) / Self.precision
            let lng = Double(longitude) / Self.precision

            waypoints.append(Waypoint(latitude: lat, longitude: lng))
        }

        return waypoints
    }

    // MARK: - Private Methods

    /// Encodes a signed integer using Google's polyline encoding
    /// - Parameter value: Signed integer to encode
    /// - Returns: Encoded ASCII string
    private func encodeSignedNumber(_ value: Int) -> String {
        // Left-shift value by 1 bit
        // If negative, invert all bits
        var encoded = value << 1
        if value < 0 {
            encoded = ~encoded
        }

        return encodeUnsignedNumber(encoded)
    }

    /// Encodes an unsigned integer using variable-length encoding
    /// - Parameter value: Unsigned integer to encode
    /// - Returns: Encoded ASCII string
    private func encodeUnsignedNumber(_ value: Int) -> String {
        var result = ""
        var remaining = value

        repeat {
            // Take 5 bits at a time
            var chunk = remaining & 0x1F
            remaining >>= 5

            // If there are more bits, set the continuation bit
            if remaining > 0 {
                chunk |= 0x20
            }

            // Add 63 to get printable ASCII character
            result.append(Character(UnicodeScalar(chunk + 63)!))
        } while remaining > 0

        return result
    }

    /// Decodes a signed number from the polyline string
    /// - Parameters:
    ///   - polyline: The polyline string
    ///   - startIndex: Index to start decoding from
    /// - Returns: Tuple of (decoded value, next index)
    private func decodeSignedNumber(
        from polyline: String,
        startingAt startIndex: String.Index
    ) -> (Int, String.Index) {
        var result = 0
        var shift = 0
        var index = startIndex

        while index < polyline.endIndex {
            // Get ASCII value and subtract 63
            let char = polyline[index]
            let value = Int(char.asciiValue!) - 63

            // Extract 5 bits and add to result
            result |= (value & 0x1F) << shift
            shift += 5

            // Move to next character
            index = polyline.index(after: index)

            // Check if this is the last chunk (no continuation bit)
            if value < 0x20 {
                break
            }
        }

        // Decode sign: if last bit is 1, the number is negative
        if result & 1 != 0 {
            result = ~(result >> 1)
        } else {
            result >>= 1
        }

        return (result, index)
    }
}
