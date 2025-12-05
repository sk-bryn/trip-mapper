# Data Model: Trip Route Visualizer CLI

**Date**: 2025-12-04
**Feature**: 001-trip-route-visualizer

## Entities

### Trip

Represents a complete delivery journey extracted from a single log entry.

| Field | Type | Description | Validation |
|-------|------|-------------|------------|
| id | UUID | Unique trip identifier | Valid UUID format required |
| logId | String | DataDog log ID for reference | Required |
| logLink | String | URL link to the source log in DataDog | Required |
| waypoints | [Waypoint] | Ordered list of waypoints from segment_coords | Minimum 2 waypoints |
| timestamp | Date | When the log was recorded | Required |

**Relationships**:
- Contains 2..* Waypoint (ordered as they appear in segment_coords)
- Maps to exactly 1 log entry (multiple logs is an error)

**State Transitions**: N/A (read-only from logs)

**Constraints**:
- Exactly one log must exist per trip ID
- If query returns multiple logs, fail with data integrity error

---

### Waypoint

A single point along the route extracted from the `segment_coords` array.

| Field | Type | Description | Validation |
|-------|------|-------------|------------|
| latitude | Double | Latitude from `coordinates.latitude` | -90.0 to 90.0 |
| longitude | Double | Longitude from `coordinates.longitude` | -180.0 to 180.0 |
| orderId | UUID? | Order being delivered (from `order_id`) | Valid UUID if present |

**Relationships**:
- Belongs to 1 Trip

**Business Rules**:
- If `orderId` is present: waypoint is part of a delivery to a customer
- If `orderId` is absent: waypoint represents return-to-restaurant segment

**Validation Rules**:
- Latitude must be within valid range
- Longitude must be within valid range
- Invalid coordinates are skipped with warning logged

---

### Configuration

Application configuration loaded from file or defaults.

| Field | Type | Description | Default |
|-------|------|-------------|---------|
| outputDirectory | String | Where to save generated files | Current directory |
| outputFormats | [OutputFormat] | Which outputs to generate | [.image, .html] |
| datadogRegion | String | DataDog API region | "us1" |
| datadogEnv | String | DataDog environment filter (`prod` or `test`) | "prod" |
| datadogService | String | DataDog service filter | "delivery-driver-service" |
| mapWidth | Int | Static map width in pixels | 800 |
| mapHeight | Int | Static map height in pixels | 600 |
| logLevel | LogLevel | Logging verbosity | .info |
| retryAttempts | Int | Network retry count | 3 |
| timeoutSeconds | Int | Network timeout | 30 |

**Source**: `~/.tripvisualizer/config.json` or `./config.json`

**DataDog Query Construction**: The query is built as:
```
env:<datadogEnv> @trip_id:<user-provided-uuid> service:<datadogService> "received request for SaveActualRouteForTrip"
```

---

### OutputFormat (Enum)

```swift
enum OutputFormat: String, Codable {
    case image  // PNG static map
    case html   // Interactive HTML with embedded Google Maps
    case url    // Google Maps URL printed to stdout
}
```

---

### LogLevel (Enum)

```swift
enum LogLevel: String, Codable {
    case debug
    case info
    case warning
    case error
}
```

---

## DataDog Log Structure

Expected structure of logs fetched from DataDog. **Exactly one log entry should be returned per trip ID.**

```json
{
  "data": [
    {
      "id": "log-id-123",
      "attributes": {
        "timestamp": "2025-12-04T10:30:00Z",
        "attributes": {
          "tripID": "550e8400-e29b-41d4-a716-446655440000",
          "segment_coords": [
            {
              "coordinates": { "latitude": 37.7749, "longitude": -122.4194 },
              "order_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
            },
            {
              "coordinates": { "latitude": 37.7751, "longitude": -122.4180 },
              "order_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
            },
            {
              "coordinates": { "latitude": 37.7755, "longitude": -122.4165 }
            }
          ]
        }
      }
    }
  ]
}
```

**Parsing Path**: `data[0].attributes.attributes.segment_coords[]`

**Field Details**:
- `coordinates.latitude` (Float): Latitude coordinate
- `coordinates.longitude` (Float): Longitude coordinate
- `order_id` (UUID, optional): Order being delivered; absent means return-to-restaurant

**Validation**:
- `data.length` must equal 1 (error if 0 or >1)
- Each waypoint must have valid `coordinates.latitude` and `coordinates.longitude`

---

## Visualization Output

### Static Image (PNG)

- Generated via Google Maps Static API
- Polyline encoded for URL efficiency
- Markers at start (green) and end (red) points
- Auto-zoom to fit all waypoints

### Interactive HTML

- Self-contained HTML file with embedded Google Maps JavaScript API
- API key injected at generation time
- Polyline drawn with route styling
- Start/end markers with info windows
- Pan and zoom enabled

### URL Output

- Google Maps URL with encoded path
- Suitable for sharing or opening in browser
- Limited by URL length constraints

---

## Entity Diagram

```
┌─────────────────────┐
│        Trip         │
├─────────────────────┤
│ id: UUID            │
│ logId: String       │
│ logLink: String     │
│ timestamp: Date     │
│ waypoints: []       │──────┐
└─────────────────────┘      │ 2..*
                             ▼
                      ┌─────────────────────┐
                      │      Waypoint       │
                      ├─────────────────────┤
                      │ latitude: Double    │
                      │ longitude: Double   │
                      │ orderId: UUID?      │
                      └─────────────────────┘

Note: orderId absent = return-to-restaurant segment
```
