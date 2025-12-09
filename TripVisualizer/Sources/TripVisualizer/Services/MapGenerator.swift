import Foundation

/// Service for generating map visualizations from waypoints
///
/// Generates HTML files with interactive Google Maps, Static Maps URLs for PNG images,
/// and Google Maps web URLs for browser viewing.
public final class MapGenerator {

    // MARK: - Properties

    /// Google Maps API key
    private let apiKey: String

    /// Route color as hex string (without #)
    private let routeColor: String

    /// Route line weight in pixels
    private let routeWeight: Int

    /// Polyline encoder for path encoding
    private let polylineEncoder = PolylineEncoder()

    // MARK: - Constants

    private static let staticMapsBaseURL = "https://maps.googleapis.com/maps/api/staticmap"
    public static let defaultWidth = 640
    public static let defaultHeight = 480

    // MARK: - Initialization

    /// Creates a new map generator
    /// - Parameters:
    ///   - apiKey: Google Maps API key
    ///   - routeColor: Hex color for route polyline (default: "0000FF" blue)
    ///   - routeWeight: Line weight in pixels (default: 4)
    public init(apiKey: String, routeColor: String = "0000FF", routeWeight: Int = 4) {
        self.apiKey = apiKey
        self.routeColor = routeColor.replacingOccurrences(of: "#", with: "")
        self.routeWeight = routeWeight
    }

    // MARK: - Constants for Gap Rendering

    /// Gap segment color (gray)
    private static let gapColor = "808080"

    /// Gap segment opacity
    private static let gapOpacity = 0.6

    // MARK: - HTML Generation

