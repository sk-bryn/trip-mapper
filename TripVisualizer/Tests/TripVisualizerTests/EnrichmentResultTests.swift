import XCTest
@testable import TripVisualizer

/// Tests for EnrichmentResult model
final class EnrichmentResultTests: XCTestCase {

    // MARK: - Factory Method Tests

    func testEmptyFactoryMethod() {
        let result = EnrichmentResult.empty

        XCTAssertNil(result.restaurantLocation)
        XCTAssertTrue(result.deliveryDestinations.isEmpty)
        XCTAssertFalse(result.status.orderDataFound)
        XCTAssertFalse(result.status.locationDataFound)
        XCTAssertTrue(result.warnings.isEmpty)
    }

    func testFailedFactoryMethod() {
        let warnings = ["Order lookup failed", "Location not found"]
        let result = EnrichmentResult.failed(with: warnings)

        XCTAssertNil(result.restaurantLocation)
        XCTAssertTrue(result.deliveryDestinations.isEmpty)
        XCTAssertFalse(result.status.orderDataFound)
        XCTAssertFalse(result.status.locationDataFound)
        XCTAssertEqual(result.warnings, warnings)
    }

    // MARK: - Computed Properties Tests

    func testHasData_WithNoData() {
        let result = EnrichmentResult.empty
        XCTAssertFalse(result.hasData)
    }

    func testHasData_WithOrderDataOnly() {
        let result = EnrichmentResult(
            restaurantLocation: nil,
            deliveryDestinations: [makeDeliveryDestination()],
            status: EnrichmentStatus(orderDataFound: true, locationDataFound: false),
            warnings: []
        )
        XCTAssertTrue(result.hasData)
    }

    func testHasData_WithLocationDataOnly() {
        let result = EnrichmentResult(
            restaurantLocation: makeRestaurantLocation(),
            deliveryDestinations: [],
            status: EnrichmentStatus(orderDataFound: false, locationDataFound: true),
            warnings: []
        )
        XCTAssertTrue(result.hasData)
    }

    func testHasWarnings_WithNoWarnings() {
        let result = EnrichmentResult.empty
        XCTAssertFalse(result.hasWarnings)
    }

    func testHasWarnings_WithWarnings() {
        let result = EnrichmentResult.failed(with: ["Some warning"])
        XCTAssertTrue(result.hasWarnings)
    }

    func testDeliveryCount() {
        let destinations = [
            makeDeliveryDestination(orderId: UUID()),
            makeDeliveryDestination(orderId: UUID())
        ]
        let result = EnrichmentResult(
            restaurantLocation: nil,
            deliveryDestinations: destinations,
            status: EnrichmentStatus(orderDataFound: true, locationDataFound: false),
            warnings: []
        )
        XCTAssertEqual(result.deliveryCount, 2)
    }

    func testSummary_WithNoData() {
        let result = EnrichmentResult.empty
        XCTAssertEqual(result.summary, "No enrichment data")
    }

    func testSummary_WithAllData() {
        let restaurant = makeRestaurantLocation()
        let destinations = [makeDeliveryDestination()]
        let result = EnrichmentResult(
            restaurantLocation: restaurant,
            deliveryDestinations: destinations,
            status: EnrichmentStatus(orderDataFound: true, locationDataFound: true),
            warnings: []
        )
        XCTAssertTrue(result.summary.contains("Restaurant: \(restaurant.name)"))
        XCTAssertTrue(result.summary.contains("Deliveries: 1"))
    }

    func testSummary_WithWarnings() {
        let result = EnrichmentResult.failed(with: ["Warning 1", "Warning 2"])
        XCTAssertTrue(result.summary.contains("Warnings: 2"))
    }

    // MARK: - Codable Tests

