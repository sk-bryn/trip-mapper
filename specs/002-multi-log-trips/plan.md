# Implementation Plan: Multi-Log Trip Support

**Branch**: `002-multi-log-trips` | **Date**: 2025-12-07 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-multi-log-trips/spec.md`

## Summary

Enable visualization of trips that have multiple log fragments due to app crashes or restarts. Currently, the system uses only the most recent log entry; this feature will fetch ALL logs for a tripId, retain each as a separate data model, combine waypoints chronologically for visualization, and handle gaps/failures gracefully.

## Technical Context

**Language/Version**: Swift 5.5+ (async/await support required)
**Primary Dependencies**: Foundation, URLSession, ArgumentParser (existing)
**Storage**: File system only (logs directory, output images/HTML)
**Testing**: XCTest (existing test infrastructure)
**Target Platform**: macOS 12+, Linux with Swift 5.5+
**Project Type**: Single CLI application
**Performance Goals**: Process up to 50 log fragments per trip within existing timeout constraints
**Constraints**: Max 50 fragments per tripId, graceful degradation on partial failures
**Scale/Scope**: Extension of existing Trip Visualizer CLI

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. CLI-First Design | PASS | Extends existing CLI; progress feedback specified for multi-log downloads |
| II. Test-First Development | PASS | Unit tests required for new models and services |
| III. Strongly-Typed Swift | PASS | New LogFragment model uses strongly typed Swift structs |
| IV. Cross-Platform Compatibility | PASS | Uses only Foundation; no platform-specific APIs |
| V. Security-First | PASS | No new secrets; existing env vars for API keys |
| VI. Modular Configuration | PASS | May add maxFragments config option |
| VII. Comprehensive Documentation | PASS | DocC-compatible documentation required |

**Gate Result**: PASS - No violations

## Project Structure

### Documentation (this feature)

```text
specs/002-multi-log-trips/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (internal API contracts)
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
TripVisualizer/
├── Sources/TripVisualizer/
│   ├── Models/
│   │   ├── Trip.swift              # MODIFY: Update to support fragments
│   │   ├── LogFragment.swift       # NEW: Individual log fragment model
│   │   ├── UnifiedRoute.swift      # NEW: Combined route view model
│   │   ├── Waypoint.swift          # MODIFY: Add timestamp field
│   │   └── ...
│   ├── Services/
│   │   ├── DataDogClient.swift     # MODIFY: Fetch all logs, not just recent
│   │   ├── LogParser.swift         # MODIFY: Parse into LogFragment
│   │   ├── FragmentAggregator.swift # NEW: Combine fragments into UnifiedRoute
│   │   ├── TripVisualizer.swift    # MODIFY: Orchestrate multi-fragment flow
│   │   └── MapGenerator.swift      # MODIFY: Support dashed lines for gaps
│   └── Utilities/
│       └── ProgressIndicator.swift # MODIFY: Multi-fragment progress
└── Tests/TripVisualizerTests/
    ├── Models/
    │   ├── LogFragmentTests.swift  # NEW
    │   └── UnifiedRouteTests.swift # NEW
    ├── Services/
    │   ├── FragmentAggregatorTests.swift # NEW
    │   └── ...
    └── Integration/
        └── MultiLogTripTests.swift # NEW
```

**Structure Decision**: Extends existing single project structure. New files added to Models/ and Services/ directories following established patterns.

## Complexity Tracking

> No violations requiring justification.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| N/A | N/A | N/A |
