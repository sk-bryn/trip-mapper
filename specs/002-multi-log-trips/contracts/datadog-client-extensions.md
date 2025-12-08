# Contract: DataDogClient Extensions

**Date**: 2025-12-07
**Feature**: 002-multi-log-trips

## Overview

Extensions to the existing DataDogClient to support fetching all log entries for a tripId instead of just the most recent.

---

## Modified Interface

### fetchAllLogs (New Method)

```swift
/// Fetches ALL log entries for a specific trip (up to limit).
/// - Parameters:
///   - tripId: The trip UUID to search for
///   - limit: Maximum logs to return (default: 50)
/// - Returns: Array of DataDogLogEntry sorted by timestamp ascending
/// - Throws: `TripVisualizerError` on failure
public func fetchAllLogs(
    tripId: UUID,
    limit: Int = 50
) async throws -> [DataDogLogEntry]
```

### Existing fetchLogs (Unchanged)

The existing `fetchLogs(tripId:)` method remains unchanged for backward compatibility. It can delegate to `fetchAllLogs` internally and return the array.

---

## Input Contract

| Parameter | Type | Required | Validation |
|-----------|------|----------|------------|
| tripId | UUID | Yes | Valid UUID |
| limit | Int | No | Default 50, min 1, max 100 |

---

## Output Contract

### Success Response

| Property | Type | Description |
|----------|------|-------------|
| return | [DataDogLogEntry] | Array of log entries, sorted by timestamp ascending |

Each DataDogLogEntry contains:
- `id: String` - DataDog log ID
- `attributes.timestamp: String` - ISO 8601 timestamp
- `attributes.attributes: [String: Any]` - Log data including segment_coords

### Empty Response

If no logs found for tripId, return empty array `[]`.

---

## API Request Changes

### Current Implementation

```json
{
  "filter": {
    "query": "@tripId:<uuid>",
    "from": "now-30d",
    "to": "now"
  },
  "sort": "timestamp",
  "page": {
    "limit": 10
  }
}
```

### Updated Implementation

```json
{
  "filter": {
    "query": "@tripId:<uuid>",
    "from": "now-30d",
    "to": "now"
  },
  "sort": "timestamp",
  "page": {
    "limit": 50
  }
}
```

Changes:
1. Increase `page.limit` from 10 to 50 (configurable)
2. Return all entries, not just first/most recent

---

## Pagination Handling

If more logs exist than the limit:
1. Return the first N logs (sorted by timestamp ascending)
2. Include metadata indicating truncation occurred
3. Caller is responsible for handling truncation (per FR-011)

**Note**: DataDog API uses cursor-based pagination. For this feature, we do NOT implement pagination - we accept truncation at 50 logs.

---

## Error Conditions

| Error | HTTP Status | Recovery |
|-------|-------------|----------|
| `missingEnvironmentVariable` | N/A | Return error (config issue) |
| `networkUnreachable` | N/A | Retry per configuration |
| `networkTimeout` | N/A | Retry per configuration |
| `httpError(401/403)` | 401/403 | Return error (auth issue) |
| `rateLimitExceeded` | 429 | Return error with backoff hint |
| `httpError(5xx)` | 500-599 | Retry per configuration |
| `tripNotFound` | 200 (empty) | Return empty array |

---

## Example Usage

```swift
let client = DataDogClient(apiKey: key, appKey: appKey, configuration: config)

// Fetch all logs for a trip
let logs = try await client.fetchAllLogs(tripId: tripUUID, limit: 50)

// logs is sorted by timestamp ascending
// logs.count <= 50
// Each log has valid segment_coords (or will be filtered by caller)
```

---

## Performance Characteristics

| Metric | Value | Notes |
|--------|-------|-------|
| Timeout | Configurable (default 30s) | Per request |
| Retry count | Configurable (default 3) | On transient failures |
| Response size | ~10KB per log | Varies by waypoint count |
| Max response | ~500KB | 50 logs × 10KB |
