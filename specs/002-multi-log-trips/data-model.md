# Data Model: Multi-Log Trip Support

**Date**: 2025-12-07
**Feature**: 002-multi-log-trips

## Overview

This document defines the data models for multi-log trip support. The design retains each log fragment as a separate entity while providing a unified view for visualization.

---

## Entity Relationship Diagram

```text
┌─────────────────────────────────────────────────────────────┐
│                          Trip                                │
│  (Orchestration - links fragments to unified visualization)  │
├─────────────────────────────────────────────────────────────┤
│  id: UUID                                                    │
│  fragments: [LogFragment]                                    │
│  unifiedRoute: UnifiedRoute                                  │
│  metadata: TripMetadata                                      │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ contains 1..50
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                       LogFragment                            │
│  (Individual log entry - retained for inspection)            │
├─────────────────────────────────────────────────────────────┤
│  id: String (DataDog log ID)                                 │
│  tripId: UUID                                                │
│  timestamp: Date                                             │
│  waypoints: [Waypoint]                                       │
│  logLink: String                                             │
│  waypointCount: Int (computed)                               │
│  startLocation: Waypoint? (computed)                         │
│  endLocation: Waypoint? (computed)                           │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ contains 2..N
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                        Waypoint                              │
│  (Single coordinate point - existing model, extended)        │
├─────────────────────────────────────────────────────────────┤
│  latitude: Double                                            │
│  longitude: Double                                           │
│  orderId: UUID?                                              │
│  fragmentId: String? (NEW - reference to source fragment)    │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                      UnifiedRoute                            │
│  (Combined view for visualization - computed from fragments) │
├─────────────────────────────────────────────────────────────┤
│  tripId: UUID                                                │
│  waypoints: [Waypoint] (chronologically ordered)             │
│  segments: [RouteSegment]                                    │
│  totalWaypointCount: Int                                     │
│  fragmentCount: Int                                          │
│  hasGaps: Bool                                               │
│  isComplete: Bool (all fragments successful)                 │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ contains 1..N
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      RouteSegment                            │
│  (Contiguous portion of route - for rendering)               │
├─────────────────────────────────────────────────────────────┤
│  waypoints: [Waypoint]                                       │
│  type: SegmentType (.continuous | .gap)                      │
│  sourceFragmentId: String?                                   │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                      TripMetadata                            │
│  (Summary information for logging/display)                   │
├─────────────────────────────────────────────────────────────┤
│  totalFragments: Int                                         │
│  successfulFragments: Int                                    │
│  failedFragments: Int                                        │
│  truncated: Bool (more than 50 fragments existed)            │
│  firstTimestamp: Date                                        │
│  lastTimestamp: Date                                         │
│  totalDuration: TimeInterval                                 │
└─────────────────────────────────────────────────────────────┘
```

---

## Model Specifications

### LogFragment

Represents a single log entry from DataDog. Each fragment is retained as an independent entity for inspection.

```swift
/// A single log entry representing one fragment of a trip's route.
///
/// When the delivery app crashes or restarts, a new log fragment is created.
/// Multiple fragments together form the complete trip history.
public struct LogFragment: Codable, Equatable, Identifiable {
    /// DataDog log entry ID (unique identifier)
    public let id: String

    /// Trip UUID this fragment belongs to
    public let tripId: UUID

    /// When this log was recorded in DataDog
    public let timestamp: Date

    /// Ordered waypoints from this fragment's segment_coords
    public let waypoints: [Waypoint]

    /// URL to view this log in DataDog UI
    public let logLink: String
}
```

**Validation Rules**:
- `id` must be non-empty
- `tripId` must be valid UUID
- `timestamp` must be valid Date
- `waypoints` must have at least 2 entries
- `logLink` must be valid URL format

**Computed Properties**:
- `waypointCount: Int` - Number of waypoints
- `startLocation: Waypoint?` - First waypoint
- `endLocation: Waypoint?` - Last waypoint
- `duration: TimeInterval?` - Time span (if waypoints have timestamps)

---

### UnifiedRoute

A computed view that combines all log fragments into a single visualization-ready route.

```swift
/// Combined route from all log fragments, ready for map visualization.
///
/// This is a view model that does not replace the underlying fragment data.
/// Waypoints are chronologically ordered and deduplicated.
public struct UnifiedRoute: Codable, Equatable {
    /// Trip UUID
    public let tripId: UUID

    /// All waypoints in chronological order (deduplicated)
    public let waypoints: [Waypoint]

    /// Route segments for rendering (continuous vs gap)
    public let segments: [RouteSegment]

    /// Number of source fragments
    public let fragmentCount: Int

    /// Whether all fragments were successfully processed
    public let isComplete: Bool
}
```