    func testEncodeDecode() throws {
        let restaurant = makeRestaurantLocation()
        let destinations = [makeDeliveryDestination()]
        let original = EnrichmentResult(
            restaurantLocation: restaurant,
            deliveryDestinations: destinations,
            status: EnrichmentStatus(orderDataFound: true, locationDataFound: true),
            warnings: ["Test warning"]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(EnrichmentResult.self, from: data)

        XCTAssertEqual(decoded.restaurantLocation?.name, restaurant.name)
        XCTAssertEqual(decoded.deliveryDestinations.count, 1)
        XCTAssertEqual(decoded.status.orderDataFound, true)
        XCTAssertEqual(decoded.status.locationDataFound, true)
        XCTAssertEqual(decoded.warnings, ["Test warning"])
    }

    // MARK: - Equatable Tests

    func testEquatable_SameValues() {
        let result1 = EnrichmentResult.empty
        let result2 = EnrichmentResult.empty
        XCTAssertEqual(result1, result2)
    }

    func testEquatable_DifferentValues() {
        let result1 = EnrichmentResult.empty
        let result2 = EnrichmentResult.failed(with: ["Warning"])
        XCTAssertNotEqual(result1, result2)
    }

    // MARK: - Test Helpers

    private func makeDeliveryDestination(orderId: UUID = UUID()) -> DeliveryDestination {
        DeliveryDestination(
            orderId: orderId,
            address: "123 Main St, Atlanta, GA 30301",
            addressDisplayLine1: "123 Main St",
            addressDisplayLine2: "Atlanta, GA 30301",
            latitude: 33.7490,
            longitude: -84.3880,
            dropoffInstructions: nil
        )
    }

    private func makeRestaurantLocation() -> RestaurantLocation {
        RestaurantLocation(
            locationNumber: "00070",
            name: "West Columbia",
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

/// Tests for EnrichmentStatus model
final class EnrichmentStatusTests: XCTestCase {

    // MARK: - Factory Method Tests

    func testNoDataFound() {
        let status = EnrichmentStatus.noDataFound
        XCTAssertFalse(status.orderDataFound)
        XCTAssertFalse(status.locationDataFound)
    }

    func testAllDataFound() {
        let status = EnrichmentStatus.allDataFound
        XCTAssertTrue(status.orderDataFound)
        XCTAssertTrue(status.locationDataFound)
    }

    // MARK: - Computed Properties Tests

    func testHasAnyData_NeitherFound() {
        let status = EnrichmentStatus(orderDataFound: false, locationDataFound: false)
        XCTAssertFalse(status.hasAnyData)
    }

    func testHasAnyData_OrderOnly() {
        let status = EnrichmentStatus(orderDataFound: true, locationDataFound: false)
        XCTAssertTrue(status.hasAnyData)
    }

    func testHasAnyData_LocationOnly() {
        let status = EnrichmentStatus(orderDataFound: false, locationDataFound: true)
        XCTAssertTrue(status.hasAnyData)
    }

    func testHasAnyData_BothFound() {
        let status = EnrichmentStatus(orderDataFound: true, locationDataFound: true)
        XCTAssertTrue(status.hasAnyData)
    }

    func testHasAllData_NeitherFound() {
        let status = EnrichmentStatus(orderDataFound: false, locationDataFound: false)
        XCTAssertFalse(status.hasAllData)
    }

    func testHasAllData_OrderOnly() {
        let status = EnrichmentStatus(orderDataFound: true, locationDataFound: false)
        XCTAssertFalse(status.hasAllData)
    }

    func testHasAllData_BothFound() {
        let status = EnrichmentStatus(orderDataFound: true, locationDataFound: true)
        XCTAssertTrue(status.hasAllData)
    }

    func testSummary_AllCases() {
        let status1 = EnrichmentStatus(orderDataFound: true, locationDataFound: true)
        XCTAssertEqual(status1.summary, "All enrichment data available")

        let status2 = EnrichmentStatus(orderDataFound: true, locationDataFound: false)
        XCTAssertEqual(status2.summary, "Order data available, restaurant location unavailable")

        let status3 = EnrichmentStatus(orderDataFound: false, locationDataFound: true)
        XCTAssertEqual(status3.summary, "Restaurant location available, order data unavailable")

        let status4 = EnrichmentStatus(orderDataFound: false, locationDataFound: false)
        XCTAssertEqual(status4.summary, "No enrichment data available")
    }

    // MARK: - Codable Tests

    func testEncodeDecode() throws {
        let original = EnrichmentStatus(orderDataFound: true, locationDataFound: false)

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(EnrichmentStatus.self, from: data)

        XCTAssertEqual(decoded.orderDataFound, true)
        XCTAssertEqual(decoded.locationDataFound, false)
    }
}

/// Tests for MarkerStyle model
final class MarkerStyleTests: XCTestCase {

    func testDefaultDeliveryDestination() {
        let style = MarkerStyle.defaultDeliveryDestination
        XCTAssertEqual(style.icon, "home")
        XCTAssertEqual(style.color, "9900FF")
    }

    func testDefaultRestaurantOrigin() {
        let style = MarkerStyle.defaultRestaurantOrigin
        XCTAssertEqual(style.icon, "restaurant")
        XCTAssertEqual(style.color, "0066FF")
    }

    func testIsValidColor_ValidHex() {
        let style = MarkerStyle(icon: "test", color: "FF00FF")
        XCTAssertTrue(style.isValidColor)
    }

    func testIsValidColor_InvalidLength() {
        let style = MarkerStyle(icon: "test", color: "FF00")
        XCTAssertFalse(style.isValidColor)
    }

    func testIsValidColor_InvalidCharacters() {
        let style = MarkerStyle(icon: "test", color: "GGGGGG")
        XCTAssertFalse(style.isValidColor)
    }

    func testCssColor() {
        let style = MarkerStyle(icon: "test", color: "9900FF")
        XCTAssertEqual(style.cssColor, "#9900FF")
    }

    func testUrlColor() {
        let style = MarkerStyle(icon: "test", color: "9900FF")
        XCTAssertEqual(style.urlColor, "0x9900FF")
    }

    func testEncodeDecode() throws {
        let original = MarkerStyle(icon: "custom", color: "AABBCC")

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MarkerStyle.self, from: data)

        XCTAssertEqual(decoded.icon, "custom")
        XCTAssertEqual(decoded.color, "AABBCC")
    }
}
