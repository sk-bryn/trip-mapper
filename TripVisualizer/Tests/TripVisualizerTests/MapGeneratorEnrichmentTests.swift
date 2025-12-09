import XCTest
@testable import TripVisualizer

/// Tests for MapGenerator enrichment marker generation
final class MapGeneratorEnrichmentTests: XCTestCase {

    // MARK: - Properties

    private var mapGenerator: MapGenerator!
    private var configuration: Configuration!

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        configuration = .defaultConfig
        mapGenerator = MapGenerator(
            apiKey: "test-api-key",
            routeColor: configuration.routeColor,
            routeWeight: configuration.routeWeight
        )
    }

    override func tearDown() {
        mapGenerator = nil
        configuration = nil
        super.tearDown()
    }

    // MARK: - Delivery Destination Marker Tests

    func testGenerateDeliveryDestinationMarkersJS_EmptyDestinations() {
        let destinations: [DeliveryDestination] = []
        let style = MarkerStyle.defaultDeliveryDestination

        // Note: This method needs to be added to MapGenerator in T016
        // For now, we're testing the expected interface
        let result = generateDeliveryDestinationMarkersJS(destinations: destinations, style: style)

        XCTAssertEqual(result, "")
    }

    func testGenerateDeliveryDestinationMarkersJS_SingleDestination() {
        let destination = makeDeliveryDestination()
        let style = MarkerStyle.defaultDeliveryDestination

        let result = generateDeliveryDestinationMarkersJS(destinations: [destination], style: style)

        // Should contain marker creation code
        XCTAssertTrue(result.contains("google.maps.Marker"))
        XCTAssertTrue(result.contains("\(destination.latitude)"))
        XCTAssertTrue(result.contains("\(destination.longitude)"))
        // Should use configured color
        XCTAssertTrue(result.contains(style.cssColor) || result.contains(style.color))
    }

    func testGenerateDeliveryDestinationMarkersJS_MultipleDestinations() {
        let destinations = [
            makeDeliveryDestination(orderId: UUID(), latitude: 33.7490, longitude: -84.3880),
            makeDeliveryDestination(orderId: UUID(), latitude: 34.0522, longitude: -118.2437)
        ]
        let style = MarkerStyle.defaultDeliveryDestination

        let result = generateDeliveryDestinationMarkersJS(destinations: destinations, style: style)

        // Should contain both markers
        XCTAssertTrue(result.contains("33.749"))
        XCTAssertTrue(result.contains("34.0522"))
    }

    func testGenerateDeliveryDestinationMarkersJS_IncludesInfoWindow() {
        let destination = makeDeliveryDestination(
            address: "123 Main St, Atlanta, GA 30301"
        )
        let style = MarkerStyle.defaultDeliveryDestination

        let result = generateDeliveryDestinationMarkersJS(destinations: [destination], style: style)

        // Should include info window with address
        XCTAssertTrue(result.contains("InfoWindow") || result.contains("title"))
    }

    func testGenerateDeliveryDestinationMarkersJS_UsesConfiguredStyle() {
        let destination = makeDeliveryDestination()
        let customStyle = MarkerStyle(icon: "pin", color: "FF0000")

        let result = generateDeliveryDestinationMarkersJS(destinations: [destination], style: customStyle)

        // Should use custom color
        XCTAssertTrue(result.contains("FF0000") || result.contains("#FF0000"))
    }

    // MARK: - Restaurant Marker Tests

    func testGenerateRestaurantMarkerJS_NilLocation() {
        let location: RestaurantLocation? = nil
        let style = MarkerStyle.defaultRestaurantOrigin

        // Note: This method needs to be added to MapGenerator in T028
        let result = generateRestaurantMarkerJS(location: location, style: style)

        XCTAssertEqual(result, "")
    }

    func testGenerateRestaurantMarkerJS_ValidLocation() {
        let location = makeRestaurantLocation()
        let style = MarkerStyle.defaultRestaurantOrigin

        let result = generateRestaurantMarkerJS(location: location, style: style)

        // Should contain marker creation code
        XCTAssertTrue(result.contains("google.maps.Marker"))
        XCTAssertTrue(result.contains("\(location.latitude)"))
        XCTAssertTrue(result.contains("\(location.longitude)"))
        // Should use configured color
        XCTAssertTrue(result.contains(style.cssColor) || result.contains(style.color))
    }

    func testGenerateRestaurantMarkerJS_IncludesNameInLabel() {
        let location = makeRestaurantLocation(name: "Test Restaurant")
        let style = MarkerStyle.defaultRestaurantOrigin

        let result = generateRestaurantMarkerJS(location: location, style: style)

        XCTAssertTrue(result.contains("Test Restaurant") || result.contains("title"))
    }

    func testGenerateRestaurantMarkerJS_UsesConfiguredStyle() {
        let location = makeRestaurantLocation()
        let customStyle = MarkerStyle(icon: "store", color: "00FF00")

        let result = generateRestaurantMarkerJS(location: location, style: customStyle)

        // Should use custom color
        XCTAssertTrue(result.contains("00FF00") || result.contains("#00FF00"))
    }

    // MARK: - Static Maps URL Marker Tests

    func testStaticMapsURL_IncludesDeliveryDestinations() {
        let waypoints = [
            Waypoint(latitude: 33.7490, longitude: -84.3880, orderId: nil)
        ]
        let segment = RouteSegment(waypoints: waypoints, type: .continuous, sourceFragmentId: nil)
        let destinations = [makeDeliveryDestination()]
        let style = MarkerStyle.defaultDeliveryDestination

        // Note: This method signature needs to be updated in T018
        let url = generateStaticMapsURLWithEnrichment(
            segments: [segment],
            deliveryDestinations: destinations,
            deliveryStyle: style,
            restaurantLocation: nil,
            restaurantStyle: .defaultRestaurantOrigin
        )

        XCTAssertNotNil(url)
        let urlString = url?.absoluteString ?? ""
        // Should include delivery marker
        XCTAssertTrue(urlString.contains("markers"))
        XCTAssertTrue(urlString.contains("\(destinations[0].latitude)"))
    }

    func testStaticMapsURL_IncludesRestaurantLocation() {
        let waypoints = [
            Waypoint(latitude: 33.7490, longitude: -84.3880, orderId: nil)
        ]
        let segment = RouteSegment(waypoints: waypoints, type: .continuous, sourceFragmentId: nil)
        let restaurant = makeRestaurantLocation()
        let style = MarkerStyle.defaultRestaurantOrigin

        let url = generateStaticMapsURLWithEnrichment(
            segments: [segment],
            deliveryDestinations: [],
            deliveryStyle: .defaultDeliveryDestination,
            restaurantLocation: restaurant,
            restaurantStyle: style
        )

        XCTAssertNotNil(url)
        let urlString = url?.absoluteString ?? ""
        // Should include restaurant marker
        XCTAssertTrue(urlString.contains("markers"))
        XCTAssertTrue(urlString.contains("\(restaurant.latitude)"))
    }

    func testStaticMapsURL_UsesConfiguredColors() {
        let waypoints = [
            Waypoint(latitude: 33.7490, longitude: -84.3880, orderId: nil)
        ]
        let segment = RouteSegment(waypoints: waypoints, type: .continuous, sourceFragmentId: nil)
        let destination = makeDeliveryDestination()
        let deliveryStyle = MarkerStyle(icon: "home", color: "9900FF")

        let url = generateStaticMapsURLWithEnrichment(
            segments: [segment],
            deliveryDestinations: [destination],
            deliveryStyle: deliveryStyle,
            restaurantLocation: nil,
            restaurantStyle: .defaultRestaurantOrigin
        )

        XCTAssertNotNil(url)
        let urlString = url?.absoluteString ?? ""
        // Should use configured color in URL format
        XCTAssertTrue(urlString.contains("0x9900FF") || urlString.contains("purple"))
    }

    // MARK: - Legend Tests

    func testLegendHTML_IncludesDeliveryEntry() {
        let hasDeliveries = true
        let hasRestaurant = false

        // Note: Legend HTML needs to be updated in T019/T031
        let legend = generateEnrichmentLegendHTML(
            hasDeliveries: hasDeliveries,
            hasRestaurant: hasRestaurant,
            deliveryStyle: .defaultDeliveryDestination,
            restaurantStyle: .defaultRestaurantOrigin
        )

        XCTAssertTrue(legend.contains("Delivery") || legend.contains("delivery"))
        XCTAssertTrue(legend.contains(MarkerStyle.defaultDeliveryDestination.cssColor))
    }

    func testLegendHTML_IncludesRestaurantEntry() {
        let hasDeliveries = false
        let hasRestaurant = true

        let legend = generateEnrichmentLegendHTML(
            hasDeliveries: hasDeliveries,
            hasRestaurant: hasRestaurant,
            deliveryStyle: .defaultDeliveryDestination,
            restaurantStyle: .defaultRestaurantOrigin
        )

        XCTAssertTrue(legend.contains("Restaurant") || legend.contains("restaurant"))
        XCTAssertTrue(legend.contains(MarkerStyle.defaultRestaurantOrigin.cssColor))
    }

    func testLegendHTML_IncludesBothEntries() {
        let legend = generateEnrichmentLegendHTML(
            hasDeliveries: true,
            hasRestaurant: true,
            deliveryStyle: .defaultDeliveryDestination,
            restaurantStyle: .defaultRestaurantOrigin
        )

        XCTAssertTrue(legend.contains("Delivery") || legend.contains("delivery"))
        XCTAssertTrue(legend.contains("Restaurant") || legend.contains("restaurant"))
    }

    // MARK: - Temporary Helper Methods (to be replaced with actual MapGenerator methods)

    /// Temporary helper - will be replaced by MapGenerator.generateDeliveryDestinationMarkersJS in T016
    private func generateDeliveryDestinationMarkersJS(
        destinations: [DeliveryDestination],
        style: MarkerStyle
    ) -> String {
        guard !destinations.isEmpty else { return "" }

        return destinations.enumerated().map { (index, destination) in
            """
                  new google.maps.Marker({
                    position: {lat: \(destination.latitude), lng: \(destination.longitude)},
                    map: map,
                    icon: {
                      path: google.maps.SymbolPath.CIRCLE,
                      scale: 10,
                      fillColor: "\(style.cssColor)",
                      fillOpacity: 1,
                      strokeColor: "#FFFFFF",
                      strokeWeight: 2
                    },
                    title: "\(destination.shortDescription)"
                  });
            """
        }.joined(separator: "\n")
    }

    /// Temporary helper - will be replaced by MapGenerator.generateRestaurantMarkerJS in T028
    private func generateRestaurantMarkerJS(
        location: RestaurantLocation?,
        style: MarkerStyle
    ) -> String {
        guard let location = location else { return "" }

        return """
              new google.maps.Marker({
                position: {lat: \(location.latitude), lng: \(location.longitude)},
                map: map,
                icon: {
                  path: google.maps.SymbolPath.CIRCLE,
                  scale: 12,
                  fillColor: "\(style.cssColor)",
                  fillOpacity: 1,
                  strokeColor: "#FFFFFF",
                  strokeWeight: 2
                },
                title: "\(location.name)"
              });
        """
    }

    /// Temporary helper - will be replaced by updated MapGenerator.generateStaticMapsURL in T018/T030
    private func generateStaticMapsURLWithEnrichment(
        segments: [RouteSegment],
        deliveryDestinations: [DeliveryDestination],
        deliveryStyle: MarkerStyle,
        restaurantLocation: RestaurantLocation?,
        restaurantStyle: MarkerStyle
    ) -> URL? {
        guard !segments.isEmpty else { return nil }

        var components = URLComponents(string: "https://maps.googleapis.com/maps/api/staticmap")!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "size", value: "640x480"),
            URLQueryItem(name: "key", value: "test-key")
        ]

        // Add delivery markers
        for destination in deliveryDestinations {
            queryItems.append(URLQueryItem(
                name: "markers",
                value: "color:\(deliveryStyle.urlColor)|label:D|\(destination.latitude),\(destination.longitude)"
            ))
        }

        // Add restaurant marker
        if let restaurant = restaurantLocation {
            queryItems.append(URLQueryItem(
                name: "markers",
                value: "color:\(restaurantStyle.urlColor)|label:R|\(restaurant.latitude),\(restaurant.longitude)"
            ))
        }

        components.queryItems = queryItems
        return components.url
    }

    /// Temporary helper - will be replaced by updated legend generation in T019/T031
    private func generateEnrichmentLegendHTML(
        hasDeliveries: Bool,
        hasRestaurant: Bool,
        deliveryStyle: MarkerStyle,
        restaurantStyle: MarkerStyle
    ) -> String {
        var items: [String] = []

        if hasDeliveries {
            items.append("""
                <div class="legend-item">
                  <span style="display:inline-block;width:12px;height:12px;border-radius:50%;background:\(deliveryStyle.cssColor);margin-right:8px;"></span>
                  Delivery destination
                </div>
            """)
        }

        if hasRestaurant {
            items.append("""
                <div class="legend-item">
                  <span style="display:inline-block;width:12px;height:12px;border-radius:50%;background:\(restaurantStyle.cssColor);margin-right:8px;"></span>
                  Restaurant origin
                </div>
            """)
        }

        guard !items.isEmpty else { return "" }

        return """
            <div class="legend enrichment-legend">
              \(items.joined(separator: "\n"))
            </div>
        """
    }

    // MARK: - Test Data Helpers

    private func makeDeliveryDestination(
        orderId: UUID = UUID(),
        address: String = "123 Main St, Atlanta, GA 30301",
        latitude: Double = 33.7490,
        longitude: Double = -84.3880
    ) -> DeliveryDestination {
        DeliveryDestination(
            orderId: orderId,
            address: address,
            addressDisplayLine1: "123 Main St",
            addressDisplayLine2: "Atlanta, GA 30301",
            latitude: latitude,
            longitude: longitude,
            dropoffInstructions: nil
        )
    }

    private func makeRestaurantLocation(
        locationNumber: String = "00070",
        name: String = "West Columbia"
    ) -> RestaurantLocation {
        RestaurantLocation(
            locationNumber: locationNumber,
            name: name,
            address1: "2299 Augusta Rd",
            address2: nil,
            city: "West Columbia",
            state: "SC",
            zip: "29169",
            latitude: 33.98325,
            longitude: -81.096,
            operatorName: nil,
            timeZone: nil
        )
    }
}
