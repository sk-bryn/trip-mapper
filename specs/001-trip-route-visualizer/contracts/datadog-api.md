# DataDog API Contract

**Date**: 2025-12-04
**Feature**: 001-trip-route-visualizer

## Endpoint: Log Search

**URL**: `POST https://api.datadoghq.com/api/v2/logs/events/search`

**Region Variants**:
- US1 (default): `api.datadoghq.com`
- US3: `api.us3.datadoghq.com`
- US5: `api.us5.datadoghq.com`
- EU: `api.datadoghq.eu`
- AP1: `api.ap1.datadoghq.com`

### Authentication

| Header | Value |
|--------|-------|
| `DD-API-KEY` | `$DD_API_KEY` environment variable |
| `DD-APPLICATION-KEY` | `$DD_APP_KEY` environment variable |
| `Content-Type` | `application/json` |

### Request

```json
{
  "filter": {
    "query": "env:prod @trip_id:550e8400-e29b-41d4-a716-446655440000 service:delivery-driver-service \"received request for SaveActualRouteForTrip\"",
    "from": "now-30d",
    "to": "now"
  },
  "sort": "timestamp",
  "page": {
    "limit": 10
  }
}
```

**Query Construction**:

The query filter is constructed from:
- `env:<datadogEnv>` - Environment filter (from config, default: `prod`)
- `@trip_id:<uuid>` - Trip identifier (from user input)
- `service:<datadogService>` - Service filter (from config, default: `delivery-driver-service`)
- `"received request for SaveActualRouteForTrip"` - Content match (hardcoded)

**Parameters**:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `filter.query` | String | Yes | Composite DataDog query with env, trip_id, service, and content filters |
| `filter.from` | String | Yes | Start time (relative or ISO8601) |
| `filter.to` | String | Yes | End time (relative or ISO8601) |
| `sort` | String | No | Sort order: `timestamp` or `-timestamp` |
| `page.limit` | Int | No | Results per page (expect exactly 1 result) |

### Response

**Success (200 OK)**:

```json
{
  "data": [
    {
      "id": "AQAAAZPxxx...",
      "type": "log",
      "attributes": {
        "timestamp": "2025-12-04T10:30:00.000Z",
        "status": "info",
        "service": "delivery-driver-service",
        "attributes": {
          "trip_id": "550e8400-e29b-41d4-a716-446655440000",
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
  ],
  "meta": {
    "page": {
      "after": "cursor_string_for_next_page"
    },
    "status": "done"
  }
}
```

**Error Responses**:

| Status | Meaning | Action |
|--------|---------|--------|
| 400 | Bad Request | Invalid query syntax |
| 401 | Unauthorized | Invalid API key |
| 403 | Forbidden | Insufficient permissions |
| 429 | Rate Limited | Retry with backoff |
| 500 | Server Error | Retry with backoff |

### Pagination

Not required - query is designed to return exactly one log entry per trip. If `meta.page.after` is present, this indicates an unexpected condition (multiple logs match) and should be treated as a data integrity error.

### Rate Limiting

- Default: 300 requests per hour
- Implement exponential backoff on 429 responses
- Respect `X-RateLimit-*` headers if present

### Data Extraction Path

```
response.data[0].attributes.attributes.segment_coords[]
         └─ exactly 1 log (error if 0 or >1)
                    └─ nested attributes
                                  └─ coordinate array
```

Each waypoint object:
```json
{
  "coordinates": { "latitude": 37.7749, "longitude": -122.4194 },
  "order_id": "optional-uuid-string"
}
```

**Field Details**:
- `coordinates.latitude` (Float): Latitude coordinate (-90.0 to 90.0)
- `coordinates.longitude` (Float): Longitude coordinate (-180.0 to 180.0)
- `order_id` (UUID, optional): Order being delivered; absent means return-to-restaurant segment

### Expected Result Count

- **0 logs**: Trip not found error
- **1 log**: Success - extract waypoints
- **>1 logs**: Data integrity error (expected exactly one log per trip)
