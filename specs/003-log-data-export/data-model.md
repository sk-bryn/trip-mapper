# Data Model: Log Data Export

**Feature**: 003-log-data-export
**Date**: 2025-12-08

## Entity Relationship Diagram

```text
┌─────────────────────────────────────────────────────────────┐
│                     TripDataExport                          │
├─────────────────────────────────────────────────────────────┤
│ tripId: UUID                                                │
│ generatedAt: Date                                           │
│ summary: ExportSummary                                      │
│ orderSequence: [String]                                     │
│ routeSegments: [RouteSegmentExport]                         │
└─────────────────────────────────────────────────────────────┘
                          │
                          │ 1:1
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                     ExportSummary                           │
├─────────────────────────────────────────────────────────────┤
│ totalRouteSegments: Int                                     │
│ totalWaypoints: Int                                         │
│ totalOrders: Int                                            │
│ hasGaps: Bool                                               │
│ truncated: Bool                                             │
│ incompleteData: Bool                                        │
└─────────────────────────────────────────────────────────────┘

                          │
                          │ 1:N
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                   RouteSegmentExport                        │
├─────────────────────────────────────────────────────────────┤
│ segmentIndex: Int                                           │
│ datadogLogId: String                                        │
│ datadogUrl: String                                          │
│ timestamp: Date                                             │
│ waypointCount: Int                                          │
│ orders: [OrderSummary]                                      │
└─────────────────────────────────────────────────────────────┘
                          │
                          │ 1:N
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                     OrderSummary                            │
├─────────────────────────────────────────────────────────────┤
│ orderId: String                                             │
│ waypointCount: Int                                          │
└─────────────────────────────────────────────────────────────┘
```

## Entity Definitions

### TripDataExport

The root entity for the JSON export file. Contains all information needed to verify a trip visualization.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| tripId | UUID | Yes | The trip identifier matching the visualization |
| generatedAt | Date | Yes | ISO8601 timestamp when export was generated |
| summary | ExportSummary | Yes | Aggregate statistics for the trip |
| orderSequence | [String] | Yes | Ordered list of all orderIds in delivery sequence |
| routeSegments | [RouteSegmentExport] | Yes | Array of route segment details |

**Validation Rules**:
- tripId must be a valid UUID
- routeSegments must have at least 1 element (trips with no data don't generate export)
- orderSequence may be empty if no waypoints have orderIds

**JSON Key Mapping**: Uses camelCase (Swift default for JSONEncoder)

---

### ExportSummary

Aggregate statistics providing a quick overview of the trip.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| totalRouteSegments | Int | Yes | Number of route segments (DataDog logs) |
| totalWaypoints | Int | Yes | Sum of waypoints across all segments |
| totalOrders | Int | Yes | Count of unique orderIds |
| hasGaps | Bool | Yes | True if gaps were detected between segments |
| truncated | Bool | Yes | True if logs exceeded max limit (50) |
| incompleteData | Bool | Yes | True if any log fragments failed to download |

**Validation Rules**:
- All counts must be >= 0
- totalRouteSegments must match routeSegments.count
- totalOrders must match orderSequence.count

---

### RouteSegmentExport

Represents one route segment correlated to its source DataDog log entry.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| segmentIndex | Int | Yes | 0-based index in segment sequence |
| datadogLogId | String | Yes | DataDog log entry ID for cross-reference |
| datadogUrl | String | Yes | Direct URL to view log in DataDog console |
| timestamp | Date | Yes | ISO8601 timestamp from DataDog log |
| waypointCount | Int | Yes | Number of waypoints in this segment |
| orders | [OrderSummary] | Yes | Order details for this segment (may be empty) |

**Validation Rules**:
- segmentIndex must be unique and sequential (0, 1, 2, ...)
- datadogLogId must be non-empty
- datadogUrl must be a valid URL format
- waypointCount must be >= 0 (0 for gap segments)
- orders may be empty if segment has no orderIds

---

### OrderSummary

Aggregated information about one order within a route segment.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| orderId | String | Yes | The order identifier from waypoint data |
| waypointCount | Int | Yes | Number of waypoints with this orderId |

**Validation Rules**:
- orderId must be non-empty
- waypointCount must be > 0

---

## Factory Methods

### TripDataExport.from(tripId:logs:route:metadata:)

Creates a TripDataExport from existing trip visualization data.

```swift
static func from(
    tripId: UUID,
    logs: [LogFragment],
    route: UnifiedRoute,
    metadata: TripMetadata
) -> TripDataExport
```

**Parameters**:
- tripId: The trip UUID
- logs: Array of LogFragment from DataDog (ordered by timestamp)
- route: The UnifiedRoute with aggregated waypoints
- metadata: TripMetadata with processing info

**Behavior**:
1. Extract orderSequence from all waypoints (first occurrence order)
2. Build RouteSegmentExport for each LogFragment
3. Calculate summary statistics
4. Return populated TripDataExport

---

### RouteSegmentExport.from(index:fragment:)

Creates a RouteSegmentExport from a LogFragment.

```swift
static func from(
    index: Int,
    fragment: LogFragment
) -> RouteSegmentExport
```

**Parameters**:
- index: The segment's position in the sequence
- fragment: The source LogFragment

**Behavior**:
1. Extract datadogLogId from fragment.id
2. Use fragment.logLink for datadogUrl
3. Use fragment.timestamp for timestamp
4. Count waypoints from fragment.waypoints
5. Group waypoints by orderId to create OrderSummary array

---

## Sample JSON Output

```json
{
  "tripId": "13A40F55-D849-45F1-A8E5-FA443ACEDB4A",
  "generatedAt": "2025-12-08T04:22:45Z",
  "summary": {
    "totalRouteSegments": 5,
    "totalWaypoints": 270,
    "totalOrders": 3,
    "hasGaps": true,
    "truncated": false,
    "incompleteData": false
  },
  "orderSequence": ["ORD-001", "ORD-002", "ORD-003"],
  "routeSegments": [
    {
      "segmentIndex": 0,
      "datadogLogId": "log-abc123",
      "datadogUrl": "https://app.datadoghq.com/logs?query=@id:log-abc123",
      "timestamp": "2025-12-05T05:24:25Z",
      "waypointCount": 40,
      "orders": [
        { "orderId": "ORD-001", "waypointCount": 25 },
        { "orderId": "ORD-002", "waypointCount": 15 }
      ]
    },
    {
      "segmentIndex": 1,
      "datadogLogId": "log-def456",
      "datadogUrl": "https://app.datadoghq.com/logs?query=@id:log-def456",
      "timestamp": "2025-12-05T05:39:01Z",
      "waypointCount": 50,
      "orders": [
        { "orderId": "ORD-003", "waypointCount": 50 }
      ]
    }
  ]
}
```

## Relationships to Existing Models

| New Model | Existing Model | Relationship |
|-----------|----------------|--------------|
| RouteSegmentExport | LogFragment | 1:1 - Each segment created from one fragment |
| OrderSummary | Waypoint.orderId | N:1 - Aggregates waypoints by orderId |
| TripDataExport | UnifiedRoute | Uses route for gap detection info |
| TripDataExport | TripMetadata | Uses for truncated/incomplete flags |
