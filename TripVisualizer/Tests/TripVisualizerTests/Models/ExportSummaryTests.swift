import XCTest
@testable import TripVisualizer

final class ExportSummaryTests: XCTestCase {

    // MARK: - Initialization Tests

    func testExportSummaryCreation() {
        let summary = ExportSummary(
            totalRouteSegments: 5,
            totalWaypoints: 270,
            totalOrders: 3,
            hasGaps: true,
            truncated: false,
            incompleteData: false
        )

        XCTAssertEqual(summary.totalRouteSegments, 5)
        XCTAssertEqual(summary.totalWaypoints, 270)
        XCTAssertEqual(summary.totalOrders, 3)
        XCTAssertTrue(summary.hasGaps)
        XCTAssertFalse(summary.truncated)
        XCTAssertFalse(summary.incompleteData)
    }

    func testExportSummaryWithAllFlags() {
        let summary = ExportSummary(
            totalRouteSegments: 50,
            totalWaypoints: 5000,
            totalOrders: 10,
            hasGaps: true,
            truncated: true,
            incompleteData: true
        )

        XCTAssertTrue(summary.hasGaps)
        XCTAssertTrue(summary.truncated)
        XCTAssertTrue(summary.incompleteData)
    }

    // MARK: - Validation Tests

    func testIsValidWithValidCounts() {
        let summary = ExportSummary(
            totalRouteSegments: 5,
            totalWaypoints: 100,
            totalOrders: 3,
            hasGaps: false,
            truncated: false,
            incompleteData: false
        )

        XCTAssertTrue(summary.isValid)
    }

    func testIsValidWithZeroCounts() {
        let summary = ExportSummary(
            totalRouteSegments: 0,
            totalWaypoints: 0,
            totalOrders: 0,
            hasGaps: false,
            truncated: false,
            incompleteData: false
        )

        XCTAssertTrue(summary.isValid)
    }

    func testIsValidWithNegativeSegmentsReturnsFalse() {
        let summary = ExportSummary(
            totalRouteSegments: -1,
            totalWaypoints: 100,
            totalOrders: 3,
            hasGaps: false,
            truncated: false,
            incompleteData: false
        )

        XCTAssertFalse(summary.isValid)
    }

    func testIsValidWithNegativeWaypointsReturnsFalse() {
        let summary = ExportSummary(
            totalRouteSegments: 5,
            totalWaypoints: -1,
            totalOrders: 3,
            hasGaps: false,
            truncated: false,
            incompleteData: false
        )

        XCTAssertFalse(summary.isValid)
    }

    func testIsValidWithNegativeOrdersReturnsFalse() {
        let summary = ExportSummary(
            totalRouteSegments: 5,
            totalWaypoints: 100,
            totalOrders: -1,
            hasGaps: false,
            truncated: false,
            incompleteData: false
        )

        XCTAssertFalse(summary.isValid)
    }

    // MARK: - Equatable Tests

    func testExportSummaryEquality() {
        let summary1 = ExportSummary(
            totalRouteSegments: 5,
            totalWaypoints: 270,
            totalOrders: 3,
            hasGaps: true,
            truncated: false,
            incompleteData: false
        )

        let summary2 = ExportSummary(
            totalRouteSegments: 5,
            totalWaypoints: 270,
            totalOrders: 3,
            hasGaps: true,
            truncated: false,
            incompleteData: false
        )

        XCTAssertEqual(summary1, summary2)
    }

    func testExportSummaryInequality() {
        let summary1 = ExportSummary(
            totalRouteSegments: 5,
            totalWaypoints: 270,
            totalOrders: 3,
            hasGaps: true,
            truncated: false,
            incompleteData: false
        )

        let summary2 = ExportSummary(
            totalRouteSegments: 6,
            totalWaypoints: 270,
            totalOrders: 3,
            hasGaps: true,
            truncated: false,
            incompleteData: false
        )

        XCTAssertNotEqual(summary1, summary2)
    }

    // MARK: - Codable Tests

    func testExportSummaryEncoding() throws {
        let summary = ExportSummary(
            totalRouteSegments: 5,
            totalWaypoints: 270,
            totalOrders: 3,
            hasGaps: true,
            truncated: false,
            incompleteData: false
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(summary)
        let json = String(data: data, encoding: .utf8)!

        XCTAssertTrue(json.contains("\"totalRouteSegments\":5"))
        XCTAssertTrue(json.contains("\"totalWaypoints\":270"))
        XCTAssertTrue(json.contains("\"totalOrders\":3"))
        XCTAssertTrue(json.contains("\"hasGaps\":true"))
        XCTAssertTrue(json.contains("\"truncated\":false"))
        XCTAssertTrue(json.contains("\"incompleteData\":false"))
    }

    func testExportSummaryDecoding() throws {
        let json = """
        {
            "totalRouteSegments": 5,
            "totalWaypoints": 270,
            "totalOrders": 3,
            "hasGaps": true,
            "truncated": false,
            "incompleteData": false
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let summary = try decoder.decode(ExportSummary.self, from: json)

        XCTAssertEqual(summary.totalRouteSegments, 5)
        XCTAssertEqual(summary.totalWaypoints, 270)
        XCTAssertEqual(summary.totalOrders, 3)
        XCTAssertTrue(summary.hasGaps)
        XCTAssertFalse(summary.truncated)
        XCTAssertFalse(summary.incompleteData)
    }

    func testExportSummaryRoundTrip() throws {
        let original = ExportSummary(
            totalRouteSegments: 10,
            totalWaypoints: 500,
            totalOrders: 5,
            hasGaps: true,
            truncated: true,
            incompleteData: true
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(ExportSummary.self, from: data)

        XCTAssertEqual(original, decoded)
    }

    // MARK: - Description Tests

    func testDescriptionWithNoFlags() {
        let summary = ExportSummary(
            totalRouteSegments: 5,
            totalWaypoints: 270,
            totalOrders: 3,
            hasGaps: false,
            truncated: false,
            incompleteData: false
        )

        let description = summary.description

        XCTAssertTrue(description.contains("ExportSummary"))
        XCTAssertTrue(description.contains("5 segments"))
        XCTAssertTrue(description.contains("270 waypoints"))
        XCTAssertTrue(description.contains("3 orders"))
        XCTAssertFalse(description.contains("gaps"))
        XCTAssertFalse(description.contains("truncated"))
        XCTAssertFalse(description.contains("incomplete"))
    }

    func testDescriptionWithAllFlags() {
        let summary = ExportSummary(
            totalRouteSegments: 50,
            totalWaypoints: 5000,
            totalOrders: 10,
            hasGaps: true,
            truncated: true,
            incompleteData: true
        )

        let description = summary.description

        XCTAssertTrue(description.contains("has gaps"))
        XCTAssertTrue(description.contains("truncated"))
        XCTAssertTrue(description.contains("incomplete"))
    }
}