    /// Generates HTML content with interactive Google Map supporting route segments.
    ///
    /// Continuous segments are rendered as solid lines, gap segments as dashed lines.
    ///
    /// - Parameters:
    ///   - tripId: Trip UUID for the title
    ///   - segments: Route segments with type information
    /// - Returns: HTML string
    /// - Throws: `TripVisualizerError` if segments are empty
    public func generateHTML(tripId: UUID, segments: [RouteSegment]) throws -> String {
        guard !segments.isEmpty else {
            throw TripVisualizerError.noRouteData
        }

        let allWaypoints = segments.flatMap { $0.waypoints }
        guard !allWaypoints.isEmpty else {
            throw TripVisualizerError.noRouteData
        }

        let hasGaps = segments.contains { $0.isGap }
        let segmentsJS = generateSegmentsJS(segments)
        let deliveryPoints = findDeliveryPoints(allWaypoints)
        let deliveryMarkersJS = generateDeliveryMarkersJS(deliveryPoints)
        let legendHTML = hasGaps ? generateLegendHTML() : ""

        return """
        <!DOCTYPE html>
        <html>
        <head>
          <title>Trip Route: \(tripId.uuidString)</title>
          <style>
            #map { height: 100vh; width: 100%; }
            .legend {
              position: absolute;
              bottom: 20px;
              left: 20px;
              background: white;
              padding: 10px 15px;
              border-radius: 4px;
              box-shadow: 0 2px 6px rgba(0,0,0,0.3);
              font-family: Arial, sans-serif;
              font-size: 12px;
              z-index: 1;
            }
            .legend-item { display: flex; align-items: center; margin: 5px 0; }
            .solid-line { width: 30px; height: 3px; background: #\(routeColor); margin-right: 8px; }
            .dashed-line { width: 30px; height: 3px; background: repeating-linear-gradient(90deg, #\(Self.gapColor) 0, #\(Self.gapColor) 5px, transparent 5px, transparent 10px); margin-right: 8px; }
          </style>
        </head>
        <body>
          <div id="map"></div>
        \(legendHTML)
          <script>
            function initMap() {
              const firstCoord = {lat: \(allWaypoints[0].latitude), lng: \(allWaypoints[0].longitude)};
              const map = new google.maps.Map(document.getElementById("map"), {
                zoom: 12,
                center: firstCoord
              });

              // Render segments
        \(segmentsJS)

              // Start marker
              new google.maps.Marker({
                position: firstCoord,
                map: map,
                icon: "http://maps.google.com/mapfiles/ms/icons/green-dot.png",
                title: "Start"
              });

              // End marker
              const lastCoord = {lat: \(allWaypoints.last!.latitude), lng: \(allWaypoints.last!.longitude)};
              new google.maps.Marker({
                position: lastCoord,
                map: map,
                icon: "http://maps.google.com/mapfiles/ms/icons/red-dot.png",
                title: "End"
              });

              // Delivery markers
        \(deliveryMarkersJS)

              // Fit bounds
              const bounds = new google.maps.LatLngBounds();
              \(coordinatesToJSON(allWaypoints)).forEach(c => bounds.extend(c));
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

    /// Generates JavaScript for rendering route segments
    private func generateSegmentsJS(_ segments: [RouteSegment]) -> String {
        segments.enumerated().map { (index, segment) in
            let coordsJSON = coordinatesToJSON(segment.waypoints)
            let color = segment.isGap ? Self.gapColor : routeColor
            let opacity = segment.isGap ? Self.gapOpacity : 1.0

            if segment.isGap {
                return """
                      // Gap segment \(index)
                      const gapPath\(index) = new google.maps.Polyline({
                        path: \(coordsJSON),
                        geodesic: true,
                        strokeColor: "#\(color)",
                        strokeOpacity: 0,
                        strokeWeight: \(routeWeight),
                        icons: [{
                          icon: {
                            path: 'M 0,-1 0,1',
                            strokeOpacity: \(opacity),
                            scale: 4
                          },
                          offset: '0',
                          repeat: '20px'
                        }]
                      });
                      gapPath\(index).setMap(map);
                """
            } else {
                return """
                      // Continuous segment \(index)
                      const path\(index) = new google.maps.Polyline({
                        path: \(coordsJSON),
                        geodesic: true,
                        strokeColor: "#\(color)",
                        strokeOpacity: \(opacity),
                        strokeWeight: \(routeWeight)
                      });
                      path\(index).setMap(map);
                """
            }
        }.joined(separator: "\n")
    }

    /// Generates legend HTML for gap indication
    private func generateLegendHTML() -> String {
        """
          <div class="legend">
            <div class="legend-item"><span class="solid-line"></span> Route data</div>
            <div class="legend-item"><span class="dashed-line"></span> Gap (missing data)</div>
          </div>
        """
    }

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
        let deliveryPoints = findDeliveryPoints(waypoints)
        let deliveryMarkersJS = generateDeliveryMarkersJS(deliveryPoints)

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
                strokeColor: "#\(routeColor)",
                strokeWeight: \(routeWeight)
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

              // Delivery markers
        \(deliveryMarkersJS)

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

    /// Generates JavaScript code for delivery markers
    private func generateDeliveryMarkersJS(_ deliveryPoints: [(orderNumber: Int, waypoint: Waypoint)]) -> String {
        guard !deliveryPoints.isEmpty else { return "" }

        return deliveryPoints.map { point in
            """
                  new google.maps.Marker({
                    position: {lat: \(point.waypoint.latitude), lng: \(point.waypoint.longitude)},
                    map: map,
                    label: { text: "\(point.orderNumber)", color: "white", fontWeight: "bold" },
                    icon: {
                      path: google.maps.SymbolPath.CIRCLE,
                      scale: 12,
                      fillColor: "#FF6600",
                      fillOpacity: 1,
                      strokeColor: "#CC5200",
                      strokeWeight: 2
                    },
                    title: "Delivery #\(point.orderNumber)"
                  });
            """
        }.joined(separator: "\n")
    }

    /// Writes HTML content to a file with support for route segments.
    ///
    /// This is the preferred method for multi-log trips as it properly
    /// renders gap segments with dashed lines.
    ///
    /// - Parameters:
    ///   - tripId: Trip UUID for the title
    ///   - segments: Route segments with type information
    ///   - path: Output file path
    /// - Throws: `TripVisualizerError` on file write failure
    public func writeHTML(tripId: UUID, segments: [RouteSegment], to path: String) throws {
        let html = try generateHTML(tripId: tripId, segments: segments)

        do {
            try html.write(toFile: path, atomically: true, encoding: .utf8)
            logDebug("HTML map written to \(path)")
        } catch {
            throw TripVisualizerError.cannotWriteOutput(
                path: path,
                reason: error.localizedDescription
            )
        }
    }

    /// Writes HTML content to a file (backward compatible)
    /// - Parameters:
    ///   - tripId: Trip UUID for the title
    ///   - waypoints: Array of waypoints to display
    ///   - path: Output file path
    /// - Throws: `TripVisualizerError` on file write failure
    public func writeHTML(tripId: UUID, waypoints: [Waypoint], to path: String) throws {
        // Wrap in single continuous segment for backward compatibility
        let segment = RouteSegment(waypoints: waypoints, type: .continuous, sourceFragmentId: nil)
        try writeHTML(tripId: tripId, segments: [segment], to: path)
    }

    /// Writes HTML content to a file with enrichment markers
    /// - Parameters:
    ///   - tripId: Trip UUID for the title
    ///   - segments: Route segments with type information
    ///   - enrichmentResult: Enrichment data for markers
    ///   - configuration: Configuration for marker styles
    ///   - path: Output file path
    /// - Throws: `TripVisualizerError` on file write failure
    public func writeHTML(
        tripId: UUID,
        segments: [RouteSegment],
        enrichmentResult: EnrichmentResult,
        configuration: Configuration,
        to path: String
    ) throws {
        let html = try generateHTML(
            tripId: tripId,
            segments: segments,
            enrichmentResult: enrichmentResult,
            configuration: configuration
        )

        do {
            try html.write(toFile: path, atomically: true, encoding: .utf8)
            logDebug("HTML map written to \(path)")
        } catch {
            throw TripVisualizerError.cannotWriteOutput(
                path: path,
                reason: error.localizedDescription
            )
        }
    }

    // MARK: - Static Maps URL Generation

    /// Generates a Google Static Maps API URL for PNG download with segment support.
    ///
    /// Gap segments are rendered in gray color to differentiate from continuous segments.
    /// Note: Google Static Maps API doesn't support dashed lines, so we use color differentiation.
    ///
    /// - Parameters:
    ///   - segments: Route segments with type information
    ///   - width: Image width in pixels (default: 640)
    ///   - height: Image height in pixels (default: 480)
    /// - Returns: Static Maps URL or nil if segments are empty
    public func generateStaticMapsURL(
        segments: [RouteSegment],
        width: Int = defaultWidth,
        height: Int = defaultHeight
    ) -> URL? {
        guard !segments.isEmpty else { return nil }

        let allWaypoints = segments.flatMap { $0.waypoints }
        guard !allWaypoints.isEmpty else { return nil }

        var components = URLComponents(string: Self.staticMapsBaseURL)!

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "size", value: "\(width)x\(height)"),
            URLQueryItem(name: "key", value: apiKey)
        ]

        // Add path for each segment with appropriate color
        for segment in segments {
            let color = segment.isGap ? Self.gapColor : routeColor
            let encodedPath = polylineEncoder.encode(segment.waypoints)
            queryItems.append(URLQueryItem(
                name: "path",
                value: "color:0x\(color)|weight:\(routeWeight)|enc:\(encodedPath)"
            ))
        }

        // Add start marker (green)
        if let first = allWaypoints.first {
            queryItems.append(URLQueryItem(
                name: "markers",
                value: "color:green|label:S|\(first.latitude),\(first.longitude)"
            ))
        }

        // Add end marker (red)
        if let last = allWaypoints.last, allWaypoints.count > 1 {
            queryItems.append(URLQueryItem(
                name: "markers",
                value: "color:red|label:E|\(last.latitude),\(last.longitude)"
            ))
        }

        // Add delivery markers (orange with numbers)
        let deliveryPoints = findDeliveryPoints(allWaypoints)
        for point in deliveryPoints {
            queryItems.append(URLQueryItem(
                name: "markers",
                value: "color:orange|label:\(point.orderNumber)|\(point.waypoint.latitude),\(point.waypoint.longitude)"
            ))
        }

        components.queryItems = queryItems
        return components.url
    }

    /// Generates a Google Static Maps API URL for PNG download (backward compatible)
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

        // Wrap in single continuous segment
        let segment = RouteSegment(waypoints: waypoints, type: .continuous, sourceFragmentId: nil)
        return generateStaticMapsURL(segments: [segment], width: width, height: height)
    }

    /// Downloads PNG image from Static Maps API
    /// - Parameters:
    ///   - waypoints: Array of waypoints to display
    ///   - outputPath: Path to save the PNG file
    ///   - retryCount: Number of retry attempts for transient failures
    /// - Throws: `TripVisualizerError` on download or file write failure
    public func downloadPNG(
        waypoints: [Waypoint],
        to outputPath: String,
        retryCount: Int = RetryHandler.defaultRetryCount
    ) async throws {
        guard let url = generateStaticMapsURL(waypoints: waypoints) else {
            throw TripVisualizerError.noRouteData
        }

        logDebug("Downloading static map from: \(url.absoluteString)")

        // Use retry handler for transient network failures
        let data: Data = try await RetryHandler.withRetry(retryCount: retryCount) {
            let (responseData, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw TripVisualizerError.networkUnreachable("Invalid response from Google Maps API")
            }

            switch httpResponse.statusCode {
            case 200:
                return responseData
            case 403:
                throw TripVisualizerError.httpError(
                    statusCode: 403,
                    message: "Access denied. Ensure Static Maps API is enabled for your Google API key."
                )
            case 429:
                throw TripVisualizerError.rateLimitExceeded
            case 500...599:
                throw TripVisualizerError.httpError(
                    statusCode: httpResponse.statusCode,
                    message: "Google Maps server error"
                )
            default:
                throw TripVisualizerError.httpError(
                    statusCode: httpResponse.statusCode,
                    message: "Failed to download static map"
                )
            }
        }

        // Write file (not retried - local operation)
        do {
            try data.write(to: URL(fileURLWithPath: outputPath))
            logInfo("PNG map written to \(outputPath)")
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

    // MARK: - Enrichment Marker Generation

    /// Generates JavaScript code for delivery destination markers (from enrichment data).
    ///
    /// These markers represent the intended delivery addresses from GetDeliveryOrder logs,
    /// displayed separately from actual route waypoints to enable comparison.
    ///
    /// - Parameters:
    ///   - destinations: Array of delivery destinations from enrichment
    ///   - style: Marker style configuration
    /// - Returns: JavaScript code string for marker creation
    public func generateDeliveryDestinationMarkersJS(
        _ destinations: [DeliveryDestination],
        style: MarkerStyle
    ) -> String {
        guard !destinations.isEmpty else { return "" }

        return destinations.enumerated().map { (index, destination) in
            let label = "\(index + 1)"
            let escapedAddress = destination.formattedAddress
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
            let escapedInstructions = destination.dropoffInstructions?
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n") ?? ""
            let infoContent = escapedInstructions.isEmpty
                ? escapedAddress
                : "\(escapedAddress)<br><i>\(escapedInstructions)</i>"

            return """
                  // Delivery destination \(index + 1)
                  const deliveryMarker\(index) = new google.maps.Marker({
                    position: {lat: \(destination.latitude), lng: \(destination.longitude)},
                    map: map,
                    label: { text: "\(label)", color: "white", fontWeight: "bold" },
                    icon: {
                      path: google.maps.SymbolPath.CIRCLE,
                      scale: 12,
                      fillColor: "\(style.cssColor)",
                      fillOpacity: 1,
                      strokeColor: "#FFFFFF",
                      strokeWeight: 2
                    },
                    title: "Delivery \(label): \(destination.shortDescription)"
                  });
                  const deliveryInfo\(index) = new google.maps.InfoWindow({
                    content: "<strong>Delivery \(label)</strong><br>\(infoContent)"
                  });
                  deliveryMarker\(index).addListener("click", () => {
                    deliveryInfo\(index).open(map, deliveryMarker\(index));
                  });
            """
        }.joined(separator: "\n")
    }

    /// Generates JavaScript code for restaurant origin marker (from enrichment data).
    ///
    /// - Parameters:
    ///   - location: Restaurant location from enrichment (nil if not available)
    ///   - style: Marker style configuration
    /// - Returns: JavaScript code string for marker creation
    public func generateRestaurantMarkerJS(
        _ location: RestaurantLocation?,
        style: MarkerStyle
    ) -> String {
        guard let restaurant = location else { return "" }

        let escapedName = restaurant.name
            .replacingOccurrences(of: "\"", with: "\\\"")
        let escapedAddress = restaurant.formattedAddress
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")

        return """
              // Restaurant origin
              const restaurantMarker = new google.maps.Marker({
                position: {lat: \(restaurant.latitude), lng: \(restaurant.longitude)},
                map: map,
                label: { text: "R", color: "white", fontWeight: "bold" },
                icon: {
                  path: google.maps.SymbolPath.CIRCLE,
                  scale: 14,
                  fillColor: "\(style.cssColor)",
                  fillOpacity: 1,
                  strokeColor: "#FFFFFF",
                  strokeWeight: 2
                },
                title: "\(escapedName)"
              });
              const restaurantInfo = new google.maps.InfoWindow({
                content: "<strong>\(escapedName)</strong><br>\(escapedAddress)"
              });
              restaurantMarker.addListener("click", () => {
                restaurantInfo.open(map, restaurantMarker);
              });
        """
    }

    /// Generates HTML content with interactive Google Map including enrichment markers.
    ///
    /// - Parameters:
    ///   - tripId: Trip UUID for the title
    ///   - segments: Route segments with type information
    ///   - enrichmentResult: Enrichment data (delivery destinations and restaurant)
    ///   - configuration: Configuration for marker styles
    /// - Returns: HTML string
    /// - Throws: `TripVisualizerError` if segments are empty
    public func generateHTML(
        tripId: UUID,
        segments: [RouteSegment],
        enrichmentResult: EnrichmentResult,
        configuration: Configuration
    ) throws -> String {
        guard !segments.isEmpty else {
            throw TripVisualizerError.noRouteData
        }

        let allWaypoints = segments.flatMap { $0.waypoints }
        guard !allWaypoints.isEmpty else {
            throw TripVisualizerError.noRouteData
        }

        let hasGaps = segments.contains { $0.isGap }
        let segmentsJS = generateSegmentsJS(segments)
        let deliveryPoints = findDeliveryPoints(allWaypoints)
        let waypointDeliveryMarkersJS = generateDeliveryMarkersJS(deliveryPoints)

        // Enrichment markers
        let enrichmentDeliveryMarkersJS = generateDeliveryDestinationMarkersJS(
            enrichmentResult.deliveryDestinations,
            style: configuration.deliveryDestinationMarkerStyle
        )
        let restaurantMarkerJS = generateRestaurantMarkerJS(
            enrichmentResult.restaurantLocation,
            style: configuration.restaurantOriginMarkerStyle
        )

        // Generate legend with enrichment entries
        let legendHTML = generateEnrichmentLegendHTML(
            hasGaps: hasGaps,
            hasDeliveryDestinations: !enrichmentResult.deliveryDestinations.isEmpty,
            hasRestaurant: enrichmentResult.restaurantLocation != nil,
            configuration: configuration
        )

        // Collect all coordinates for bounds fitting (include enrichment locations)
        var allCoordinatesJS = coordinatesToJSON(allWaypoints)
        if !enrichmentResult.deliveryDestinations.isEmpty || enrichmentResult.restaurantLocation != nil {
            var extraCoords: [String] = []
            for dest in enrichmentResult.deliveryDestinations {
                extraCoords.append("{lat: \(dest.latitude), lng: \(dest.longitude)}")
            }
            if let restaurant = enrichmentResult.restaurantLocation {
                extraCoords.append("{lat: \(restaurant.latitude), lng: \(restaurant.longitude)}")
            }
            if !extraCoords.isEmpty {
                // Remove trailing ] and add extra coords
                allCoordinatesJS = String(allCoordinatesJS.dropLast()) + ", " + extraCoords.joined(separator: ", ") + "]"
            }
        }

        return """
        <!DOCTYPE html>
        <html>
        <head>
          <title>Trip Route: \(tripId.uuidString)</title>
          <style>
            #map { height: 100vh; width: 100%; }
            .legend {
              position: absolute;
              bottom: 20px;
              left: 20px;
              background: white;
              padding: 10px 15px;
              border-radius: 4px;
              box-shadow: 0 2px 6px rgba(0,0,0,0.3);
              font-family: Arial, sans-serif;
              font-size: 12px;
              z-index: 1;
            }
            .legend-item { display: flex; align-items: center; margin: 5px 0; }
            .solid-line { width: 30px; height: 3px; background: #\(routeColor); margin-right: 8px; }
            .dashed-line { width: 30px; height: 3px; background: repeating-linear-gradient(90deg, #\(Self.gapColor) 0, #\(Self.gapColor) 5px, transparent 5px, transparent 10px); margin-right: 8px; }
            .marker-circle { width: 12px; height: 12px; border-radius: 50%; margin-right: 8px; }
          </style>
        </head>
        <body>
          <div id="map"></div>
        \(legendHTML)
          <script>
            function initMap() {
              const firstCoord = {lat: \(allWaypoints[0].latitude), lng: \(allWaypoints[0].longitude)};
              const map = new google.maps.Map(document.getElementById("map"), {
                zoom: 12,
                center: firstCoord
              });

              // Render segments
        \(segmentsJS)

              // Start marker
              new google.maps.Marker({
                position: firstCoord,
                map: map,
                icon: "http://maps.google.com/mapfiles/ms/icons/green-dot.png",
                title: "Start"
              });

              // End marker
              const lastCoord = {lat: \(allWaypoints.last!.latitude), lng: \(allWaypoints.last!.longitude)};
              new google.maps.Marker({
                position: lastCoord,
                map: map,
                icon: "http://maps.google.com/mapfiles/ms/icons/red-dot.png",
                title: "End"
              });

              // Waypoint delivery markers (from route data)
        \(waypointDeliveryMarkersJS)

              // Enrichment: Delivery destination markers
        \(enrichmentDeliveryMarkersJS)

              // Enrichment: Restaurant origin marker
        \(restaurantMarkerJS)

              // Fit bounds
              const bounds = new google.maps.LatLngBounds();
              \(allCoordinatesJS).forEach(c => bounds.extend(c));
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

    /// Generates a Google Static Maps API URL with enrichment markers.
    ///
    /// - Parameters:
    ///   - segments: Route segments with type information
    ///   - enrichmentResult: Enrichment data for delivery and restaurant markers
    ///   - configuration: Configuration for marker styles
    ///   - width: Image width in pixels (default: 640)
    ///   - height: Image height in pixels (default: 480)
    /// - Returns: Static Maps URL or nil if segments are empty
    public func generateStaticMapsURL(
        segments: [RouteSegment],
        enrichmentResult: EnrichmentResult,
        configuration: Configuration,
        width: Int = defaultWidth,
        height: Int = defaultHeight
    ) -> URL? {
        guard !segments.isEmpty else { return nil }

        let allWaypoints = segments.flatMap { $0.waypoints }
        guard !allWaypoints.isEmpty else { return nil }

        var components = URLComponents(string: Self.staticMapsBaseURL)!

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "size", value: "\(width)x\(height)"),
            URLQueryItem(name: "key", value: apiKey)
        ]

        // Add path for each segment with appropriate color
        for segment in segments {
            let color = segment.isGap ? Self.gapColor : routeColor
            let encodedPath = polylineEncoder.encode(segment.waypoints)
            queryItems.append(URLQueryItem(
                name: "path",
                value: "color:0x\(color)|weight:\(routeWeight)|enc:\(encodedPath)"
            ))
        }

        // Add start marker (green)
        if let first = allWaypoints.first {
            queryItems.append(URLQueryItem(
                name: "markers",
                value: "color:green|label:S|\(first.latitude),\(first.longitude)"
            ))
        }

        // Add end marker (red)
        if let last = allWaypoints.last, allWaypoints.count > 1 {
            queryItems.append(URLQueryItem(
                name: "markers",
                value: "color:red|label:E|\(last.latitude),\(last.longitude)"
            ))
        }

        // Add waypoint delivery markers (orange with numbers)
        let deliveryPoints = findDeliveryPoints(allWaypoints)
        for point in deliveryPoints {
            queryItems.append(URLQueryItem(
                name: "markers",
                value: "color:orange|label:\(point.orderNumber)|\(point.waypoint.latitude),\(point.waypoint.longitude)"
            ))
        }

        // Add enrichment delivery destination markers (configured color)
        let deliveryStyle = configuration.deliveryDestinationMarkerStyle
        for (index, destination) in enrichmentResult.deliveryDestinations.enumerated() {
            let label = index < 9 ? "\(index + 1)" : "D"
            queryItems.append(URLQueryItem(
                name: "markers",
                value: "color:\(deliveryStyle.urlColor)|label:\(label)|\(destination.latitude),\(destination.longitude)"
            ))
        }

        // Add restaurant origin marker (configured color)
        if let restaurant = enrichmentResult.restaurantLocation {
            let restaurantStyle = configuration.restaurantOriginMarkerStyle
            queryItems.append(URLQueryItem(
                name: "markers",
                value: "color:\(restaurantStyle.urlColor)|label:R|\(restaurant.latitude),\(restaurant.longitude)"
            ))
        }

        components.queryItems = queryItems
        return components.url
    }

    /// Generates legend HTML including enrichment marker entries.
    ///
    /// - Parameters:
    ///   - hasGaps: Whether gap segments are present
    ///   - hasDeliveryDestinations: Whether enrichment delivery destinations are present
    ///   - hasRestaurant: Whether enrichment restaurant location is present
    ///   - configuration: Configuration for marker styles
    /// - Returns: HTML string for legend div
    private func generateEnrichmentLegendHTML(
        hasGaps: Bool,
        hasDeliveryDestinations: Bool,
        hasRestaurant: Bool,
        configuration: Configuration
    ) -> String {
        var items: [String] = []

        // Route legend items
        items.append("<div class=\"legend-item\"><span class=\"solid-line\"></span> Route data</div>")

        if hasGaps {
            items.append("<div class=\"legend-item\"><span class=\"dashed-line\"></span> Gap (missing data)</div>")
        }

        // Enrichment legend items
        if hasDeliveryDestinations {
            let color = configuration.deliveryDestinationMarkerStyle.cssColor
            items.append("<div class=\"legend-item\"><span class=\"marker-circle\" style=\"background:\(color)\"></span> Delivery destination</div>")
        }

        if hasRestaurant {
            let color = configuration.restaurantOriginMarkerStyle.cssColor
            items.append("<div class=\"legend-item\"><span class=\"marker-circle\" style=\"background:\(color)\"></span> Restaurant origin</div>")
        }

        return """
          <div class="legend">
            \(items.joined(separator: "\n            "))
          </div>
        """
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

    /// Finds the last waypoint for each unique order ID
    /// - Parameter waypoints: Array of waypoints
    /// - Returns: Array of (orderNumber, waypoint) tuples representing delivery points
    public func findDeliveryPoints(_ waypoints: [Waypoint]) -> [(orderNumber: Int, waypoint: Waypoint)] {
        var orderLastWaypoint: [UUID: (index: Int, waypoint: Waypoint)] = [:]
        var orderFirstSeen: [UUID: Int] = [:]
        var orderCounter = 0

        for (index, waypoint) in waypoints.enumerated() {
            guard let orderId = waypoint.orderId else { continue }

            // Track the order of first appearance for numbering
            if orderFirstSeen[orderId] == nil {
                orderCounter += 1
                orderFirstSeen[orderId] = orderCounter
            }

            // Always update to the latest waypoint for this order
            orderLastWaypoint[orderId] = (index, waypoint)
        }

        // Sort by the index (position in route) and return with order numbers
        return orderLastWaypoint
            .sorted { $0.value.index < $1.value.index }
            .map { (orderFirstSeen[$0.key]!, $0.value.waypoint) }
    }
}
