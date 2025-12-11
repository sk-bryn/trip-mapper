import XCTest
@testable import TripVisualizer

/// Tests for EnrichmentService
///
/// Note: These tests focus on the parsing and data transformation methods.
/// Network-level tests are covered in DataDogClientTests.
/// Full integration tests will be added in T045.
final class EnrichmentServiceTests: XCTestCase {

    // MARK: - Properties

    private var configuration: Configuration!
    private var enrichmentService: EnrichmentService!

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        configuration = .defaultConfig
        // Create service with empty credentials (we won't make network calls)
        let dataDogClient = DataDogClient(
            apiKey: "test-api-key",
            appKey: "test-app-key",
            configuration: configuration
        )
        enrichmentService = EnrichmentService(
            dataDogClient: dataDogClient,
            configuration: configuration
        )
    }

    override func tearDown() {
        configuration = nil
        enrichmentService = nil
        super.tearDown()
    }

    // MARK: - parseDeliveryDestination Tests

    func testParseDeliveryDestination_ReturnsNil_WhenNoResponseBody() {
        let logEntry = makeEmptyLog()

        let result = enrichmentService.parseDeliveryDestination(from: logEntry)

        // Stub returns nil (expected until T014 implementation)
        XCTAssertNil(result)
    }

    func testParseDeliveryDestination_ReturnsNil_WhenMissingOrderData() {
        let logEntry = makeLogWithEmptyResponseBody()

        let result = enrichmentService.parseDeliveryDestination(from: logEntry)

        XCTAssertNil(result)
    }

    func testParseDeliveryDestination_ReturnsNil_WhenMissingCoordinates() {
        let logEntry = makeDeliveryOrderLogWithoutCoordinates()

        let result = enrichmentService.parseDeliveryDestination(from: logEntry)

        XCTAssertNil(result)
    }

    func testParseDeliveryDestination_ReturnsDestination_WhenValidData() {
        let orderId = UUID()
        let logEntry = makeDeliveryOrderLog(orderId: orderId, tripId: UUID())

        let result = enrichmentService.parseDeliveryDestination(from: logEntry)

        XCTAssertNotNil(result)
        guard let destination = result else { return }

        XCTAssertEqual(destination.orderId, orderId)
        XCTAssertEqual(destination.latitude, 33.7490, accuracy: 0.0001)
        XCTAssertEqual(destination.longitude, -84.3880, accuracy: 0.0001)
        XCTAssertEqual(destination.address, "123 Main St, Atlanta, GA 30301")
        XCTAssertEqual(destination.addressDisplayLine1, "123 Main St")
        XCTAssertEqual(destination.addressDisplayLine2, "Atlanta, GA 30301")
    }

    func testParseDeliveryDestination_HandlesFloatCoordinates() {
        let orderId = UUID()
        let logEntry = makeDeliveryOrderLogWithFloatCoordinates(orderId: orderId)

        let result = enrichmentService.parseDeliveryDestination(from: logEntry)

        XCTAssertNotNil(result)
        guard let destination = result else { return }

        XCTAssertEqual(destination.orderId, orderId)
        // Float precision is lower, so use larger accuracy
        XCTAssertEqual(destination.latitude, Double(Float(33.7490)), accuracy: 0.001)
        XCTAssertEqual(destination.longitude, Double(Float(-84.3880)), accuracy: 0.001)
    }

    // MARK: - parseRestaurantLocation Tests

    func testParseRestaurantLocation_ReturnsNil_WhenNoResponseBody() {
        let logEntry = makeEmptyLog()

        let result = enrichmentService.parseRestaurantLocation(from: logEntry, locationNumber: "00070")

        // Stub returns nil (expected until T026 implementation)
        XCTAssertNil(result)
    }

    func testParseRestaurantLocation_ReturnsNil_WhenLocationNotFound() {
        let logEntry = makeLocationDetailsLog(locationNumber: "00070")

        // Search for different location number
        let result = enrichmentService.parseRestaurantLocation(from: logEntry, locationNumber: "99999")

        // Should return nil when location number doesn't match
        XCTAssertNil(result)
    }

    func testParseRestaurantLocation_ReturnsLocation_WhenValidData() {
        let logEntry = makeLocationDetailsLog(locationNumber: "00070")

        let result = enrichmentService.parseRestaurantLocation(from: logEntry, locationNumber: "00070")

        XCTAssertNotNil(result)
        guard let location = result else { return }

        XCTAssertEqual(location.locationNumber, "00070")
        XCTAssertEqual(location.name, "West Columbia")
        XCTAssertEqual(location.latitude, 33.98325, accuracy: 0.0001)
        XCTAssertEqual(location.longitude, -81.096, accuracy: 0.0001)
        XCTAssertEqual(location.address1, "2299 Augusta Rd")
        XCTAssertEqual(location.city, "West Columbia")
        XCTAssertEqual(location.state, "SC")
        XCTAssertEqual(location.zip, "29169")
    }

    // MARK: - fetchRestaurantLocationWithWarnings Tests

    func testFetchRestaurantLocationWithWarnings_ReturnsWarning_WhenNotFound() async {
        // When fetchRestaurantLocation returns nil (no matching logs),
        // the wrapper method should add a warning
        let (location, warnings) = await enrichmentService.fetchRestaurantLocationWithWarnings(
            locationNumber: "99999"
        )

        // Location should be nil since no logs exist for this location
        XCTAssertNil(location)
        // Should have a warning about the failed lookup
        // Note: The actual warning depends on whether the network call fails or returns empty
        // In test environment without network, this will fail with a network error
        XCTAssertFalse(warnings.isEmpty)
    }

    // MARK: - fetchDeliveryDestinations Tests

    func testFetchDeliveryDestinations_ReturnsEmptyArray_WhenNoOrderIds() async {
        let (destinations, warnings) = await enrichmentService.fetchDeliveryDestinations(
            orderIds: []
        )

        XCTAssertTrue(destinations.isEmpty)
        XCTAssertTrue(warnings.isEmpty)
    }

    // MARK: - fetchEnrichmentData Tests

    func testFetchEnrichmentData_ReturnsEmpty_WhenNoInputs() async {
        let result = await enrichmentService.fetchEnrichmentData(
            orderIds: [],
            locationNumber: nil
        )

        XCTAssertEqual(result, EnrichmentResult.empty)
    }

    // Note: Real network call tests removed due to memory issues with XCTest async
    // Graceful degradation is tested in GracefulDegradationTests.swift

    // MARK: - EnrichmentResult Integration Tests

    func testEnrichmentResult_Empty_HasCorrectDefaults() {
        let result = EnrichmentResult.empty

        XCTAssertNil(result.restaurantLocation)
        XCTAssertTrue(result.deliveryDestinations.isEmpty)
        XCTAssertFalse(result.status.orderDataFound)
        XCTAssertFalse(result.status.locationDataFound)
        XCTAssertTrue(result.warnings.isEmpty)
        XCTAssertFalse(result.hasData)
        XCTAssertFalse(result.hasWarnings)
    }

    func testEnrichmentResult_Failed_ContainsWarnings() {
        let warnings = ["Order lookup failed", "Location not found"]
        let result = EnrichmentResult.failed(with: warnings)

        XCTAssertEqual(result.warnings, warnings)
        XCTAssertTrue(result.hasWarnings)
        XCTAssertFalse(result.hasData)
    }

    func testEnrichmentResult_WithDeliveryDestinations() {
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

        XCTAssertTrue(result.hasData)
        XCTAssertEqual(result.deliveryCount, 2)
        XCTAssertTrue(result.status.orderDataFound)
        XCTAssertFalse(result.status.locationDataFound)
    }

    func testEnrichmentResult_WithRestaurantLocation() {
        let restaurant = makeRestaurantLocation()
        let result = EnrichmentResult(
            restaurantLocation: restaurant,
            deliveryDestinations: [],
            status: EnrichmentStatus(orderDataFound: false, locationDataFound: true),
            warnings: []
        )

        XCTAssertTrue(result.hasData)
        XCTAssertEqual(result.restaurantLocation?.name, restaurant.name)
        XCTAssertFalse(result.status.orderDataFound)
        XCTAssertTrue(result.status.locationDataFound)
    }

    func testEnrichmentResult_Summary_AllData() {
        let restaurant = makeRestaurantLocation()
        let destinations = [makeDeliveryDestination(orderId: UUID())]
        let result = EnrichmentResult(
            restaurantLocation: restaurant,
            deliveryDestinations: destinations,
            status: EnrichmentStatus.allDataFound,
            warnings: []
        )

        XCTAssertTrue(result.summary.contains("Restaurant:"))
        XCTAssertTrue(result.summary.contains("Deliveries: 1"))
    }

    // MARK: - Test Helpers

    private func makeEmptyLog() -> DataDogLogEntry {
        DataDogLogEntry(
            id: UUID().uuidString,
            attributes: DataDogLogAttributes(
                timestamp: ISO8601DateFormatter().string(from: Date()),
                message: "Test log",
                attributes: [:]
            ),
            type: "log"
        )
    }

    private func makeLogWithEmptyResponseBody() -> DataDogLogEntry {
        DataDogLogEntry(
            id: UUID().uuidString,
            attributes: DataDogLogAttributes(
                timestamp: ISO8601DateFormatter().string(from: Date()),
                message: "handled request for GetDeliveryOrder",
                attributes: [
                    "response": [
                        "Msg": [:] as [String: Any]
                    ] as [String: Any]
                ]
            ),
            type: "log"
        )
    }

    private func makeDeliveryOrderLog(orderId: UUID, tripId: UUID) -> DataDogLogEntry {
        DataDogLogEntry(
            id: UUID().uuidString,
            attributes: DataDogLogAttributes(
                timestamp: ISO8601DateFormatter().string(from: Date()),
                message: "handled request for GetDeliveryOrder",
                attributes: [
                    "orderId": orderId.uuidString.lowercased(),
                    "response": [
                        "Msg": [
                            "order": [
                                "order_id": orderId.uuidString.lowercased(),
                                "trip_id": tripId.uuidString.lowercased(),
                                "coordinates": [
                                    "latitude": 33.7490,
                                    "longitude": -84.3880
                                ],
                                "address": "123 Main St, Atlanta, GA 30301",
                                "address_display_line1": "123 Main St",
                                "address_display_line2": "Atlanta, GA 30301"
                            ] as [String: Any]
                        ] as [String: Any]
                    ] as [String: Any]
                ]
            ),
            type: "log"
        )
    }

    private func makeDeliveryOrderLogWithoutCoordinates() -> DataDogLogEntry {
        DataDogLogEntry(
            id: UUID().uuidString,
            attributes: DataDogLogAttributes(
                timestamp: ISO8601DateFormatter().string(from: Date()),
                message: "handled request for GetDeliveryOrder",
                attributes: [
                    "response": [
                        "Msg": [
                            "order": [
                                "order_id": UUID().uuidString.lowercased(),
                                "address": "123 Main St, Atlanta, GA 30301"
                            ] as [String: Any]
                        ] as [String: Any]
                    ] as [String: Any]
                ]
            ),
            type: "log"
        )
    }

    private func makeDeliveryOrderLogWithFloatCoordinates(orderId: UUID) -> DataDogLogEntry {
        DataDogLogEntry(
            id: UUID().uuidString,
            attributes: DataDogLogAttributes(
                timestamp: ISO8601DateFormatter().string(from: Date()),
                message: "handled request for GetDeliveryOrder",
                attributes: [
                    "response": [
                        "Msg": [
                            "order": [
                                "order_id": orderId.uuidString.lowercased(),
                                "coordinates": [
                                    "latitude": Float(33.7490),
                                    "longitude": Float(-84.3880)
                                ],
                                "address": "123 Main St"
                            ] as [String: Any]
                        ] as [String: Any]
                    ] as [String: Any]
                ]
            ),
            type: "log"
        )
    }

    private func makeLocationDetailsLog(locationNumber: String) -> DataDogLogEntry {
        DataDogLogEntry(
            id: UUID().uuidString,
            attributes: DataDogLogAttributes(
                timestamp: ISO8601DateFormatter().string(from: Date()),
                message: "handled request for GetLocationsDetails",
                attributes: [
                    "response": [
                        "Msg": [
                            "locations": [
                                [
                                    "location_number": locationNumber,
                                    "name": "West Columbia",
                                    "coordinates": [
                                        "latitude": 33.98325,
                                        "longitude": -81.096
                                    ],
                                    "address": [
                                        "address1": "2299 Augusta Rd",
                                        "city": "West Columbia",
                                        "state": "SC",
                                        "zip": "29169"
                                    ]
                                ] as [String: Any]
                            ]
                        ] as [String: Any]
                    ] as [String: Any]
                ]
            ),
            type: "log"
        )
    }

    private func makeDeliveryDestination(orderId: UUID) -> DeliveryDestination {
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

    // MARK: - OutForDelivery Parsing Test Helpers

    private func makeOutForDeliveryLog(orderId: UUID) -> DataDogLogEntry {
        DataDogLogEntry(
            id: UUID().uuidString,
            attributes: DataDogLogAttributes(
                timestamp: ISO8601DateFormatter().string(from: Date()),
                message: "Order Out For Delivery",
                attributes: [
                    "cfadEventName": "OrderOutForDelivery",
                    "orderId": orderId.uuidString.lowercased(),
                    "order": [
                        "OrderID": orderId.uuidString.lowercased(),
                        "Latitude": 36.0934931,
                        "Longitude": -80.0342805,
                        "DeliveryAddress": [
                            "AddressLine1": "1014 Grays Land Court",
                            "AddressLine2": "Apt. 315",
                            "AddressLine3": "Hand-off at door",
                            "City": "Kernersville",
                            "State": "NC",
                            "Zip": "27284"
                        ] as [String: Any],
                        "DropOffInstructions": "Hand-off at door; Building 300, Apt 315",
                        "DestinationPlaceID": "EkAxMDE0IEdyYXlzIExhbmQgQ291cnQ"
                    ] as [String: Any]
                ]
            ),
            type: "log"
        )
    }

    private func makeOutForDeliveryLogWithoutCoordinates(orderId: UUID) -> DataDogLogEntry {
        DataDogLogEntry(
            id: UUID().uuidString,
            attributes: DataDogLogAttributes(
                timestamp: ISO8601DateFormatter().string(from: Date()),
                message: "Order Out For Delivery",
                attributes: [
                    "cfadEventName": "OrderOutForDelivery",
                    "orderId": orderId.uuidString.lowercased(),
                    "order": [
                        "OrderID": orderId.uuidString.lowercased(),
                        "DeliveryAddress": [
                            "AddressLine1": "1014 Grays Land Court",
                            "City": "Kernersville",
                            "State": "NC",
                            "Zip": "27284"
                        ] as [String: Any]
                    ] as [String: Any]
                ]
            ),
            type: "log"
        )
    }

    private func makeOutForDeliveryLogWithFloatCoordinates(orderId: UUID) -> DataDogLogEntry {
        DataDogLogEntry(
            id: UUID().uuidString,
            attributes: DataDogLogAttributes(
                timestamp: ISO8601DateFormatter().string(from: Date()),
                message: "Order Out For Delivery",
                attributes: [
                    "cfadEventName": "OrderOutForDelivery",
                    "order": [
                        "OrderID": orderId.uuidString.lowercased(),
                        "Latitude": Float(36.0934931),
                        "Longitude": Float(-80.0342805),
                        "DeliveryAddress": [
                            "AddressLine1": "1014 Grays Land Court",
                            "City": "Kernersville",
                            "State": "NC",
                            "Zip": "27284"
                        ] as [String: Any]
                    ] as [String: Any]
                ]
            ),
            type: "log"
        )
    }

    // MARK: - parseOutForDeliveryDestination Tests

    func testParseOutForDeliveryDestination_ReturnsNil_WhenNoOrderData() {
        let logEntry = makeEmptyLog()

        let result = enrichmentService.parseOutForDeliveryDestination(from: logEntry)

        XCTAssertNil(result)
    }

    func testParseOutForDeliveryDestination_ReturnsNil_WhenMissingCoordinates() {
        let orderId = UUID()
        let logEntry = makeOutForDeliveryLogWithoutCoordinates(orderId: orderId)

        let result = enrichmentService.parseOutForDeliveryDestination(from: logEntry)

        XCTAssertNil(result)
    }

    func testParseOutForDeliveryDestination_ReturnsDestination_WhenValidData() {
        let orderId = UUID()
        let logEntry = makeOutForDeliveryLog(orderId: orderId)

        let result = enrichmentService.parseOutForDeliveryDestination(from: logEntry)

        XCTAssertNotNil(result)
        guard let destination = result else { return }

        XCTAssertEqual(destination.orderId, orderId)
        XCTAssertEqual(destination.latitude, 36.0934931, accuracy: 0.0001)
        XCTAssertEqual(destination.longitude, -80.0342805, accuracy: 0.0001)
        XCTAssertTrue(destination.address.contains("1014 Grays Land Court"))
        XCTAssertTrue(destination.address.contains("Kernersville"))
        XCTAssertEqual(destination.addressDisplayLine1, "1014 Grays Land Court, Apt. 315")
        XCTAssertEqual(destination.addressDisplayLine2, "Kernersville, NC 27284")
        XCTAssertEqual(destination.dropoffInstructions, "Hand-off at door; Building 300, Apt 315")
        XCTAssertEqual(destination.destinationPlaceId, "EkAxMDE0IEdyYXlzIExhbmQgQ291cnQ")
    }

    func testParseOutForDeliveryDestination_HandlesFloatCoordinates() {
        let orderId = UUID()
        let logEntry = makeOutForDeliveryLogWithFloatCoordinates(orderId: orderId)

        let result = enrichmentService.parseOutForDeliveryDestination(from: logEntry)

        XCTAssertNotNil(result)
        guard let destination = result else { return }

        XCTAssertEqual(destination.orderId, orderId)
        // Float precision is lower, so use larger accuracy
        XCTAssertEqual(destination.latitude, Double(Float(36.0934931)), accuracy: 0.001)
        XCTAssertEqual(destination.longitude, Double(Float(-80.0342805)), accuracy: 0.001)
    }

    func testParseOutForDeliveryDestination_HandlesMinimalAddress() {
        let orderId = UUID()
        // Create log with only required fields
        let logEntry = DataDogLogEntry(
            id: UUID().uuidString,
            attributes: DataDogLogAttributes(
                timestamp: ISO8601DateFormatter().string(from: Date()),
                message: "Order Out For Delivery",
                attributes: [
                    "order": [
                        "OrderID": orderId.uuidString.lowercased(),
                        "Latitude": 36.0934931,
                        "Longitude": -80.0342805,
                        "DeliveryAddress": [
                            "AddressLine1": "123 Main St",
                            "City": "Anytown",
                            "State": "NC",
                            "Zip": "12345"
                        ] as [String: Any]
                    ] as [String: Any]
                ]
            ),
            type: "log"
        )

        let result = enrichmentService.parseOutForDeliveryDestination(from: logEntry)

        XCTAssertNotNil(result)
        guard let destination = result else { return }

        XCTAssertEqual(destination.addressDisplayLine1, "123 Main St")
        XCTAssertEqual(destination.addressDisplayLine2, "Anytown, NC 12345")
        XCTAssertNil(destination.dropoffInstructions)
        XCTAssertNil(destination.destinationPlaceId)
    }
}
