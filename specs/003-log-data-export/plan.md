# Implementation Plan: Log Data Export

**Branch**: `003-log-data-export` | **Date**: 2025-12-08 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/003-log-data-export/spec.md`

## Summary

Add automatic JSON export of DataDog log metadata alongside map visualizations. The export provides a single file per trip containing route segment correlations to DataDog logs, orderIds per segment, ordered delivery sequence, and waypoint counts (without individual coordinates for brevity). This enables independent verification of rendered maps against source data.

## Technical Context

**Language/Version**: Swift 5.5+ (async/await support required)
**Primary Dependencies**: Foundation, URLSession (no external dependencies per constitution)
**Storage**: File system only (output directory alongside map files)
**Testing**: XCTest (existing test infrastructure)
**Target Platform**: macOS 12+, Linux with Swift 5.5+
**Project Type**: Single CLI application (extends existing Trip Visualizer)
**Performance Goals**: Export generation completes within existing visualization timeout
**Constraints**: Export file must be human-readable; no configuration options for export
**Scale/Scope**: Extension of existing Trip Visualizer CLI; single new output format

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. CLI-First Design | PASS | Export is automatic output alongside existing map files; follows stdout/file conventions |
| II. Test-First Development | PASS | Unit tests required for new TripDataExport model and export generation |
| III. Strongly-Typed Swift | PASS | New TripDataExport model uses strongly typed Swift structs |
| IV. Cross-Platform Compatibility | PASS | Uses only Foundation; JSONEncoder is cross-platform |
| V. Security-First | PASS | No new secrets; export contains no sensitive data beyond tripId |
| VI. Modular Configuration | PASS | No new config needed (export is always automatic per clarification) |
| VII. Comprehensive Documentation | PASS | DocC-compatible documentation required for new types |

**Gate Result**: PASS - No violations

## Project Structure

### Documentation (this feature)

```text
specs/003-log-data-export/
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
│   │   ├── TripDataExport.swift       # NEW: Export data model
│   │   ├── RouteSegmentExport.swift   # NEW: Segment export model
│   │   ├── OrderSummary.swift         # NEW: Order summary model
│   │   └── ...
│   ├── Services/
│   │   ├── TripVisualizer.swift       # MODIFY: Add export generation
│   │   ├── DataExportGenerator.swift  # NEW: Export file writer
│   │   └── ...
│   └── Utilities/
│       └── ...
└── Tests/TripVisualizerTests/
    ├── Models/
    │   ├── TripDataExportTests.swift  # NEW
    │   └── ...
    ├── Services/
    │   ├── DataExportGeneratorTests.swift # NEW
    │   └── ...
    └── Integration/
        └── DataExportIntegrationTests.swift # NEW
```

**Structure Decision**: Extends existing single project structure. New files added to Models/ and Services/ directories following established patterns from 002-multi-log-trips.

## Complexity Tracking

> No violations requiring justification.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| N/A | N/A | N/A |