**Computed Properties**:
- `totalWaypointCount: Int` - Total waypoints across all segments
- `hasGaps: Bool` - True if any segment has type `.gap`
- `continuousSegments: [RouteSegment]` - Only continuous segments
- `gapSegments: [RouteSegment]` - Only gap segments

---

### RouteSegment

Represents a contiguous portion of the route for rendering purposes.

```swift
/// A contiguous portion of a route, either continuous data or a gap.
public struct RouteSegment: Codable, Equatable {
    /// Waypoints in this segment
    public let waypoints: [Waypoint]

    /// Type of segment for rendering
    public let type: SegmentType

    /// Source fragment ID (nil for gap segments)
    public let sourceFragmentId: String?
}

/// Segment type for rendering differentiation
public enum SegmentType: String, Codable {
    /// Continuous route data from a log fragment
    case continuous

    /// Gap between fragments (render as dashed line)
    case gap
}
```

---

### TripMetadata

Summary information about the trip processing.

```swift
/// Metadata about trip fragment processing for logging and display.
public struct TripMetadata: Codable, Equatable {
    /// Total fragments found in DataDog
    public let totalFragments: Int

    /// Successfully processed fragments
    public let successfulFragments: Int

    /// Failed fragments (download or parse errors)
    public let failedFragments: Int

    /// True if more than 50 fragments existed (truncated)
    public let truncated: Bool

    /// Timestamp of first fragment
    public let firstTimestamp: Date

    /// Timestamp of last fragment
    public let lastTimestamp: Date
}
```

**Computed Properties**:
- `totalDuration: TimeInterval` - Time from first to last fragment
- `successRate: Double` - Percentage of successful fragments
- `hasFailures: Bool` - True if any fragments failed

---

### Waypoint (Extended)

The existing Waypoint model with optional fragment reference.

```swift
/// Extended waypoint with optional source fragment reference.
public struct Waypoint: Codable, Equatable, Hashable {
    public let latitude: Double
    public let longitude: Double
    public let orderId: UUID?

    /// NEW: Reference to source LogFragment (for tracing)
    public let fragmentId: String?
}
```

**Note**: `fragmentId` is optional to maintain backward compatibility with existing code that creates Waypoints without fragment context.

---

## State Transitions

### Fragment Processing States

```text
                    ┌──────────────┐
                    │   Pending    │
                    └──────┬───────┘
                           │ fetch from DataDog
                           ▼
                    ┌──────────────┐
              ┌─────│  Fetching    │─────┐
              │     └──────────────┘     │
              │ success              │ failure
              ▼                      ▼
       ┌──────────────┐      ┌──────────────┐
       │   Parsing    │      │   Failed     │
       └──────┬───────┘      └──────────────┘
              │
       ┌──────┴──────┐
       │ success     │ failure
       ▼             ▼
┌──────────────┐ ┌──────────────┐
│   Complete   │ │   Failed     │
└──────────────┘ └──────────────┘
```

### Trip Aggregation States

```text
┌──────────────┐
│  Collecting  │ ← Gather all fragments
└──────┬───────┘
       │ all fragments resolved
       ▼
┌──────────────┐
│  Ordering    │ ← Sort by timestamp
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Deduplicating│ ← Remove duplicate waypoints
└──────┬───────┘
       │
       ▼
┌──────────────┐
│ Gap Detection│ ← Identify gaps between fragments
└──────┬───────┘
       │
       ▼
┌──────────────┐
│  Complete    │ ← UnifiedRoute ready
└──────────────┘
```

---

## Relationships Summary

| Entity | Relationship | Target | Cardinality |
|--------|--------------|--------|-------------|
| Trip | contains | LogFragment | 1:N (max 50) |
| Trip | has | UnifiedRoute | 1:1 |
| Trip | has | TripMetadata | 1:1 |
| LogFragment | contains | Waypoint | 1:N (min 2) |
| UnifiedRoute | contains | RouteSegment | 1:N |
| UnifiedRoute | contains | Waypoint | 1:N |
| RouteSegment | contains | Waypoint | 1:N |
| Waypoint | references | LogFragment | N:1 (optional) |
