# Contract: FragmentAggregator Service

**Date**: 2025-12-07
**Feature**: 002-multi-log-trips

## Overview

The FragmentAggregator service is responsible for combining multiple LogFragments into a UnifiedRoute for visualization. This is an internal service contract (not an external API).

---

## Service Interface

```swift
/// Service for aggregating multiple log fragments into a unified route.
public protocol FragmentAggregating {
    /// Aggregates log fragments into a unified route for visualization.
    /// - Parameters:
    ///   - fragments: Array of log fragments (must be non-empty)
    ///   - gapThreshold: Time interval to consider as a gap (default: 5 minutes)
    /// - Returns: UnifiedRoute combining all fragment waypoints
    /// - Throws: AggregationError if aggregation fails
    func aggregate(
        fragments: [LogFragment],
        gapThreshold: TimeInterval
    ) throws -> UnifiedRoute
}
```

---

## Input Contract

### LogFragment Array

| Property | Type | Required | Validation |
|----------|------|----------|------------|
| fragments | [LogFragment] | Yes | Non-empty, max 50 elements |
| gapThreshold | TimeInterval | No | Default 300 seconds (5 min), min 60, max 3600 |

### Each LogFragment

| Property | Type | Required | Validation |
|----------|------|----------|------------|
| id | String | Yes | Non-empty |
| tripId | UUID | Yes | Valid UUID, all fragments must match |
| timestamp | Date | Yes | Valid date |
| waypoints | [Waypoint] | Yes | Min 2 waypoints |
| logLink | String | Yes | Non-empty |

---

## Output Contract

### UnifiedRoute

| Property | Type | Description |
|----------|------|-------------|
| tripId | UUID | Trip identifier (from fragments) |
| waypoints | [Waypoint] | All waypoints, chronologically ordered, deduplicated |
| segments | [RouteSegment] | Segments for rendering (continuous + gaps) |
| fragmentCount | Int | Number of source fragments |
| isComplete | Bool | True if all input fragments were processed |

### RouteSegment

| Property | Type | Description |
|----------|------|-------------|
| waypoints | [Waypoint] | Waypoints in this segment |
| type | SegmentType | `.continuous` or `.gap` |
| sourceFragmentId | String? | Fragment ID (nil for gaps) |

---

## Processing Rules

### 1. Fragment Ordering

Fragments are sorted by `timestamp` in ascending order (oldest first).

```text
Input:  [Fragment(t=10:05), Fragment(t=09:30), Fragment(t=10:15)]
Output: [Fragment(t=09:30), Fragment(t=10:05), Fragment(t=10:15)]
```

### 2. Waypoint Deduplication

Waypoints are considered duplicates if:
- Latitude difference < 0.00001 degrees (~1 meter)
- Longitude difference < 0.00001 degrees (~1 meter)

When duplicates found across fragments, keep the waypoint from the earlier fragment.

### 3. Gap Detection

A gap is inserted between consecutive fragments when:
```
fragment[N+1].timestamp - fragment[N].timestamp > gapThreshold
```

Gap segments contain exactly 2 waypoints:
1. Last waypoint of fragment N
2. First waypoint of fragment N+1

### 4. Segment Construction

```text
For each fragment:
  Create RouteSegment(type: .continuous, waypoints: fragment.waypoints)

  If gap detected before next fragment:
    Create RouteSegment(type: .gap, waypoints: [lastWaypoint, nextFirstWaypoint])
```

---

## Error Conditions

| Error | Condition | Recovery |
|-------|-----------|----------|
| `emptyFragments` | Input array is empty | Return error (cannot proceed) |
| `tripIdMismatch` | Fragments have different tripIds | Return error (data integrity issue) |
| `invalidFragment` | Fragment has <2 waypoints | Skip fragment, log warning |
| `allFragmentsInvalid` | All fragments failed validation | Return error |

---

## Example Usage

```swift
let aggregator = FragmentAggregator()

let fragments = [
    LogFragment(id: "log1", tripId: tripId, timestamp: t1, waypoints: [w1, w2, w3]),
    LogFragment(id: "log2", tripId: tripId, timestamp: t2, waypoints: [w4, w5]),
    LogFragment(id: "log3", tripId: tripId, timestamp: t3, waypoints: [w6, w7, w8])
]

let route = try aggregator.aggregate(
    fragments: fragments,
    gapThreshold: 300 // 5 minutes
)

// Result:
// route.segments = [
//   RouteSegment(type: .continuous, waypoints: [w1, w2, w3]),
//   RouteSegment(type: .gap, waypoints: [w3, w4]),  // if gap > 5min
//   RouteSegment(type: .continuous, waypoints: [w4, w5]),
//   RouteSegment(type: .continuous, waypoints: [w6, w7, w8])
// ]
```

---

## Performance Characteristics

| Operation | Complexity | Notes |
|-----------|------------|-------|
| Sort fragments | O(n log n) | n = number of fragments |
| Deduplicate waypoints | O(m) | m = total waypoints |
| Gap detection | O(n) | Linear scan of fragments |
| Total | O(n log n + m) | Dominated by waypoint count |

**Expected Performance**:
- 50 fragments, 100 waypoints each = 5,000 waypoints
- Processing time: < 100ms on typical hardware
