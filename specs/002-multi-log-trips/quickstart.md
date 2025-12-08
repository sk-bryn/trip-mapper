# Quickstart: Multi-Log Trip Support

**Date**: 2025-12-07
**Feature**: 002-multi-log-trips

## Overview

This guide provides a quick reference for implementing multi-log trip support. After this feature, the Trip Visualizer will handle trips with multiple log fragments from app crashes or restarts.

---

## Key Changes Summary

| Component | Change Type | Description |
|-----------|-------------|-------------|
| LogFragment | NEW | Model for individual log entries |
| UnifiedRoute | NEW | Combined view for visualization |
| RouteSegment | NEW | Segment with type (continuous/gap) |
| TripMetadata | NEW | Processing summary |
| FragmentAggregator | NEW | Service to combine fragments |
| DataDogClient | MODIFY | Fetch all logs, not just recent |
| LogParser | MODIFY | Parse into LogFragment |
| TripVisualizerService | MODIFY | Orchestrate multi-fragment flow |
| MapGenerator | MODIFY | Support gap segment rendering |
| ProgressIndicator | MODIFY | Multi-fragment progress display |
| Trip | MODIFY | Support multiple fragments |

---

## Implementation Order

### Phase 1: Models (No Dependencies)

1. **LogFragment.swift** - Create new model
2. **RouteSegment.swift** - Create new model
3. **UnifiedRoute.swift** - Create new model
4. **TripMetadata.swift** - Create new model
5. **Waypoint.swift** - Add optional `fragmentId` property

### Phase 2: Services (Depends on Phase 1)

6. **FragmentAggregator.swift** - Create new service
7. **DataDogClient.swift** - Add `fetchAllLogs` method
8. **LogParser.swift** - Return LogFragment instead of waypoints

### Phase 3: Integration (Depends on Phase 2)

9. **MapGenerator.swift** - Add segment-based rendering
10. **TripVisualizerService.swift** - Orchestrate new flow
11. **ProgressIndicator.swift** - Update progress messages

### Phase 4: Testing

12. Unit tests for all new models
13. Unit tests for FragmentAggregator
14. Integration tests for multi-log scenarios

---

## Code Snippets

### Creating a LogFragment

```swift
let fragment = LogFragment(
    id: logEntry.id,
    tripId: tripUUID,
    timestamp: parseTimestamp(logEntry.attributes.timestamp),
    waypoints: parsedWaypoints,
    logLink: dataDogClient.generateLogLink(logId: logEntry.id)
)
```

### Aggregating Fragments

```swift
let aggregator = FragmentAggregator()
let unifiedRoute = try aggregator.aggregate(
    fragments: logFragments,
    gapThreshold: 300 // 5 minutes
)
```

### Rendering with Gaps

```swift
try mapGenerator.writeHTML(
    tripId: tripId,
    segments: unifiedRoute.segments,
    to: outputPath
)
```

---

## Configuration Additions

Consider adding to `Configuration`:

```swift
/// Maximum log fragments to process per trip (default: 50)
public var maxFragments: Int

/// Time threshold for gap detection in seconds (default: 300)
public var gapThresholdSeconds: TimeInterval
```

---

## Testing Checklist

- [ ] Single log trip works unchanged
- [ ] Multiple logs combine correctly
- [ ] Duplicate waypoints removed
- [ ] Gaps detected and rendered
- [ ] Partial failures handled gracefully
- [ ] Progress shows fragment count
- [ ] Verbose mode shows fragment details
- [ ] 50 fragment limit enforced with warning

---

## Common Patterns

### Fragment Processing Loop

```swift
var fragments: [LogFragment] = []
var failedCount = 0

for logEntry in logEntries {
    do {
        let waypoints = try logParser.parseLogEntry(logEntry)
        let fragment = LogFragment(...)
        fragments.append(fragment)
    } catch {
        failedCount += 1
        logWarning("Failed to parse fragment: \(error)")
    }
}

// Proceed with available fragments
if !fragments.isEmpty {
    let route = try aggregator.aggregate(fragments: fragments)
    // Continue with visualization
}
```

### Backward Compatible Trip Creation

```swift
// For compatibility with existing code expecting Trip
let trip = Trip(
    id: tripId,
    fragments: fragments,
    unifiedRoute: unifiedRoute,
    metadata: TripMetadata(...)
)

// Legacy access still works
let allWaypoints = trip.unifiedRoute.waypoints
```

---

## Error Handling

| Scenario | Handling |
|----------|----------|
| No logs found | Throw `tripNotFound` |
| All fragments fail | Throw `noRouteData` |
| Some fragments fail | Warn and continue with available |
| > 50 fragments | Process first 50, warn about truncation |
| Gap between fragments | Create gap segment, continue |

---

## Files to Create

```
TripVisualizer/Sources/TripVisualizer/
├── Models/
│   ├── LogFragment.swift       (NEW)
│   ├── RouteSegment.swift      (NEW)
│   ├── UnifiedRoute.swift      (NEW)
│   └── TripMetadata.swift      (NEW)
└── Services/
    └── FragmentAggregator.swift (NEW)

TripVisualizer/Tests/TripVisualizerTests/
├── Models/
│   ├── LogFragmentTests.swift  (NEW)
│   ├── RouteSegmentTests.swift (NEW)
│   └── UnifiedRouteTests.swift (NEW)
└── Services/
    └── FragmentAggregatorTests.swift (NEW)
```

---

## Success Criteria Verification

| Criterion | How to Verify |
|-----------|---------------|
| SC-001: All waypoints displayed | Compare waypoint counts |
| SC-002: Single-log unchanged | Diff output before/after |
| SC-003: Fragment count shown | Check console output |
| SC-004: Partial success works | Test with mock failures |
| SC-005: No duplicates | Assert unique coordinates |
