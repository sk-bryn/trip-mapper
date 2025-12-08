import XCTest
@testable import TripVisualizer

final class OrderSummaryTests: XCTestCase {

    // MARK: - Initialization Tests

    func testOrderSummaryCreation() {
        let summary = OrderSummary(orderId: "ORD-001", waypointCount: 25)

        XCTAssertEqual(summary.orderId, "ORD-001")
        XCTAssertEqual(summary.waypointCount, 25)
    }

    func testOrderSummaryWithUUID() {
        let orderId = UUID()
        let summary = OrderSummary(orderId: orderId.uuidString, waypointCount: 10)

        XCTAssertEqual(summary.orderId, orderId.uuidString)
        XCTAssertEqual(summary.waypointCount, 10)
    }

    // MARK: - Validation Tests

    func testIsValidWithNonEmptyIdAndPositiveCount() {
        let summary = OrderSummary(orderId: "ORD-001", waypointCount: 1)
        XCTAssertTrue(summary.isValid)
    }

    func testIsValidWithEmptyIdReturnsFalse() {
        let summary = OrderSummary(orderId: "", waypointCount: 10)
        XCTAssertFalse(summary.isValid)
    }

    func testIsValidWithZeroCountReturnsFalse() {
        let summary = OrderSummary(orderId: "ORD-001", waypointCount: 0)
        XCTAssertFalse(summary.isValid)
    }

    func testIsValidWithNegativeCountReturnsFalse() {
        let summary = OrderSummary(orderId: "ORD-001", waypointCount: -1)
        XCTAssertFalse(summary.isValid)
    }

    // MARK: - Equatable Tests

    func testOrderSummaryEquality() {
        let summary1 = OrderSummary(orderId: "ORD-001", waypointCount: 25)
        let summary2 = OrderSummary(orderId: "ORD-001", waypointCount: 25)

        XCTAssertEqual(summary1, summary2)
    }

    func testOrderSummaryInequality() {
        let summary1 = OrderSummary(orderId: "ORD-001", waypointCount: 25)
        let summary2 = OrderSummary(orderId: "ORD-002", waypointCount: 25)

        XCTAssertNotEqual(summary1, summary2)
    }

    func testOrderSummaryInequalityByCount() {
        let summary1 = OrderSummary(orderId: "ORD-001", waypointCount: 25)
        let summary2 = OrderSummary(orderId: "ORD-001", waypointCount: 30)

        XCTAssertNotEqual(summary1, summary2)
    }

    // MARK: - Codable Tests

    func testOrderSummaryEncoding() throws {
        let summary = OrderSummary(orderId: "ORD-001", waypointCount: 25)

        let encoder = JSONEncoder()
        let data = try encoder.encode(summary)

        XCTAssertFalse(data.isEmpty)

        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("ORD-001"))
        XCTAssertTrue(json.contains("25"))
    }

    func testOrderSummaryDecoding() throws {
        let json = """
        {
            "orderId": "ORD-001",
            "waypointCount": 25
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let summary = try decoder.decode(OrderSummary.self, from: json)

        XCTAssertEqual(summary.orderId, "ORD-001")
        XCTAssertEqual(summary.waypointCount, 25)
    }

    func testOrderSummaryRoundTrip() throws {
        let original = OrderSummary(orderId: "ORD-12345", waypointCount: 42)

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(OrderSummary.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    // MARK: - Description Tests

    func testDescription() {
        let summary = OrderSummary(orderId: "ORD-001", waypointCount: 25)
        let description = summary.description

        XCTAssertTrue(description.contains("OrderSummary"))
        XCTAssertTrue(description.contains("ORD-001"))
        XCTAssertTrue(description.contains("25"))
    }
}
