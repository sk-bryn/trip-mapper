# Contract: DataExportGenerator

**Feature**: 003-log-data-export
**Date**: 2025-12-08

## Overview

Service responsible for generating the JSON data export file from trip visualization data.

## Interface

```swift
/// Generates JSON data export files for trip visualizations.
///
/// The generator creates a single JSON file containing DataDog log metadata,
/// route segment correlations, orderIds, and waypoint counts for independent
/// verification of rendered maps.
public final class DataExportGenerator {

    // MARK: - Initialization

    /// Creates a new DataExportGenerator.
    public init()

    // MARK: - Public Methods

    /// Generates a TripDataExport from trip visualization data.
    ///
    /// - Parameters:
    ///   - tripId: The trip UUID
    ///   - logs: Array of LogFragment from DataDog (ordered by timestamp)
    ///   - route: The UnifiedRoute with gap detection info
    ///   - metadata: TripMetadata with processing flags
    /// - Returns: A populated TripDataExport ready for serialization
    public func generateExport(
        tripId: UUID,
        logs: [LogFragment],
        route: UnifiedRoute,
        metadata: TripMetadata
    ) -> TripDataExport

    /// Writes a TripDataExport to a JSON file.
    ///
    /// - Parameters:
    ///   - export: The TripDataExport to write
    ///   - path: Absolute path for the output file
    /// - Throws: `TripVisualizerError.cannotWriteOutput` if file cannot be written
    public func writeExport(_ export: TripDataExport, to path: String) throws

    /// Generates and writes a data export in one operation.
    ///
    /// Convenience method combining `generateExport` and `writeExport`.
    ///
    /// - Parameters:
    ///   - tripId: The trip UUID
    ///   - logs: Array of LogFragment from DataDog
    ///   - route: The UnifiedRoute
    ///   - metadata: TripMetadata
    ///   - outputDirectory: Directory to write the export file
    /// - Returns: Path to the written export file
    /// - Throws: `TripVisualizerError.cannotWriteOutput` on failure
    @discardableResult
    public func generateAndWrite(
        tripId: UUID,
        logs: [LogFragment],
        route: UnifiedRoute,
        metadata: TripMetadata,
        to outputDirectory: String
    ) throws -> String
}
```

## Behavior Specifications

### generateExport(tripId:logs:route:metadata:)

**Preconditions**:
- logs array is non-empty
- logs are ordered by timestamp (ascending)

**Postconditions**:
- Returns TripDataExport with all fields populated
- orderSequence contains unique orderIds in first-occurrence order
- routeSegments.count == logs.count
- summary.totalRouteSegments == routeSegments.count
- summary.totalWaypoints == sum of all segment waypointCounts
- summary.totalOrders == orderSequence.count
- summary.hasGaps reflects route.hasGaps
- summary.truncated reflects metadata.truncated
- summary.incompleteData is true if any log download failed

**Edge Cases**:
- Empty logs array: Should not be called (caller validates)
- Waypoints without orderIds: Counted in waypointCount but not in orders array
- All waypoints have same orderId: Single entry in orderSequence and orders

### writeExport(_:to:)

**Preconditions**:
- export is a valid TripDataExport
- path is a writable file path

**Postconditions**:
- File created at path with pretty-printed JSON
- JSON uses ISO8601 date format
- JSON keys are sorted alphabetically (for consistent output)

**Error Handling**:
- Directory doesn't exist: Throws cannotWriteOutput
- Permission denied: Throws cannotWriteOutput
- Disk full: Throws cannotWriteOutput

### generateAndWrite(tripId:logs:route:metadata:to:)

**File Naming**: `<tripId>-data.json`

**Postconditions**:
- Calls generateExport then writeExport
- Returns full path to written file (e.g., `/output/<tripId>/<tripId>-data.json`)

## JSON Encoding Configuration

```swift
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
encoder.dateEncodingStrategy = .iso8601
```

## Integration Points

### Called By

- `TripVisualizerService.visualize(tripId:)` - after map generation

### Dependencies

- `LogFragment` - source data for route segments
- `UnifiedRoute` - gap detection information
- `TripMetadata` - truncated/incomplete flags
- `TripDataExport` - output model
- `FileManager` - file writing

## Test Scenarios

1. **Single log with orders**: One LogFragment with 3 orderIds
2. **Multiple logs with shared orders**: Orders spanning multiple segments
3. **Logs without orderIds**: Waypoints have no orderId field
4. **Gap detection**: Route with hasGaps = true
5. **Truncated trip**: metadata.truncated = true
6. **Write failure**: Permission denied on output directory
7. **Large trip**: 50 segments with many waypoints (performance)
