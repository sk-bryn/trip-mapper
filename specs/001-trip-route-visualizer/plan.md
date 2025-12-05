# Implementation Plan: Trip Route Visualizer CLI

**Branch**: `001-trip-route-visualizer` | **Date**: 2025-12-04 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-trip-route-visualizer/spec.md`

## Summary

Build a Swift CLI tool that accepts a trip UUID, fetches trip logs from DataDog REST API v2, extracts route coordinates from the `segment_coords` array field, and generates a Google Maps visualization as both a static PNG image and an interactive HTML file with embedded map.

## Technical Context

**Language/Version**: Swift 5.5+ (async/await support required)
**Primary Dependencies**: Foundation, URLSession, swift-argument-parser (justified exception - see Complexity Tracking)
**Storage**: File system only (logs directory, output images/HTML)
**Testing**: XCTest (Swift's built-in testing framework)
**Target Platform**: macOS and Linux (cross-platform CLI)
**Project Type**: Single CLI application
**Performance Goals**: <30 seconds for trips with up to 500 waypoints (SC-001)
**Constraints**: Minimal external dependencies (only ArgumentParser); environment variables for API keys
**Scale/Scope**: Single-user CLI tool processing one trip at a time

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Evidence |
|-----------|--------|----------|
| I. CLI-First Design | PASS | stdout/stderr protocol, log files in `logs/`, progress indicators, help system |
| II. Test-First Development | PASS | XCTest planned, unit tests for each module required |
| III. Strongly-Typed Swift | PASS | Swift 5.5+, async/await, typed models for Trip/Waypoint |
| IV. Cross-Platform | PASS | Foundation + URLSession only, macOS + Linux targets |
| V. Security-First | PASS | API keys via env vars (DD_API_KEY, DD_APP_KEY, GOOGLE_MAPS_API_KEY) |
| VI. Modular Configuration | PASS | Config file support planned (FR-012) |
| VII. Comprehensive Documentation | PASS | Help system, DocC documentation planned |

**Gate Status**: PASSED - No violations

## Project Structure

### Documentation (this feature)

```text
specs/001-trip-route-visualizer/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
TripVisualizer/
├── Package.swift                    # Swift Package Manager manifest
├── Sources/
│   └── TripVisualizer/
│       ├── main.swift               # Entry point, CLI argument parsing
│       ├── Commands/
│       │   └── VisualizeCommand.swift
│       ├── Models/
│       │   ├── Trip.swift
│       │   ├── Waypoint.swift
│       │   ├── Configuration.swift
│       │   └── Errors.swift
│       ├── Services/
│       │   ├── DataDogClient.swift  # DataDog API integration
│       │   ├── LogParser.swift      # Extract coordinates from logs
│       │   └── MapGenerator.swift   # Generate HTML/PNG output
│       ├── Utilities/
│       │   ├── Logger.swift
│       │   ├── ProgressReporter.swift
│       │   └── Environment.swift
│       └── Resources/
│           └── map-template.html    # Google Maps HTML template
├── Tests/
│   └── TripVisualizerTests/
│       ├── Models/
│       ├── Services/
│       └── Integration/
├── logs/                            # Runtime log output directory
└── README.md
```

**Structure Decision**: Single CLI application using Swift Package Manager. Models, Services, and Utilities follow separation of concerns. Tests mirror source structure.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| swift-argument-parser dependency | CLI argument parsing, help generation, validation (FR-009, FR-014) | Manual CommandLine.arguments parsing would duplicate standard infrastructure, produce inconsistent help output, and require significantly more test coverage for equivalent functionality. ArgumentParser is Apple-maintained with zero transitive dependencies. |
