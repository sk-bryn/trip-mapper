# Research: Log Data Export

**Feature**: 003-log-data-export
**Date**: 2025-12-08

## Research Questions

### 1. JSON Export Pattern in Swift

**Decision**: Use `JSONEncoder` with `.prettyPrinted` and `.sortedKeys` output formatting

**Rationale**:
- Foundation's JSONEncoder is cross-platform (macOS + Linux)
- `.prettyPrinted` satisfies human-readability requirement (FR-008)
- `.sortedKeys` ensures consistent output for testing and diffs
- Codable protocol provides type-safe serialization

**Alternatives Considered**:
- Manual JSON string building: Rejected - error-prone, no type safety
- Third-party JSON libraries: Rejected - violates constitution (no external dependencies)

### 2. OrderId Extraction from Waypoints

**Decision**: Extract orderIds from existing `Waypoint.orderId` optional property

**Rationale**:
- Waypoint model already has optional `orderId: String?` field (from 001-trip-route-visualizer)
- Group waypoints by orderId to calculate per-order waypoint counts
- Maintain orderId sequence based on first occurrence in route

**Alternatives Considered**:
- Parse orderIds from raw DataDog log attributes: Rejected - orderId already extracted into Waypoint
- Store orderIds at fragment level: Rejected - orderIds are waypoint-level data

### 3. Route Segment to DataDog Log Correlation

**Decision**: Leverage existing `LogFragment` model which already contains log ID, timestamp, and DataDog URL

**Rationale**:
- 002-multi-log-trips already established LogFragment with all needed metadata
- Each LogFragment corresponds to one route segment in the visualization
- FragmentAggregator preserves fragment identity through aggregation

**Alternatives Considered**:
- Create new correlation structure: Rejected - duplicates existing LogFragment data
- Store correlation in UnifiedRoute: Rejected - UnifiedRoute is for visualization, not export

### 4. Export File Naming Convention

**Decision**: Use `<tripId>-data.json` in the same output directory as map files

**Rationale**:
- Matches existing output naming pattern (`<tripId>.html`, `<tripId>.png`)
- Single file per trip (per clarification)
- `.json` extension enables syntax highlighting in editors

**Alternatives Considered**:
- Include timestamp in filename: Rejected - would create multiple files on re-run
- Use different directory: Rejected - breaks association with map outputs

### 5. Integration Point in TripVisualizerService

**Decision**: Generate export after fragment aggregation, alongside map generation

**Rationale**:
- All required data (LogFragments, UnifiedRoute with orderIds) available after aggregation
- Export generation is independent of map generation (can run in parallel)
- Follows existing pattern of `generateOutputsWithSegments`

**Alternatives Considered**:
- Generate before aggregation: Rejected - missing unified waypoint counts
- Generate as separate command: Rejected - clarification specifies automatic generation

## Implementation Patterns

### Export Data Structure

```swift
struct TripDataExport: Codable {
    let tripId: UUID
    let generatedAt: Date
    let summary: ExportSummary
    let orderSequence: [String]  // Ordered list of all orderIds
    let routeSegments: [RouteSegmentExport]
}

struct ExportSummary: Codable {
    let totalRouteSegments: Int
    let totalWaypoints: Int
    let totalOrders: Int
    let hasGaps: Bool
    let truncated: Bool
}

struct RouteSegmentExport: Codable {
    let segmentIndex: Int
    let datadogLogId: String
    let datadogUrl: String
    let timestamp: Date
    let waypointCount: Int
    let orders: [OrderSummary]
}

struct OrderSummary: Codable {
    let orderId: String
    let waypointCount: Int
}
```

### OrderId Sequence Extraction

```swift
// Extract ordered sequence of orderIds from all waypoints
func extractOrderSequence(from fragments: [LogFragment]) -> [String] {
    var seen = Set<String>()
    var sequence: [String] = []

    for fragment in fragments {
        for waypoint in fragment.waypoints {
            if let orderId = waypoint.orderId, !seen.contains(orderId) {
                seen.insert(orderId)
                sequence.append(orderId)
            }
        }
    }
    return sequence
}
```

## Dependencies on Existing Code

| Component | Dependency | Notes |
|-----------|------------|-------|
| LogFragment | 002-multi-log-trips | Contains logId, timestamp, logLink, waypoints |
| Waypoint | 001-trip-route-visualizer | Contains optional orderId |
| TripVisualizerService | 002-multi-log-trips | Integration point for export generation |
| Configuration | 002-multi-log-trips | Output directory path |

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Large export files for trips with many segments | Use summary counts (no individual waypoints) - per clarification |
| Export failure blocks visualization | Generate export after map outputs; warn on failure but don't fail visualization |
| Missing orderIds in source data | Handle gracefully; export empty orders array for segments without orderIds |
