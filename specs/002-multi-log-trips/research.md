# Research: Multi-Log Trip Support

**Date**: 2025-12-07
**Feature**: 002-multi-log-trips

## Overview

This document captures research findings for implementing multi-log trip support. The existing codebase provides a solid foundation that requires targeted modifications rather than architectural changes.

---

## Research Topics

### 1. DataDog API Pagination for Multiple Logs

**Question**: How does DataDog Logs Search API handle multiple results for the same tripId?

**Finding**: The existing `DataDogClient.fetchLogs()` method already receives multiple log entries via `DataDogLogResponse.data` array. The current implementation in `TripVisualizerService.validateLogResponse()` sorts by timestamp and selects only the most recent log with route data.

**Decision**: Modify to return ALL logs with valid route data instead of just the most recent.

**Rationale**: The API already supports this; only the selection logic needs to change.

**Alternatives Considered**:
- Pagination with cursor: Not needed; the default limit of 10 logs per query is sufficient for most trips. Can increase limit if needed.
- Multiple API calls: Unnecessary complexity; single call returns all matching logs.

---

### 2. Waypoint Timestamp Extraction

**Question**: Do waypoints in segment_coords have timestamps for chronological ordering?

**Finding**: Examined existing `LogParser` and sample log structures. The waypoint coordinates in `segment_coords` do NOT include individual timestamps. However, each log entry has a top-level timestamp (`attributes.timestamp`) that indicates when that log fragment was created.

**Decision**:
1. Use log entry timestamp as the fragment timestamp
2. Waypoints within a fragment maintain their array order (assumed chronological within fragment)
3. Fragments are ordered by their log timestamp

**Rationale**: This matches the real-world behavior - each log fragment represents a continuous session, and waypoints within it are in route order.

**Alternatives Considered**:
- Add timestamp to Waypoint model: Would require log format changes; not available in current data
- Use GPS timestamp if present: Not consistently available in current log format

---

### 3. Duplicate Waypoint Detection

**Question**: How should duplicate waypoints across fragments be identified and removed?

**Finding**: Waypoints are currently defined by latitude, longitude, and optional orderId. The `Waypoint` struct already implements `Equatable` and `Hashable`.

**Decision**: Consider waypoints duplicates if they have identical coordinates (latitude, longitude). Use a tolerance of ~1 meter for floating-point comparison (approximately 0.00001 degrees).

**Rationale**: Same physical location across fragments indicates overlap period. Order ID may differ if driver was between deliveries.

**Alternatives Considered**:
- Exact coordinate match only: Too strict; GPS jitter could miss real duplicates
- Include orderId in duplicate check: Could miss legitimate duplicates during return-to-restaurant segments

---

### 4. Gap Detection Between Fragments

**Question**: How to identify and handle gaps between consecutive log fragments?

**Finding**: Gaps occur when:
1. Time between end of fragment N and start of fragment N+1 exceeds a threshold
2. Geographic distance between last waypoint of fragment N and first waypoint of fragment N+1 is significant

**Decision**:
- Use time-based gap detection with 5-minute threshold (configurable)
- Mark gap segments for dashed-line rendering
- Do NOT attempt to interpolate missing data

**Rationale**: Time-based detection is reliable; geographic distance alone could flag legitimate fast travel.

**Alternatives Considered**:
- Geographic distance only: Unreliable for varying travel speeds
- Combined time + distance: Added complexity without clear benefit
- Interpolation: Would create false data; better to show gaps honestly

---

### 5. Fragment Limit Implementation

**Question**: How to enforce the 50-fragment limit from spec clarification?

**Finding**: The limit should be applied after fetching but before processing to avoid unnecessary work.

**Decision**:
1. Fetch all logs matching tripId (up to API limit)
2. Sort by timestamp ascending (oldest first)
3. Take first 50 fragments
4. Warn user if more fragments exist

**Rationale**: Taking oldest-first ensures complete trip history up to limit. User is warned about truncation.

**Alternatives Considered**:
- Most recent 50: Would lose beginning of trip
- Random sample: Would create disjointed route
- Configurable limit: Adds complexity; 50 is reasonable default

---

### 6. Dashed Line Rendering for Gaps

**Question**: How to render dashed lines in Google Maps output formats?

**Finding**:
- **HTML/JavaScript Maps**: Google Maps JavaScript API supports `StrokePattern` with dashed lines via `icons` property on Polyline
- **Static Maps API**: Does not support dashed lines directly; would need to approximate with shorter segments or different color

**Decision**:
- HTML output: Use proper dashed polyline between gap endpoints
- PNG/Static output: Use a different color (gray) for gap segments instead of dashed lines
- URL output: Include gap coordinates with note about gaps

**Rationale**: Maintains visual distinction while working within API constraints.

**Alternatives Considered**:
- Skip gaps entirely in static maps: Loses information about route continuity
- Use markers instead of lines: Clutters the map

---

### 7. Backward Compatibility

**Question**: How to ensure single-log trips continue to work identically?

**Finding**: The new multi-fragment architecture naturally handles single-log trips as a degenerate case (1 fragment).

**Decision**:
1. `LogFragment` array with single element = current behavior
2. `UnifiedRoute` from single fragment = identical to current Trip waypoints
3. No special-casing needed in visualization pipeline

**Rationale**: Unified code path is simpler to maintain and test.

**Alternatives Considered**:
- Separate code paths for single vs. multi: Duplicates logic, harder to maintain
- Feature flag: Unnecessary complexity for a backward-compatible change

---

## Summary of Decisions

| Topic | Decision |
|-------|----------|
| DataDog API | Use existing API, modify selection logic to return all logs |
| Waypoint timestamps | Use log entry timestamp for fragment ordering |
| Duplicate detection | Coordinate match with ~1 meter tolerance |
| Gap detection | 5-minute time threshold between fragments |
| Fragment limit | 50 fragments, oldest-first, warn on truncation |
| Gap rendering | Dashed lines (HTML), gray lines (PNG) |
| Backward compatibility | Single code path handles 1-N fragments |

---

## Dependencies Identified

1. **Existing Models**: Waypoint, Trip, DataDogLogEntry
2. **Existing Services**: DataDogClient, LogParser, MapGenerator, TripVisualizerService
3. **New Models**: LogFragment, UnifiedRoute
4. **New Services**: FragmentAggregator

---

## Next Steps

1. Create data-model.md with LogFragment and UnifiedRoute specifications
2. Define internal contracts for FragmentAggregator service
3. Proceed to task breakdown in Phase 2
