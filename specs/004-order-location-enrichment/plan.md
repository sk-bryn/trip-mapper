# Implementation Plan: Order & Location Enrichment

**Branch**: `004-order-location-enrichment` | **Date**: 2025-12-08 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/004-order-location-enrichment/spec.md`

## Summary

Add order delivery address enrichment and restaurant location data to trip visualizations by querying additional DataDog logs (GetDeliveryOrder, GetLocationsDetails) and displaying this enrichment data on the map with distinct markers, while including status indicators in the map-data.json export.

## Technical Context

**Language/Version**: Swift 5.5+ (async/await)
**Primary Dependencies**: Foundation, URLSession (no external dependencies per constitution)
**Storage**: File system (logs directory, output images/HTML, map-data.json)
**Testing**: XCTest
**Target Platform**: macOS and Linux
**Project Type**: single (CLI tool)
**Performance Goals**: Enrichment queries should complete within existing timeout constraints (30s default)
**Constraints**: No additional external dependencies; parallel fetching for minimal latency impact
**Scale/Scope**: Enrichment data for each trip (typically 1-10 orders per trip)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Pre-Phase 0 Assessment

| Principle | Status | Notes |
|-----------|--------|-------|
| I. CLI-First Design | ✅ PASS | No CLI changes required; enrichment is automatic |
| II. Test-First Development | ✅ PASS | Unit tests required for all new enrichment code |
| III. Strongly-Typed Swift | ✅ PASS | New entities use typed Swift structs |
| IV. Cross-Platform Compatibility | ✅ PASS | Uses only Foundation/URLSession |
| V. Security-First | ✅ PASS | Uses existing DD_API_KEY, DD_APP_KEY credentials |
| VI. Modular Configuration | ✅ PASS | New marker styles configurable via existing config |
| VII. Comprehensive Documentation | ✅ PASS | All new entities/services documented |

### Post-Phase 1 Re-Assessment

| Principle | Status | Evidence |
|-----------|--------|----------|
| I. CLI-First Design | ✅ PASS | Enrichment automatic; outputs to stdout/file per existing patterns |
| II. Test-First Development | ✅ PASS | Test files defined in project structure; 6 test classes specified |
| III. Strongly-Typed Swift | ✅ PASS | 5 new typed structs defined in data-model.md with validation rules |
| IV. Cross-Platform Compatibility | ✅ PASS | Only Foundation/URLSession used; no platform-specific APIs |
| V. Security-First | ✅ PASS | Reuses existing credentials; no new secrets required |
| VI. Modular Configuration | ✅ PASS | MarkerStyle config added; defaults with override capability |
| VII. Comprehensive Documentation | ✅ PASS | research.md, data-model.md, contracts/, quickstart.md generated |

**Gate Status**: ✅ ALL GATES PASSED - Ready for Phase 2 task generation

## Project Structure

### Documentation (this feature)

```text
specs/004-order-location-enrichment/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output (via /speckit.tasks)
```

### Source Code (repository root)

```text
TripVisualizer/Sources/TripVisualizer/
├── Models/
│   ├── DeliveryDestination.swift    # NEW: Order delivery address entity
│   ├── RestaurantLocation.swift     # NEW: Restaurant location entity
│   ├── EnrichmentResult.swift       # NEW: Combined enrichment data
│   ├── EnrichmentStatus.swift       # NEW: Status flags for map-data.json
│   ├── TripDataExport.swift         # MODIFIED: Add enrichment section
│   └── Configuration.swift          # MODIFIED: Add marker style config
├── Services/
│   ├── EnrichmentService.swift      # NEW: Fetches enrichment data from DataDog
│   ├── DataDogClient.swift          # MODIFIED: Add enrichment query methods
│   ├── MapGenerator.swift           # MODIFIED: Add enrichment markers
│   └── DataExportGenerator.swift    # MODIFIED: Include enrichment in export
└── Tests/
    ├── EnrichmentServiceTests.swift # NEW: Unit tests for enrichment
    ├── DeliveryDestinationTests.swift
    ├── RestaurantLocationTests.swift
    └── EnrichmentResultTests.swift

TripVisualizer/Tests/TripVisualizerTests/
├── EnrichmentServiceTests.swift
├── DeliveryDestinationTests.swift
├── RestaurantLocationTests.swift
├── EnrichmentResultTests.swift
└── MapGeneratorEnrichmentTests.swift
```

**Structure Decision**: Extends existing single-project structure. New enrichment entities in Models/, new EnrichmentService in Services/, tests in existing Tests directory.

## Complexity Tracking

No constitution violations requiring justification. Feature follows existing patterns.

