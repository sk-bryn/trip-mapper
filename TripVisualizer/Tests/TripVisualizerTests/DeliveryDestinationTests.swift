import XCTest
@testable import TripVisualizer

/// Tests for DeliveryDestination model
final class DeliveryDestinationTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInitialization() {
        let orderId = UUID()
        let destination = DeliveryDestination(
            orderId: orderId,
            address: "123 Main St, Apt #2, Atlanta, GA, 30301",
            addressDisplayLine1: "123 Main St, Apt #2",
            addressDisplayLine2: "Atlanta, GA 30301",
            latitude: 33.7490,
            longitude: -84.3880,
            dropoffInstructions: "Leave at front door"
        )

        XCTAssertEqual(destination.orderId, orderId)
        XCTAssertEqual(destination.address, "123 Main St, Apt #2, Atlanta, GA, 30301")
        XCTAssertEqual(destination.addressDisplayLine1, "123 Main St, Apt #2")
        XCTAssertEqual(destination.addressDisplayLine2, "Atlanta, GA 30301")
        XCTAssertEqual(destination.latitude, 33.7490)
        XCTAssertEqual(destination.longitude, -84.3880)
        XCTAssertEqual(destination.dropoffInstructions, "Leave at front door")
    }

    func testInitializationWithNilDropoffInstructions() {
        let destination = makeDeliveryDestination(dropoffInstructions: nil)
        XCTAssertNil(destination.dropoffInstructions)
    }

    // MARK: - Coordinate Validation Tests

    func testHasValidCoordinates_ValidCoordinates() {
        let destination = makeDeliveryDestination(latitude: 33.7490, longitude: -84.3880)
        XCTAssertTrue(destination.hasValidCoordinates)
    }

    func testHasValidCoordinates_AtBoundaries() {
        // Latitude boundaries
        let northPole = makeDeliveryDestination(latitude: 90.0, longitude: 0.0)
        XCTAssertTrue(northPole.hasValidCoordinates)

        let southPole = makeDeliveryDestination(latitude: -90.0, longitude: 0.0)
        XCTAssertTrue(southPole.hasValidCoordinates)

        // Longitude boundaries
        let eastBoundary = makeDeliveryDestination(latitude: 0.0, longitude: 180.0)
        XCTAssertTrue(eastBoundary.hasValidCoordinates)

        let westBoundary = makeDeliveryDestination(latitude: 0.0, longitude: -180.0)
        XCTAssertTrue(westBoundary.hasValidCoordinates)
    }

    func testHasValidCoordinates_InvalidLatitude() {
        let tooHigh = makeDeliveryDestination(latitude: 91.0, longitude: 0.0)
        XCTAssertFalse(tooHigh.hasValidCoordinates)

        let tooLow = makeDeliveryDestination(latitude: -91.0, longitude: 0.0)
        XCTAssertFalse(tooLow.hasValidCoordinates)
    }

    func testHasValidCoordinates_InvalidLongitude() {
        let tooHigh = makeDeliveryDestination(latitude: 0.0, longitude: 181.0)
        XCTAssertFalse(tooHigh.hasValidCoordinates)

        let tooLow = makeDeliveryDestination(latitude: 0.0, longitude: -181.0)
        XCTAssertFalse(tooLow.hasValidCoordinates)
    }

    // MARK: - Formatted Address Tests

    func testFormattedAddress_WithDisplayLines() {
        let destination = makeDeliveryDestination(
            addressDisplayLine1: "123 Main St",
            addressDisplayLine2: "Atlanta, GA 30301"
        )
        XCTAssertEqual(destination.formattedAddress, "123 Main St, Atlanta, GA 30301")
    }

    func testFormattedAddress_WithEmptyDisplayLine1() {
        let destination = DeliveryDestination(
            orderId: UUID(),
            address: "Full address string",
            addressDisplayLine1: "",
            addressDisplayLine2: "Atlanta, GA 30301",
            latitude: 33.7490,
            longitude: -84.3880,
            dropoffInstructions: nil
        )
        XCTAssertEqual(destination.formattedAddress, "Full address string")
    }

    func testFormattedAddress_WithEmptyDisplayLine2() {
        let destination = DeliveryDestination(
            orderId: UUID(),
            address: "Full address string",
            addressDisplayLine1: "123 Main St",
            addressDisplayLine2: "",
            latitude: 33.7490,
            longitude: -84.3880,
            dropoffInstructions: nil
        )
        XCTAssertEqual(destination.formattedAddress, "Full address string")
    }

    // MARK: - Short Description Tests

    func testShortDescription_ShortAddress() {
        let destination = makeDeliveryDestination(addressDisplayLine1: "123 Main St")
        XCTAssertEqual(destination.shortDescription, "123 Main St")
    }

    func testShortDescription_LongAddress() {
        let longAddress = "12345 Very Long Street Name That Exceeds Limit"
        let destination = makeDeliveryDestination(addressDisplayLine1: longAddress)
        XCTAssertEqual(destination.shortDescription.count, 30)
        XCTAssertTrue(destination.shortDescription.hasSuffix("..."))
    }

    func testShortDescription_EmptyDisplayLine1() {
        let destination = DeliveryDestination(
            orderId: UUID(),
            address: "Full Address",
            addressDisplayLine1: "",
            addressDisplayLine2: "City, ST 12345",
            latitude: 33.7490,
            longitude: -84.3880,
            dropoffInstructions: nil
        )
        XCTAssertEqual(destination.shortDescription, "Full Address")
    }

    // MARK: - Factory Method Tests

    func testFromOrderResponse_ValidData() {
        let orderId = UUID()
        let orderResponse: [String: Any] = [
            "coordinates": [
                "latitude": 33.7490,
                "longitude": -84.3880
            ],
            "address": "123 Main St, Atlanta, GA 30301",
            "address_display_line1": "123 Main St",
            "address_display_line2": "Atlanta, GA 30301",
            "dropoff_instructions": "Ring doorbell",
            "destination_place_id": "ChIJ8dI_QZfV2IcRlfqLN6T4Ru4"
        ]

        let destination = DeliveryDestination.from(orderId: orderId, orderResponse: orderResponse)

        XCTAssertNotNil(destination)
        XCTAssertEqual(destination?.orderId, orderId)
        XCTAssertEqual(destination?.latitude, 33.7490)
        XCTAssertEqual(destination?.longitude, -84.3880)
        XCTAssertEqual(destination?.address, "123 Main St, Atlanta, GA 30301")
        XCTAssertEqual(destination?.addressDisplayLine1, "123 Main St")
        XCTAssertEqual(destination?.addressDisplayLine2, "Atlanta, GA 30301")
        XCTAssertEqual(destination?.dropoffInstructions, "Ring doorbell")
        XCTAssertEqual(destination?.destinationPlaceId, "ChIJ8dI_QZfV2IcRlfqLN6T4Ru4")
    }

    func testFromOrderResponse_FloatCoordinates() {
        let orderId = UUID()
        let orderResponse: [String: Any] = [
            "coordinates": [
                "latitude": Float(33.7490),
                "longitude": Float(-84.3880)
            ],
            "address": "123 Main St",
            "address_display_line1": "123 Main St",
            "address_display_line2": "Atlanta, GA 30301"
        ]

        let destination = DeliveryDestination.from(orderId: orderId, orderResponse: orderResponse)

        XCTAssertNotNil(destination)
        if let dest = destination {
            XCTAssertEqual(dest.latitude, Double(Float(33.7490)), accuracy: 0.0001)
            XCTAssertEqual(dest.longitude, Double(Float(-84.3880)), accuracy: 0.0001)
        }
    }

    func testFromOrderResponse_MissingCoordinates() {
        let orderId = UUID()
        let orderResponse: [String: Any] = [
            "address": "123 Main St"
        ]

        let destination = DeliveryDestination.from(orderId: orderId, orderResponse: orderResponse)

        XCTAssertNil(destination)
    }

    func testFromOrderResponse_MissingLatitude() {
        let orderId = UUID()
        let orderResponse: [String: Any] = [
            "coordinates": [
                "longitude": -84.3880
            ],
            "address": "123 Main St"
        ]

        let destination = DeliveryDestination.from(orderId: orderId, orderResponse: orderResponse)

        XCTAssertNil(destination)
    }

    func testFromOrderResponse_MissingOptionalFields() {
        let orderId = UUID()
        let orderResponse: [String: Any] = [
            "coordinates": [
                "latitude": 33.7490,
                "longitude": -84.3880
            ]
        ]

        let destination = DeliveryDestination.from(orderId: orderId, orderResponse: orderResponse)

        XCTAssertNotNil(destination)
        XCTAssertEqual(destination?.address, "")
        XCTAssertEqual(destination?.addressDisplayLine1, "")
        XCTAssertEqual(destination?.addressDisplayLine2, "")
        XCTAssertNil(destination?.dropoffInstructions)
    }

    // MARK: - Codable Tests

    func testEncodeDecode() throws {
        let orderId = UUID()
        let original = DeliveryDestination(
            orderId: orderId,
            address: "123 Main St, Atlanta, GA 30301",
            addressDisplayLine1: "123 Main St",
            addressDisplayLine2: "Atlanta, GA 30301",
            latitude: 33.7490,
            longitude: -84.3880,
            dropoffInstructions: "Leave at door"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DeliveryDestination.self, from: data)

        XCTAssertEqual(decoded.orderId, original.orderId)
        XCTAssertEqual(decoded.address, original.address)
        XCTAssertEqual(decoded.addressDisplayLine1, original.addressDisplayLine1)
        XCTAssertEqual(decoded.addressDisplayLine2, original.addressDisplayLine2)
        XCTAssertEqual(decoded.latitude, original.latitude)
        XCTAssertEqual(decoded.longitude, original.longitude)
        XCTAssertEqual(decoded.dropoffInstructions, original.dropoffInstructions)
    }

    func testEncodeDecodeWithNilDropoffInstructions() throws {
        let original = makeDeliveryDestination(dropoffInstructions: nil)

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DeliveryDestination.self, from: data)

        XCTAssertNil(decoded.dropoffInstructions)
    }

    // MARK: - Equatable Tests

    func testEquatable_SameValues() {
        let orderId = UUID()
        let destination1 = DeliveryDestination(
            orderId: orderId,
            address: "123 Main St",
            addressDisplayLine1: "123 Main St",
            addressDisplayLine2: "Atlanta, GA 30301",
            latitude: 33.7490,
            longitude: -84.3880,
            dropoffInstructions: nil
        )
        let destination2 = DeliveryDestination(
            orderId: orderId,
            address: "123 Main St",
            addressDisplayLine1: "123 Main St",
            addressDisplayLine2: "Atlanta, GA 30301",
            latitude: 33.7490,
            longitude: -84.3880,
            dropoffInstructions: nil
        )

        XCTAssertEqual(destination1, destination2)
    }

    func testEquatable_DifferentOrderId() {
        let destination1 = makeDeliveryDestination(orderId: UUID())
        let destination2 = makeDeliveryDestination(orderId: UUID())

        XCTAssertNotEqual(destination1, destination2)
    }

    func testEquatable_DifferentCoordinates() {
        let orderId = UUID()
        let destination1 = makeDeliveryDestination(orderId: orderId, latitude: 33.7490, longitude: -84.3880)
        let destination2 = makeDeliveryDestination(orderId: orderId, latitude: 34.0522, longitude: -118.2437)

        XCTAssertNotEqual(destination1, destination2)
    }

    // MARK: - Test Helpers

    private func makeDeliveryDestination(
        orderId: UUID = UUID(),
        address: String = "123 Main St, Atlanta, GA 30301",
        addressDisplayLine1: String = "123 Main St",
        addressDisplayLine2: String = "Atlanta, GA 30301",
        latitude: Double = 33.7490,
        longitude: Double = -84.3880,
        dropoffInstructions: String? = nil
    ) -> DeliveryDestination {
        DeliveryDestination(
            orderId: orderId,
            address: address,
            addressDisplayLine1: addressDisplayLine1,
            addressDisplayLine2: addressDisplayLine2,
            latitude: latitude,
            longitude: longitude,
            dropoffInstructions: dropoffInstructions
        )
    }
}
