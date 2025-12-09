import XCTest
@testable import TripVisualizer

/// Tests for RestaurantLocation model
final class RestaurantLocationTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInitialization() {
        let location = RestaurantLocation(
            locationNumber: "00070",
            name: "West Columbia",
            address1: "2299 Augusta Rd",
            address2: "Suite 100",
            city: "West Columbia",
            state: "SC",
            zip: "29169",
            latitude: 33.98325,
            longitude: -81.096,
            operatorName: "John Smith",
            timeZone: "America/New_York"
        )

        XCTAssertEqual(location.locationNumber, "00070")
        XCTAssertEqual(location.name, "West Columbia")
        XCTAssertEqual(location.address1, "2299 Augusta Rd")
        XCTAssertEqual(location.address2, "Suite 100")
        XCTAssertEqual(location.city, "West Columbia")
        XCTAssertEqual(location.state, "SC")
        XCTAssertEqual(location.zip, "29169")
        XCTAssertEqual(location.latitude, 33.98325)
        XCTAssertEqual(location.longitude, -81.096)
        XCTAssertEqual(location.operatorName, "John Smith")
        XCTAssertEqual(location.timeZone, "America/New_York")
    }

    func testInitializationWithNilOptionals() {
        let location = makeRestaurantLocation(address2: nil, operatorName: nil, timeZone: nil)

        XCTAssertNil(location.address2)
        XCTAssertNil(location.operatorName)
        XCTAssertNil(location.timeZone)
    }

    // MARK: - Coordinate Validation Tests

    func testHasValidCoordinates_ValidCoordinates() {
        let location = makeRestaurantLocation(latitude: 33.98325, longitude: -81.096)
        XCTAssertTrue(location.hasValidCoordinates)
    }

    func testHasValidCoordinates_AtBoundaries() {
        // Latitude boundaries
        let northPole = makeRestaurantLocation(latitude: 90.0, longitude: 0.0)
        XCTAssertTrue(northPole.hasValidCoordinates)

        let southPole = makeRestaurantLocation(latitude: -90.0, longitude: 0.0)
        XCTAssertTrue(southPole.hasValidCoordinates)

        // Longitude boundaries
        let eastBoundary = makeRestaurantLocation(latitude: 0.0, longitude: 180.0)
        XCTAssertTrue(eastBoundary.hasValidCoordinates)

        let westBoundary = makeRestaurantLocation(latitude: 0.0, longitude: -180.0)
        XCTAssertTrue(westBoundary.hasValidCoordinates)
    }

    func testHasValidCoordinates_InvalidLatitude() {
        let tooHigh = makeRestaurantLocation(latitude: 91.0, longitude: 0.0)
        XCTAssertFalse(tooHigh.hasValidCoordinates)

        let tooLow = makeRestaurantLocation(latitude: -91.0, longitude: 0.0)
        XCTAssertFalse(tooLow.hasValidCoordinates)
    }

    func testHasValidCoordinates_InvalidLongitude() {
        let tooHigh = makeRestaurantLocation(latitude: 0.0, longitude: 181.0)
        XCTAssertFalse(tooHigh.hasValidCoordinates)

        let tooLow = makeRestaurantLocation(latitude: 0.0, longitude: -181.0)
        XCTAssertFalse(tooLow.hasValidCoordinates)
    }

    // MARK: - Location Number Validation Tests

    func testHasValidLocationNumber_Valid() {
        let location = makeRestaurantLocation(locationNumber: "00070")
        XCTAssertTrue(location.hasValidLocationNumber)
    }

    func testHasValidLocationNumber_WrongLength() {
        let tooShort = makeRestaurantLocation(locationNumber: "0070")
        XCTAssertFalse(tooShort.hasValidLocationNumber)

        let tooLong = makeRestaurantLocation(locationNumber: "000070")
        XCTAssertFalse(tooLong.hasValidLocationNumber)
    }

    func testHasValidLocationNumber_NonNumeric() {
        let withLetters = makeRestaurantLocation(locationNumber: "0007A")
        XCTAssertFalse(withLetters.hasValidLocationNumber)
    }

    // MARK: - Formatted Address Tests

    func testFormattedAddress_WithAddress2() {
        let location = RestaurantLocation(
            locationNumber: "00070",
            name: "West Columbia",
            address1: "2299 Augusta Rd",
            address2: "Suite 100",
            city: "West Columbia",
            state: "SC",
            zip: "29169",
            latitude: 33.98325,
            longitude: -81.096,
            operatorName: nil,
            timeZone: nil
        )
        XCTAssertEqual(location.formattedAddress, "2299 Augusta Rd, Suite 100, West Columbia, SC 29169")
    }

    func testFormattedAddress_WithoutAddress2() {
        let location = makeRestaurantLocation(address2: nil)
        XCTAssertEqual(location.formattedAddress, "2299 Augusta Rd, West Columbia, SC 29169")
    }

    func testFormattedAddress_WithEmptyAddress2() {
        let location = makeRestaurantLocation(address2: "")
        XCTAssertEqual(location.formattedAddress, "2299 Augusta Rd, West Columbia, SC 29169")
    }

    // MARK: - Short Description Tests

    func testShortDescription() {
        let location = makeRestaurantLocation(locationNumber: "00070", name: "West Columbia")
        XCTAssertEqual(location.shortDescription, "West Columbia (#00070)")
    }

    // MARK: - Factory Method Tests

    func testFromLocationData_ValidData() {
        let locationData: [String: Any] = [
            "locationNumber": "00070",
            "name": "West Columbia",
            "coordinates": [
                "latitude": 33.98325,
                "longitude": -81.096
            ],
            "address": [
                "address1": "2299 Augusta Rd",
                "address2": "Suite 100",
                "city": "West Columbia",
                "state": "SC",
                "zip": "29169"
            ],
            "operatorName": "John Smith",
            "timeZone": "America/New_York"
        ]

        let location = RestaurantLocation.from(locationData: locationData)

        XCTAssertNotNil(location)
        guard let loc = location else { return }

        XCTAssertEqual(loc.locationNumber, "00070")
        XCTAssertEqual(loc.name, "West Columbia")
        XCTAssertEqual(loc.latitude, 33.98325, accuracy: 0.0001)
        XCTAssertEqual(loc.longitude, -81.096, accuracy: 0.0001)
        XCTAssertEqual(loc.address1, "2299 Augusta Rd")
        XCTAssertEqual(loc.address2, "Suite 100")
        XCTAssertEqual(loc.city, "West Columbia")
        XCTAssertEqual(loc.state, "SC")
        XCTAssertEqual(loc.zip, "29169")
        XCTAssertEqual(loc.operatorName, "John Smith")
        XCTAssertEqual(loc.timeZone, "America/New_York")
    }

    func testFromLocationData_FloatCoordinates() {
        let locationData: [String: Any] = [
            "locationNumber": "00070",
            "name": "West Columbia",
            "coordinates": [
                "latitude": Float(33.98325),
                "longitude": Float(-81.096)
            ],
            "address": [:]
        ]

        let location = RestaurantLocation.from(locationData: locationData)

        XCTAssertNotNil(location)
        if let loc = location {
            XCTAssertEqual(loc.latitude, Double(Float(33.98325)), accuracy: 0.001)
            XCTAssertEqual(loc.longitude, Double(Float(-81.096)), accuracy: 0.001)
        }
    }

    func testFromLocationData_MissingLocationNumber() {
        let locationData: [String: Any] = [
            "name": "West Columbia",
            "coordinates": [
                "latitude": 33.98325,
                "longitude": -81.096
            ]
        ]

        let location = RestaurantLocation.from(locationData: locationData)

        XCTAssertNil(location)
    }

    func testFromLocationData_MissingName() {
        let locationData: [String: Any] = [
            "locationNumber": "00070",
            "coordinates": [
                "latitude": 33.98325,
                "longitude": -81.096
            ]
        ]

        let location = RestaurantLocation.from(locationData: locationData)

        XCTAssertNil(location)
    }

    func testFromLocationData_MissingCoordinates() {
        let locationData: [String: Any] = [
            "locationNumber": "00070",
            "name": "West Columbia"
        ]

        let location = RestaurantLocation.from(locationData: locationData)

        XCTAssertNil(location)
    }

    func testFromLocationData_MissingOptionalFields() {
        let locationData: [String: Any] = [
            "locationNumber": "00070",
            "name": "West Columbia",
            "coordinates": [
                "latitude": 33.98325,
                "longitude": -81.096
            ]
        ]

        let location = RestaurantLocation.from(locationData: locationData)

        XCTAssertNotNil(location)
        XCTAssertEqual(location?.address1, "")
        XCTAssertNil(location?.address2)
        XCTAssertEqual(location?.city, "")
        XCTAssertEqual(location?.state, "")
        XCTAssertEqual(location?.zip, "")
        XCTAssertNil(location?.operatorName)
        XCTAssertNil(location?.timeZone)
    }

    // MARK: - Codable Tests

    func testEncodeDecode() throws {
        let original = RestaurantLocation(
            locationNumber: "00070",
            name: "West Columbia",
            address1: "2299 Augusta Rd",
            address2: "Suite 100",
            city: "West Columbia",
            state: "SC",
            zip: "29169",
            latitude: 33.98325,
            longitude: -81.096,
            operatorName: "John Smith",
            timeZone: "America/New_York"
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RestaurantLocation.self, from: data)

        XCTAssertEqual(decoded.locationNumber, original.locationNumber)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.address1, original.address1)
        XCTAssertEqual(decoded.address2, original.address2)
        XCTAssertEqual(decoded.city, original.city)
        XCTAssertEqual(decoded.state, original.state)
        XCTAssertEqual(decoded.zip, original.zip)
        XCTAssertEqual(decoded.latitude, original.latitude)
        XCTAssertEqual(decoded.longitude, original.longitude)
        XCTAssertEqual(decoded.operatorName, original.operatorName)
        XCTAssertEqual(decoded.timeZone, original.timeZone)
    }

    func testEncodeDecodeWithNilOptionals() throws {
        let original = makeRestaurantLocation(address2: nil, operatorName: nil, timeZone: nil)

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RestaurantLocation.self, from: data)

        XCTAssertNil(decoded.address2)
        XCTAssertNil(decoded.operatorName)
        XCTAssertNil(decoded.timeZone)
    }

    // MARK: - Equatable Tests

    func testEquatable_SameValues() {
        let location1 = makeRestaurantLocation()
        let location2 = makeRestaurantLocation()
        XCTAssertEqual(location1, location2)
    }

    func testEquatable_DifferentLocationNumber() {
        let location1 = makeRestaurantLocation(locationNumber: "00070")
        let location2 = makeRestaurantLocation(locationNumber: "00071")
        XCTAssertNotEqual(location1, location2)
    }

    func testEquatable_DifferentName() {
        let location1 = makeRestaurantLocation(name: "West Columbia")
        let location2 = makeRestaurantLocation(name: "East Columbia")
        XCTAssertNotEqual(location1, location2)
    }

    // MARK: - Test Helpers

    private func makeRestaurantLocation(
        locationNumber: String = "00070",
        name: String = "West Columbia",
        address1: String = "2299 Augusta Rd",
        address2: String? = nil,
        city: String = "West Columbia",
        state: String = "SC",
        zip: String = "29169",
        latitude: Double = 33.98325,
        longitude: Double = -81.096,
        operatorName: String? = nil,
        timeZone: String? = nil
    ) -> RestaurantLocation {
        RestaurantLocation(
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
