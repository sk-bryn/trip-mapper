import Foundation

/// Service for generating map visualizations from waypoints
///
/// Generates HTML files with interactive Google Maps, Static Maps URLs for PNG images,
/// and Google Maps web URLs for browser viewing.
public final class MapGenerator {

    // MARK: - Properties

    /// Google Maps API key
    private let apiKey: String

    /// Polyline encoder for path encoding
    private let polylineEncoder = PolylineEncoder()

    // MARK: - Constants

    private static let staticMapsBaseURL = "https://maps.googleapis.com/maps/api/staticmap"
    public static let defaultWidth = 640
    public static let defaultHeight = 480

    // MARK: - Initialization

    /// Creates a new map generator
    /// - Parameter apiKey: Google Maps API key
    public init(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: - HTML Generation

    /// Generates HTML content with interactive Google Map
    /// - Parameters:
    ///   - tripId: Trip UUID for the title
    ///   - waypoints: Array of waypoints to display
    /// - Returns: HTML string
    /// - Throws: `TripVisualizerError` if waypoints are empty
    public func generateHTML(tripId: UUID, waypoints: [Waypoint]) throws -> String {
        guard !waypoints.isEmpty else {
            throw TripVisualizerError.noRouteData
        }

        let coordsJSON = coordinatesToJSON(waypoints)

        return """
        <!DOCTYPE html>
        <html>
        <head>
          <title>Trip Route: \(tripId.uuidString)</title>
          <style>
            #map { height: 100vh; width: 100%; }
          </style>
        </head>
        <body>
          <div id="map"></div>
          <script>
            function initMap() {
              const coords = \(coordsJSON);
              const map = new google.maps.Map(document.getElementById("map"), {
                zoom: 12,
                center: coords[0]
              });

              const path = new google.maps.Polyline({
                path: coords,
                geodesic: true,
                strokeColor: "#0000FF",
                strokeWeight: 4
              });
              path.setMap(map);

              // Start marker
              new google.maps.Marker({
                position: coords[0],
                map: map,
                icon: "http://maps.google.com/mapfiles/ms/icons/green-dot.png",
                title: "Start"
              });

              // End marker
              new google.maps.Marker({
                position: coords[coords.length - 1],
                map: map,
                icon: "http://maps.google.com/mapfiles/ms/icons/red-dot.png",
                title: "End"
              });

              // Fit bounds
              const bounds = new google.maps.LatLngBounds();
              coords.forEach(c => bounds.extend(c));
              map.fitBounds(bounds);
            }
          </script>
          <script async defer
            src="https://maps.googleapis.com/maps/api/js?key=\(apiKey)&callback=initMap">
          </script>
        </body>
        </html>
        """
    }

    /// Writes HTML content to a file
    /// - Parameters:
    ///   - tripId: Trip UUID for the title
    ///   - waypoints: Array of waypoints to display
    ///   - path: Output file path
    /// - Throws: `TripVisualizerError` on file write failure
    public func writeHTML(tripId: UUID, waypoints: [Waypoint], to path: String) throws {
        let html = try generateHTML(tripId: tripId, waypoints: waypoints)

        do {
            try html.write(toFile: path, atomically: true, encoding: .utf8)
            logInfo("HTML map written to \(path)")
        } catch {
            throw TripVisualizerError.cannotWriteOutput(
                path: path,
                reason: error.localizedDescription
            )
        }
    }

    // MARK: - Static Maps URL Generation

    /// Generates a Google Static Maps API URL for PNG download
    /// - Parameters:
    ///   - waypoints: Array of waypoints to display
    ///   - width: Image width in pixels (default: 640)
    ///   - height: Image height in pixels (default: 480)
    /// - Returns: Static Maps URL or nil if waypoints are empty
    public func generateStaticMapsURL(
        waypoints: [Waypoint],
        width: Int = defaultWidth,
        height: Int = defaultHeight
    ) -> URL? {
        guard !waypoints.isEmpty else { return nil }

        var components = URLComponents(string: Self.staticMapsBaseURL)!

        let encodedPath = polylineEncoder.encode(waypoints)

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "size", value: "\(width)x\(height)"),
            URLQueryItem(name: "path", value: "color:0x0000FF|weight:4|enc:\(encodedPath)"),
            URLQueryItem(name: "key", value: apiKey)
        ]

        // Add start marker (green)
        if let first = waypoints.first {
            queryItems.append(URLQueryItem(
                name: "markers",
                value: "color:green|label:S|\(first.latitude),\(first.longitude)"
            ))
        }

        // Add end marker (red)
        if let last = waypoints.last, waypoints.count > 1 {
            queryItems.append(URLQueryItem(
                name: "markers",
                value: "color:red|label:E|\(last.latitude),\(last.longitude)"
            ))
        }

        components.queryItems = queryItems
        return components.url
    }

    /// Downloads PNG image from Static Maps API
    /// - Parameters:
    ///   - waypoints: Array of waypoints to display
    ///   - outputPath: Path to save the PNG file
    /// - Throws: `TripVisualizerError` on download or file write failure
    public func downloadPNG(waypoints: [Waypoint], to outputPath: String) async throws {
        guard let url = generateStaticMapsURL(waypoints: waypoints) else {
            throw TripVisualizerError.noRouteData
        }

        logDebug("Downloading static map from: \(url.absoluteString)")

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                throw TripVisualizerError.httpError(
                    statusCode: statusCode,
                    message: "Failed to download static map"
                )
            }

            try data.write(to: URL(fileURLWithPath: outputPath))
            logInfo("PNG map written to \(outputPath)")
        } catch let error as TripVisualizerError {
            throw error
        } catch {
            throw TripVisualizerError.cannotWriteOutput(
                path: outputPath,
                reason: error.localizedDescription
            )
        }
    }

    // MARK: - Web URL Generation

    /// Generates a Google Maps web URL for browser viewing
    /// - Parameter waypoints: Array of waypoints to display
    /// - Returns: Google Maps URL or nil if waypoints are empty
    public func generateGoogleMapsWebURL(waypoints: [Waypoint]) -> URL? {
        guard waypoints.count >= 2 else { return nil }

        // Use origin and destination with waypoints parameter
        let origin = waypoints.first!
        let destination = waypoints.last!

        var urlString = "https://www.google.com/maps/dir/"
        urlString += "\(origin.latitude),\(origin.longitude)/"
        urlString += "\(destination.latitude),\(destination.longitude)/"

        return URL(string: urlString)
    }

    // MARK: - Helpers

    /// Converts waypoints to JSON array format for Google Maps JavaScript API
    /// - Parameter waypoints: Array of waypoints
    /// - Returns: JSON string representation
    public func coordinatesToJSON(_ waypoints: [Waypoint]) -> String {
        let coords = waypoints.map { waypoint in
            "{lat: \(waypoint.latitude), lng: \(waypoint.longitude)}"
        }
        return "[\(coords.joined(separator: ", "))]"
    }
}
